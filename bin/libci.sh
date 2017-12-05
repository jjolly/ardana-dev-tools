#
# (c) Copyright 2015-2017 Hewlett Packard Enterprise Development LP
# (c) Copyright 2017 SUSE LLC
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License. You may obtain
# a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations
# under the License.
#
export DEVTOOLS=$(cd $(dirname ${BASH_SOURCE[0]})/.. ; pwd)
export PS4='+${BASH_SOURCE/$HOME/\~}@${LINENO}(${FUNCNAME[0]}):'

# CDL convention
cfg=/etc/profile.d/proxy.sh
if [ -e $cfg ] ; then
    source $cfg
fi

# Validated ansible-playbook to use.
export PATH=$DEVTOOLS/tools/venvs/ansible/bin/:$PATH
export EXTRA_VARS=${EXTRA_VARS:-}
if [ -n "$EXTRA_VARS" ]; then
    shopt -s expand_aliases
    alias ansible-playbook="ansible-playbook -e '$EXTRA_VARS'"
fi

export ANSIBLE_LOG_PATH=${WORKSPACE:-${DEVTOOLS}}/vm_host_ansible.log
# Prevent ssh host key errors
export ANSIBLE_HOST_KEY_CHECKING=False

export PYTHONUNBUFFERED=1

# Used in run-lint.bash
export GOZER_GIT_MIRROR=${GOZER_GIT_MIRROR:-https://gerrit.suse.provo.cloud}
export PYPI_MIRROR_URL=${PYPI_MIRROR_URL:-http://${PYPI_BASE_HOST:-pypi.suse.provo.cloud}/openstack/latest}

# For testing and developer experience we set ARDANAUSER here to be stack. During
# CI, we pass in the --ci flag which sets the ARDANAUSER appropriately
export ARDANAUSER=${ARDANAUSER:-stack}

export VAGRANT_LOG_DIR="${WORKSPACE:-${DEVTOOLS}}/logs/vagrant"
export CONSOLE_LOG_DIR="${WORKSPACE:-${DEVTOOLS}}/logs/console"
export CP_LOG_DIR="${WORKSPACE:-${DEVTOOLS}}/logs/configProcessor"
[[ ! -d "${VAGRANT_LOG_DIR}" ]] && mkdir -p "${VAGRANT_LOG_DIR}"
[[ ! -d "${CP_LOG_DIR}" ]] && mkdir -p "${CP_LOG_DIR}"

export VAGRANT_DEFAULT_PROVIDER=libvirt

export ARDANA_SUBUNIT_VENV=$DEVTOOLS/tools/venvs/subunit
export ARDANA_RUN_SUBUNIT_OUTPUT=${WORKSPACE:-$PWD}/ardanarun.subunit

export ARDANA_VAGRANT_SSH_CONFIG="astack-ssh-config"

export ARTIFACTS_FILE=$DEVTOOLS/artifacts-list.txt


devenvinstall() {
    local STATUS
    pushd $DEVTOOLS/ansible
    ansible-playbook -i hosts/localhost dev-env-install.yml
    STATUS=$?
    # clear out hashed executables to pick up anything installed
    hash -r
    popd
    return $STATUS
}

reporttimeout() {
    local STATUS=$?
    if [ $STATUS -eq 124 ]; then
        # Make it easy to search in ELK for timeouts
        echo "*** TIMEOUT RUNNING $1 ***"
    fi

    return $STATUS
}

installsubunit() {
    if [ -n "$CI" ]; then
        virtualenv $ARDANA_SUBUNIT_VENV
        timeout 2m $ARDANA_SUBUNIT_VENV/bin/pip install "setuptools<34.0.0" || reporttimeout "pip install setuptools<34.0.0"
        timeout 2m $ARDANA_SUBUNIT_VENV/bin/pip install python-subunit || reporttimeout "pip install python-subunit"

        mkdir -p $(dirname $ARDANA_RUN_SUBUNIT_OUTPUT)
        rm -f $ARDANA_RUN_SUBUNIT_OUTPUT
    fi
}

logsubunit() {
    if [ -n "$CI" ]; then
        local status="$1"
        local testid="ardanarun.$2"
        $ARDANA_SUBUNIT_VENV/bin/subunit-output $status $testid >> $ARDANA_RUN_SUBUNIT_OUTPUT
    fi
}

# CMD1 &&CMD2 && ... || logfail testid [status]
logfail() {
    # Must be the first line to capture status or else we have to pass it in
    local STATUS=${2:-$?}
    if [ -n "$CI" ]; then
        logsubunit --fail "$1"
    fi
    exit $STATUS
}

# timeout 10s || logtimeoutfail testid
logtimeoutfail() {
    local STATUS=$?
    if [ $STATUS -eq 124 ]; then
        # Make it easy to search in ELK for timeouts
        echo "*** TIMEOUT RUNNING $1 ***"
    fi

    logfail $1 $STATUS
}

# Generate the ssh-config file
# Requires the environmental variable VAGRANT_LOG_DIR to be set
generate_ssh_config() {
    if [ ! -e ${ARDANA_VAGRANT_SSH_CONFIG} -o -n "${1:-}" ]; then
        vagrant --debug \
            ssh-config 2>>"${VAGRANT_LOG_DIR}/${ARDANA_VAGRANT_SSH_CONFIG}.log" > $ARDANA_VAGRANT_SSH_CONFIG
    fi
}

get_deployer_node() {
    awk '/^deployer_node/ {gsub(/\"/,"",$3);print $3}' Vagrantfile
}

get_branch() {
    pushd $DEVTOOLS >/dev/null
    local branch=$(cat $(git rev-parse --show-toplevel)/.gitreview | awk -F= '/defaultbranch/ { print $2 }')
    popd >/dev/null

    echo $branch
}

get_branch_path() {
    echo $(get_branch) | tr '/' '_'
}

# gather debug data on vagrant env failures
gather_data() {
    printf "Dump vagrant status, ethX PCI addresses, ip addresses, link traffic stats, routes, neighbors, iptables, bridge, virsh data\n"
    vagrant status
    vagrant global-status
    n_devices="$(netstat -ia | grep -e "^eth" | wc -l)"
    for i in $(seq 0 $((${n_devices}-1)))
    do
        sudo ethtool -i eth${i} | grep -e bus-info
    done
    ip address
    ip -s link
    ip route
    ip neighbour show
    sudo iptables -L -n -v
    sudo iptables -t nat -L -n -v
    brctl show
    sudo virsh net-list
    machines=$(vagrant --machine-readable status | \
        awk -F, '/provider-name/ {print $2}')
    printf "Machines: ${machines}\n"
    for machine in ${machines} ; do
        printf "\nmachine $machine data:\n"
        cmd='
set -x
n_devices="$(netstat -ia | grep -e "^eth" | wc -l)"
for i in $(seq 0 $((${n_devices}-1)))
do
    sudo ethtool -i eth${i} | grep -e bus-info
done
ip address
ip -s link
ip route
ip neighbour show
sudo ovs-vsctl show
sudo brctl show
'
        vagrant ssh -c "$cmd" $machine
    done
    for vm in $(sudo virsh list --all --name) ; do
        printf "\nvm $vm configuration:\n"
        sudo virsh dumpxml $vm
    done
}

gather_data_on_error() {
    local cmd="$1"
    local err_log=$2
    if eval "${cmd}" ; then
        return 0
    fi
    if set -o | grep -q '^errexit[[:space:]]*on' ; then
        set +o errexit
        local setflag=true
    fi
    printf "\n'$cmd' failed\n"
    gather_data > ${err_log} 2>&1
    [[ -n "${setflag}" ]] && set -o errexit
    return 1
}

vagrant_data_on_error() {
    local cmd="$@"
    if test -z "${CI:-}" ; then
        eval $cmd
    else
        gather_data_on_error "$cmd" "${VAGRANT_LOG_DIR}/deploy-vagrant-setup-fail.log"
    fi
}

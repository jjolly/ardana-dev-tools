# Ardana Dev Tools Walkthrough
This is a step-by-step journey from the start of a bare system to the logging in to an instance within an Ardana-created Openstack Cloud. The purpose of this document is not to provide an in-depth functional description of Ardana, Openstack, or any of it's components. The purpose of this document is to provide the individual command necessary to having a working Openstack cloud via Ardana. There may be some reasoning and explanation with steps in this document, but nothing will be in depth.

## In The Beginning - Creating the foundation for your system
This walkthrough is based on the ardana-dev-tools project from GitHub. You can find the project at https://github.com/ArdanaCLM/ardana-dev-tools. This project contains a set of Vagrant scripts that set up one of many Ardana models. Once the Ardana model is set up, then Ardana can start it's work. It's rather like the system (ardana-dev-tools using Vagrant) that will set up your system (Ardana using Ansible) that will set up your system (Openstack) that will set up your system (compute nodes in Openstack).
* Clean install of Leap 15

  This guide expects the host system to have OpenSUSE Leap 15 installed for the host operating system. While this guide may be expanded in the future to cover SLES and nested virtualzation, for now only one base is used.

* Copy a ssh key (public and private) into the host system

  Or create one in the host system. This ssh key will be used to login to our final instance.

  There are ways to have Openstack create the public and private key for you. I'll leave this key creation as an exercise for the user.

* Add user to sudoers:

  All these commands are to be run from an unprivileged user. Of course, how unprivileged is a user when that user is given these rights via sudo? That's a philisophical debate outside the scope of this document.

  Type in the command:
```
echo ${USER} ALL=(ALL:ALL) NOPASSWD:ALL | sudo tee -a /etc/sudoers.d/90-${USER}-access
```

* Add user to polkit:

  This unprivileged user will be running quite a number of Libvirt `virsh` commands. Rather than cheat and use `sudo` to perform our virtualization, a rule will be added to PolicyKit to allow the unprivileged user to do virtualization.
```
sudo tee "/etc/polkit-1/rules.d/80-libvirt-manage-${USER}.rules" <<EOF
polkit.addRule(function(action, subject) {
  if (action.id == "org.libvirt.unix.manage" &&
    subject.active && subject.user == "${USER}") {
      return polkit.Result.YES;
  }
});
EOF
```

* Install needed packages into root host:

  The `git-core` package is needed for cloning the `ardana-dev-tools` project, and `libvirt` is needed to allow the dev tools to run the virtualized systems needed for the Ardana system.
```
sudo zypper ref && sudo zypper in git-core libvirt
```

* Enable and start `libvirtd`
```
sudo systemctl enable libvirtd && sudo systemctl start libvirtd
```

* (Optional) Create temporary cache directories "somewhere else"

  Ardana caches a lot of repositories that will be copied to the development system, and these cached repositories take up a lot of space. This is a real problem if your home directory is located on a slower network drive or on a device with limited space. Typicaly I would create the directories on a storage device with more space and softlink the directories to my home directory.
```
for cachedir in {cache,cache-ardana,ansible}; do mkdir -p ${PATH_TO_ALT_DIR}/${cachedir}; ln -s ${PATH_TO_ALT_DIR}/${cachedir} ~/.${cachedir}; done
```

* (Optional) Create a directory to keep one or more source projects.

  I choose to create a `src` directory and store my projected in that directory. You know your source organization, do what works best for you.
```
mkdir src && cd src
```

## A Whole New World - Getting and running the Ardana Dev Tools `astack.sh`
With the base system configured to host `ardana-dev-tools`, you're ready to build the environment. These tools will automatically create a running Ardana environment, as well as allow you to include various Ardana source projects that you may be working on.

* Clone ardana-dev-tools locally.

  This will clone the upstream `ardana-dev-tools` project, but if you have your own fork, feel free to clone it instead.
  Be aware that this will not work unless the matching `ssh` public key has been uploaded to GitHub. The public key should match the private key you copied into the system in an earlier step.
  You can also clone other ardana projects into this directory for inclusion to the dev environment

```
git clone git@github.com:ArdanaCLM/ardana-dev-tools.git
```

* Launch the `astack.sh` script to build the development environment

  There are several models that can be built. This example explicitly uses the `std-min` model. Descriptions of other models can be found in the root README.md.
  This step takes the most time. How much time is dependent on I/O speed, memory, and CPU count. Times of 2.5 hours has been experienced on fairly beefy machines.
  If you wish to defer the bulk of the time to install, then add the `--no-site` option to the script. You will need to manually execute the `site` playbook on the deployer if you use this option.

```
cd ardana-dev-tools && ./bin/astack.sh --ipv6-all std-min
```

* Login to deployer node

  For all the models there is at least one node for the deployer. This is where all the Ardana Ansible playbooks can be found. To log into the deployer, use the `ardana-vagrant`script.

```
cd ardana-vagrant-models/std-min-vagrant
./ardana-vagrant ssh deployer
```

* Run the configuration processor

  In order to properly run playbooks on the deployer, the configuration processor must be run. This only needs to be run one time.
  This script will ask for a password and confirmation twice. Skip password creation by pressing enter four times.

```
cd ~/openstack/ardana/ansible
ansible-playbook -i hosts/localhost config-processor-run.yml
```

* Run Ardana playbooks

  The main playbooks for Ardana on the deployer node can be found under the `scratch` directory.
  If you built the dev environment with the `astack.sh` script using the `--no-site` option, you will need to run the `site.yml` playbook from this directory.

```
cd ~/scratch/ansible/next/ardana/ansible
ansible-playbook -i hosts/verb_hosts <playbook filename>
```

* Clean up the Ardana development environment

  When you need to start with a fresh Ardana development environment, return to the `ardana-dev-tools` project directory in your development host and run the script that will remove the Ardana deployer and all the Openstack nodes.

```
cd ~/src/ardana-dev-tools
./bin/cleanup-slave --ci
```

## Controlling Your World - Working with the Openstack nodes
Once you've set up your development environment, you can work with the Openstack nodes by logging into the controller. These instructions are not about Ardana specifically, but more about how to work with the system deployed by `astack.sh`.
Each model supplied by the `ardana-dev-tools` project has a different configuration. You'll always have a deployer node, but the compute and control nodes tend to be different across the different models.

* Login to a controller node

  The controller nodes for the `std-min` model start with the `cp#` designator.

```
cd ardana-vagrant-models/std-min-vagrant
./ardana-vagrant ssh cp1-0001
```

* Set up the working environment for the shell

  Ardana nicely gives sourcable scripts that provide all the necessary environment variable to work with the Openstack system.

```
source ./service.osrc
```

* Add ssh key to Openstack

  In order to access your instance, you will need to add the public key to Openstack

```
openstack keypair create --public-key ~/.ssh/id_rsa.pub server-key
```

* Create network, subnet, and router for instances

  Ardana creates and external network `ext-net` that allows for "public" access of instances, but Ardana does not create a network for instances. These steps will set up the appropriate internal network 'int-net' for attaching nodes.
  These steps create a network with a CIDR of 192.168.100.0/24. Do not hesitate to change the network range to one of your liking.

```
openstack network create int-net
openstack subnet create --network int-net --subnet-range 192.168.100.0/24 int-subnet
openstack router create int-router
openstack router add subnet int-router int-subnet
openstack router set --external-gateway ext-net int-router
```

* Create an instance and attach a floating IP

  Now create a simple instance and attach a floating IP address to that instance.
  When the floating IP address is created, make note of the address and use it when attaching an address to the instance.

```
openstack server create --image cirros-0.4.0-x86_64 --flavor m1.tiny --network int-net --key-name server-key test-server-01
openstack floating ip create ext-net
openstack server add floating ip test-server-01 <floating-ip>
```

* Create security group and rules to allow ssh and ping

  In order to access the instance through the floating IP, the necessary security group and rules must be created.

```
openstack security group create ssh-access
openstack security group rule create --ingress --dst-port 22 --protocol tcp ssh-access
openstack security group create ping-access
openstack security group rule create --protocol icmp ping-access
openstack server add security group test-server-01 ssh-access
openstack server add security group test-server-01 ping-access
```

* Use the new Openstack instance

  Using the floating IP created, you may now work with the instance you have created

```
ping <ip-address>
ssh cirros@<ip-address>
```

## Conclusion

These instructions should have provided you with the necessary Ardana development environment and instructions on how to use the environment. At this point, you are the developer: go fix some bugs.

## Thanks

A big *Thank You* to the wonderful people that have helped in the creation of these steps. Including:
* Fergal McCarthy - An Ardana Master of the highest order and an overall helpful guy
* Adolfo Duarte - A great storehouse of knowledge into the world of Openstack networking
* Ryan Tidwell - Neutron master and helpful in many ways
* Nicolas Bock - Man of great patience with my need to create this document

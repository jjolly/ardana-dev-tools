# Ardana Dev Tools Walkthrough - Running `astack.sh`
This is a step-by-step journey from the start of a bare system to the 
logging in to an instance within an Ardana-created Openstack Cloud. The 
purpose of this document is not to provide an in-depth functional 
description of Ardana, Openstack, or any of it's components. The 
purpose of this document is to provide the individual command necessary 
to having a working Openstack cloud via Ardana. There may be some 
reasoning and explanation with steps in this document, but nothing will 
be in depth.

This is second of three parts to this document. In this document are 
presented the steps necessary to run the `astack.sh` script within the 
`ardana-dev-tools` project. This document requires a host that has been 
properly set up for an Ardana environment. Please refer to the document 
`walkthrough-setup.md` for more details.

## A Whole New World - Getting and running the Ardana Dev Tools 
`astack.sh`
With the base system configured to host `ardana-dev-tools`, you're 
ready to build the environment. These tools will automatically create a 
running Ardana environment, as well as allow you to include various 
Ardana source projects that you may be working on.

* Clone ardana-dev-tools locally.

  This will clone the upstream `ardana-dev-tools` project, but if you 
have your own fork, feel free to clone it instead.
  Be aware that this will not work unless the matching `ssh` public key 
has been uploaded to GitHub. The public key should match the private 
key you copied into the system in the setup walkthrough.
  You can also clone other ardana projects into this directory for 
inclusion to the dev environment

```
git clone git@github.com:ArdanaCLM/ardana-dev-tools.git
```

* Launch the `astack.sh` script to build the development environment

  There are several models that can be built. This example explicitly 
uses the `std-min` model. Descriptions of other models can be found in 
the root README.md.
  This step takes the most time. How much time is dependent on I/O 
speed, memory, and CPU count. Times of 2.5 hours has been experienced 
on fairly beefy machines.
  If you wish to defer the bulk of the time to install, then add the 
`--no-site` option to the script. You will need to manually execute the 
`site` playbook on the deployer if you use this option.

```
cd ardana-dev-tools && ./bin/astack.sh --ipv6-all std-min
```

* Login to deployer node

  For all the models there is at least one node for the deployer. This 
is where all the Ardana Ansible playbooks can be found. To log into the 
deployer, use the `ardana-vagrant`script.

```
cd ardana-vagrant-models/std-min-vagrant
./ardana-vagrant ssh deployer
```

* Run the configuration processor

  In order to properly run playbooks on the deployer, the configuration 
processor must be run. This only needs to be run one time.
  This script will ask for a password and confirmation twice. Skip 
password creation by pressing enter four times.

```
cd ~/openstack/ardana/ansible
ansible-playbook -i hosts/localhost config-processor-run.yml
```

* Run Ardana playbooks

  The main playbooks for Ardana on the deployer node can be found under 
the `scratch` directory.
  If you built the dev environment with the `astack.sh` script using 
the `--no-site` option, you will need to run the `site.yml` playbook 
from this directory.

```
cd ~/scratch/ansible/next/ardana/ansible
ansible-playbook -i hosts/verb_hosts <playbook filename>
```

* Clean up the Ardana development environment

  When you need to start with a fresh Ardana development environment, 
return to the `ardana-dev-tools` project directory in your development 
host and run the script that will remove the Ardana deployer and all 
the Openstack nodes.

```
cd ~/src/ardana-dev-tools
./bin/cleanup-slave --ci
```

## Conclusion

After following these instructions you should have a working Ardana 
envionment and should be able to access the deployer node. The next 
document, `walkthrough-openstack.md`, will provide guidance on how to 
configure and use the Openstack environment created by Ardana.

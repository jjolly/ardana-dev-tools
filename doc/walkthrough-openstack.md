# Ardana Dev Tools Walkthrough - Running `astack.sh`
This is a step-by-step journey from the start of a bare system to the 
logging in to an instance within an Ardana-created Openstack Cloud. The 
purpose of this document is not to provide an in-depth functional 
description of Ardana, Openstack, or any of it's components. The 
purpose of this document is to provide the individual command necessary 
to having a working Openstack cloud via Ardana. There may be some 
reasoning and explanation with steps in this document, but nothing will 
be in depth.

This document is part three of a three part series. The previous two 
documents should have guided through the steps to set up a host for 
Ardana (`walkthrough-setup.md`) and run the `astack.sh` script to 
actually create the Ardana environment (`walkthrough-astack.md`). For 
this document steps will be provided to help set up the Openstack 
environment, including internal networking and instance deployment.

## Controlling Your World - Working with the Openstack nodes
Once you've set up your development environment, you can work with the 
Openstack nodes by logging into the controller. These instructions are 
not about Ardana specifically, but more about how to work with the 
system deployed by `astack.sh`.
Each model supplied by the `ardana-dev-tools` project has a different 
configuration. You'll always have a deployer node, but the compute and 
control nodes tend to be different across the different models.

* Login to a controller node

  The controller nodes for the `std-min` model start with the `cp#` 
prefix.

```
cd ardana-vagrant-models/std-min-vagrant
./ardana-vagrant ssh cp1-0001
```

* Set up the working environment for the shell

  Ardana nicely gives sourcable scripts that provide all the necessary 
environment variable to work with the Openstack system.

```
source ./service.osrc
```

* Add ssh key to Openstack

  In order to access your instance, you will need to add the public key 
to Openstack

```
openstack keypair create --public-key ~/.ssh/id_rsa.pub server-key
```

* Create network, subnet, and router for instances

  Ardana creates and external network `ext-net` that allows for 
"public" access of instances, but Ardana does not create a network for 
instances. These steps will set up the appropriate internal network 
'int-net' for attaching nodes.
  These steps create a network with a CIDR of 192.168.100.0/24. Do not 
hesitate to change the network range to one of your liking.

```
openstack network create int-net
openstack subnet create --network int-net --subnet-range 
192.168.100.0/24 int-subnet
openstack router create int-router
openstack router add subnet int-router int-subnet
openstack router set --external-gateway ext-net int-router
```

* Create an instance and attach a floating IP

  Now create a simple instance and attach a floating IP address to that 
instance.
  When the floating IP address is created, make note of the address and 
use it when attaching an address to the instance.

```
openstack server create --image cirros-0.4.0-x86_64 --flavor m1.tiny --network int-net --key-name server-key test-server-01
openstack floating ip create ext-net
openstack server add floating ip test-server-01 <floating-ip>
```

* Create security group and rules to allow ssh and ping

  In order to access the instance through the floating IP, the 
necessary security group and rules must be created.

```
openstack security group create ssh-access
openstack security group rule create --ingress --dst-port 22 --protocol tcp ssh-access
openstack security group create ping-access
openstack security group rule create --protocol icmp ping-access
openstack server add security group test-server-01 ssh-access
openstack server add security group test-server-01 ping-access
```

* Use the new Openstack instance

  Using the floating IP created, you may now work with the instance you 
have created

```
ping <ip-address>
ssh cirros@<ip-address>
```

## Conclusion

These instructions should have provided you with the necessary Ardana 
development environment and instructions on how to use the environment. 
At this point, you are the developer: go fix some bugs.

## Thanks

A big *Thank You* to the wonderful people that have helped in the 
creation of these steps. Including:
* Fergal McCarthy - An Ardana Master of the highest order and an 
overall helpful guy
* Adolfo Duarte - A great storehouse of knowledge into the world of 
Openstack networking
* Ryan Tidwell - Neutron master and helpful in many ways
* Nicolas Bock - Man of great patience with my need to create this 
document

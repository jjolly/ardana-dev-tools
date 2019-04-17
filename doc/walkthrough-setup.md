# Ardana Dev Tools Walkthrough
This is a step-by-step journey from the start of a bare system to the 
logging in to an instance within an Ardana-created Openstack Cloud. The 
purpose of this document is not to provide an in-depth functional 
description of Ardana, Openstack, or any of it's components. The 
purpose of this document is to provide the individual command necessary 
to having a working Openstack cloud via Ardana. There may be some 
reasoning and explanation with steps in this document, but nothing will 
be in depth.

This specific document is part one of three in a series. This document 
specifically deals with the setup of a host to support an Ardana 
environment. This includes setting up user security, installing 
required packages, and starting services. Ideally much of the work done 
in this document would be performed in the `bin/dev-env-setup` script 
in the `ardana-dev-tools` project. This file will be modified to 
reflect changes within that script.

## In The Beginning - Creating the foundation for your system
This walkthrough is based on the ardana-dev-tools project from GitHub. 
You can find the project at 
https://github.com/ArdanaCLM/ardana-dev-tools. This project contains a 
set of Vagrant scripts that set up one of many Ardana models. Once the 
Ardana model is set up, then Ardana can start it's work. It's rather 
like the system (ardana-dev-tools using Vagrant) that will set up your 
system (Ardana using Ansible) that will set up your system (Openstack) 
that will set up your system (compute nodes in Openstack).

* Clean install of Leap 15

  This guide expects the host system to have OpenSUSE Leap 15 installed 
for the host operating system. While this guide may be expanded in the 
future to cover SLES and nested virtualzation, for now only one base is 
used.

* Copy a ssh key (public and private) into the host system

  Or create one in the host system. This ssh key will be used to login 
to our final instance.

  There are ways to have Openstack create the public and private key 
for you. I'll leave this key creation as an exercise for the user.

* Add user to sudoers:

  All these commands are to be run from an unprivileged user. Of 
course, how unprivileged is a user when that user is given these rights 
via sudo? That's a philisophical debate outside the scope of this 
document.

  Type in the command:
```
echo ${USER} ALL=(ALL:ALL) NOPASSWD:ALL | sudo tee -a /etc/sudoers.d/90-${USER}-access
```

* Add user to polkit:

  This unprivileged user will be running quite a number of Libvirt 
`virsh` commands. Rather than cheat and use `sudo` to perform our 
virtualization, a rule will be added to PolicyKit to allow the 
unprivileged user to do virtualization.
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

  The `git-core` package is needed for cloning the `ardana-dev-tools` 
project, and `libvirt` is needed to allow the dev tools to run the 
virtualized systems needed for the Ardana system.
```
sudo zypper ref && sudo zypper in git-core libvirt
```

* Enable and start `libvirtd`
```
sudo systemctl enable libvirtd && sudo systemctl start libvirtd
```

* (Optional) Create temporary cache directories "somewhere else"

  Ardana caches a lot of repositories that will be copied to the 
development system, and these cached repositories take up a lot of 
space. This is a real problem if your home directory is located on a 
slower network drive or on a device with limited space. Typicaly I 
would create the directories on a storage device with more space and 
softlink the directories to my home directory.
```
for cachedir in {cache,cache-ardana,ansible}; \
    do mkdir -p ${PATH_TO_ALT_DIR}/${cachedir}; \
    ln -s ${PATH_TO_ALT_DIR}/${cachedir} ~/.${cachedir}; \
done
```

* (Optional) Create a directory to keep one or more source projects.

  I choose to create a `src` directory and store my projected in that 
directory. You know your source organization, do what works best for 
you.
```
mkdir src && cd src
```

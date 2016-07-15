=========
VM Bakery
=========

Baking (building) scripts for VM images.

Can output as a VM image or Vagrant box.

Based on scripts from https://github.com/boxcutter/centos


Prerequisits
************


#. Hypervisor - A virtual machine hypervisor such as VirtualBox, Qemu/KVM, etc.
#. Packer - You need to install Packer on the machine running the build scripts. Packer can be downloaded from http://packer.io


How to build
************

1. Download the appropriate ISO of the OS

The iso and an MD5 file should be saved under one of the following locations:
 #. source_iso directory
 #. An HTTP server, specified in settings.sh (SETTINGS_SOURCE_ISO_HTTP_SERVER)

To create an MD5 file, use the following command:

``md5sum <OS ISO file> > <file name>.md5``

MD5 file name must be the same as the OS ISO file name with an .md5 extension.


    **Note**

    In order to build Guest Additions for Vagrant boxes on VirtualBox use the full DVD iso.
    kernel-devel, gcc, bzip2 and other packages are required and are supplied on the full DVD iso, and not the minimal version.

2. Run the appropriate bake script for the target OS:

``bake_<OS NAME><Version>.sh``

If the script does not exists, you can create it. See instructions below under "Creating bake scripts".


Running using Jenkins
*********************

The baking scripts are fully compatible with Jenkins, and will add the Jenkins build number (passed via the BUILD_NUMBER environment variable) to the final artifact file name.


Creating bake scripts
*********************

You can create new bake scripts by copying an existing script and modifying the parameters:

- PROVIDER: Target hypervisor - kvm, virtualbox, etc
- OSNAME: The target OS Name, for example: CentOS
- OSVERSION: The target OS version, for example 7.1
- OSRELEASE: The target OS release number, for example: 7511
- VAGRANT: true / false - whether to create a vagrant box or a VM image.

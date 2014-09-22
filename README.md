cloudstack-simulator
====================

Packer JSON and Vagrant file to start a Cloudstack simulator


Example use:

packer build -var 'cloudstack_branch=4.3.0-forward' cloudstack-simulator.json 

This will start an Ubuntu 12.04 from iso and install and build cloudstack from source.

will output a box file in ./builds/virtualbox/

vagrant up

will start the vm and create a zone on the simulator




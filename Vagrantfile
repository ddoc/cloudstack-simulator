# -*- mode: ruby -*-
# vi: set ft=ruby :

# Vagrantfile API/syntax version. Don't touch unless you know what you're doing!
VAGRANTFILE_API_VERSION = "2"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  # All Vagrant configuration is done here. The most common configuration
  # options are documented and commented below. For a complete reference,
  # please see the online documentation at vagrantup.com.

  # Every Vagrant virtual environment requires a box to build off of.

  $cloudstackscript = <<SCRIPT
#!/usr/bin/env bash
# set this to the location of your nfs secondary storage
# example: NFSSHARE=10.10.10.10:/xenshare
NFSSHARE=10.10.10.10:/xenshare
# ALSO, update the following line with the routable IP of your computer
mysql -uroot cloud -e "update configuration set value = '10.10.10.10' where name = 'host';"

mysql -uroot cloud -e "update configuration set value = 'true' where name = 'system.vm.use.local.storage';"
mysql -uroot cloud -e "update configuration set value = 'false' where name = 'router.version.check';"

# restart cloudstack so these changes take effect
/etc/init.d/cloudstack-simulator restart

# vhd-util
cd /automation/cloudstack/scripts/vm/hypervisor/xenserver
wget http://download.cloud.com.s3.amazonaws.com/tools/vhd-util
chmod +x vhd-util

# Create Xenserver tmplt
cd /automation/cloudstack
mkdir -p /etc/cloudstack/management
cp utils/conf/db.properties /etc/cloudstack/management
echo trying to mount sec storage: ${NFSSHARE}
mount ${NFSSHARE} /mnt && /automation/cloudstack/scripts/storage/secondary/cloud-install-sys-tmplt -F -m /mnt -u http://d21ifhcun6b1t2.cloudfront.net/templates/4.2/systemvmtemplate-2013-07-12-master-xen.vhd.bz2 -h xenserver && umount /mnt

# Deploy zone
while ! nc -vz localhost 8080 2>/dev/null; do sleep 10; done # Wait for CloudStack to start
unset MAVEN_OPTS
mvn -Pdeveloper,marvin.setup -Dmarvin.config=../../vagrant/simulator-advanced.cfg -pl :cloud-marvin integration-test

SCRIPT

  config.vm.define "cloudstack" do |cloudstack|
    cloudstack.vm.boot_timeout = 600
    cloudstack.vm.network "forwarded_port", guest: 8080, host: 8080
    cloudstack.vm.network "forwarded_port", guest: 8250, host: 8250 
    cloudstack.vm.box = "bgalura/cloudstack-simulator4_3_forward"
    cloudstack.vm.provision :shell, inline: $cloudstackscript 
    cloudstack.vm.provider "virtualbox" do |v|
      v.memory = 1024 
    end
  end 

  # config.vm.provision "puppet" do |puppet|
  #   puppet.manifests_path = "manifests"
  #   puppet.manifest_file  = "site.pp"
  # end

end

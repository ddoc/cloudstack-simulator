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
cd /automation/cloudstack
nohup mvn -pl client jetty:run -Dsimulator &

# Deploy zone
while ! nc -vz localhost 8080 2>/dev/null; do sleep 10; done # Wait for CloudStack to start
unset MAVEN_OPTS
mvn -Pdeveloper,marvin.setup -Dmarvin.config=../../vagrant/simulator-advanced.cfg -pl :cloud-marvin integration-test

SCRIPT

  config.vm.define "cloudstack" do |cloudstack|
    cloudstack.vm.boot_timeout = 600
    cloudstack.vm.network "forwarded_port", guest: 8080, host: 8080
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

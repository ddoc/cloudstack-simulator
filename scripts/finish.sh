#!/bin/bash
branch=${cloudstack_branch}

echo mysql-server-5.5 mysql-server/root_password password password| debconf-set-selections -v
echo mysql-server-5.5 mysql-server/root_password_again password password| debconf-set-selections -v
apt-get update
apt-get install -y nfs-kernel-server python-setuptools maven python-pip dnsmasq openjdk-6-jdk libmysql-java mysql-client git mysql-server-5.5 python-dev 
mysql -u root -ppassword -e "SET PASSWORD FOR root@localhost=PASSWORD('');"

echo "==== Download CS Code ===="
repo_url='https://github.com/apache/cloudstack.git'

mkdir -p /automation/cloudstack
cd /automation/cloudstack
git init
git fetch $repo_url $branch:refs/remotes/origin/$branch
git checkout 4.3.0-forward

echo "==== Simulator config and start ===="
cd /automation/cloudstack
mvn clean install -Pdeveloper -DskipTests -Dsimulator 
mvn -Pdeveloper -pl developer -Dsimulator -DskipTests clean install
mvn -Pdeveloper -pl developer -Ddeploydb
mvn -Pdeveloper -pl developer -Ddeploydb-simulator
mysql -uroot cloud -e "update configuration set value = 'false' where name = 'router.version.check';"
mysql -uroot cloud -e "update user set api_key = 'F0Hrpezpz4D3RBrM6CBWadbhzwQMLESawX-yMzc5BCdmjMon3NtDhrwmJSB1IBl7qOrVIT4H39PTEJoDnN-4vA' where id = 2;"
mysql -uroot cloud -e "update user set secret_key = 'uWpZUVnqQB4MLrS_pjHCRaGQjX62BTk_HU8uiPhEShsY7qGsrKKFBLlkTYpKsg1MzBJ4qWL0yJ7W7beemp-_Ng' where id = 2;"
cd /automation/cloudstack/tools/marvin
python setup.py install

mkdir -p /storage/secondary
mkdir -p /storage/primary0
mkdir -p /storage/primary1
mkdir -p /storage/primary2
echo "/storage/secondary *(rw,no_subtree_check,no_root_squash,fsid=0)" > /etc/exports
echo "/storage/primary0 *(rw,no_subtree_check,no_root_squash,fsid=0)" >> /etc/exports
echo "/storage/primary1 *(rw,no_subtree_check,no_root_squash,fsid=0)" >> /etc/exports
echo "/storage/primary2 *(rw,no_subtree_check,no_root_squash,fsid=0)" >> /etc/exports
/etc/init.d/nfs-kernel-server restart

# virtualbox
# Without libdbus virtualbox would not start automatically after compile
apt-get -y install --no-install-recommends libdbus-1-3

# The netboot installs the VirtualBox support (old) so we have to remove it
/etc/init.d/virtualbox-ose-guest-utils stop
rmmod vboxguest
aptitude -y purge virtualbox-ose-guest-x11 virtualbox-ose-guest-dkms virtualbox-ose-guest-utils
aptitude -y install dkms

# Install the VirtualBox guest additions
VBOX_VERSION=$(cat /home/vagrant/.vbox_version)
wget http://download.virtualbox.org/virtualbox/4.3.16/VBoxGuestAdditions_4.3.16.iso
VBOX_ISO=VBoxGuestAdditions_4.3.16.iso
mount -o loop $VBOX_ISO /mnt
yes|sh /mnt/VBoxLinuxAdditions.run
umount /mnt

#Cleanup VirtualBox
rm $VBOX_ISO

# vagrant
groupadd vagrant -g 4999
useradd vagrant -g vagrant -u 4900 -p `mkpasswd vagrant`

# sudo
apt-get install -y sudo
echo "vagrant        ALL=(ALL)       NOPASSWD: ALL" >> /etc/sudoers
sed -i "s/^.*requiretty/#Defaults requiretty/" /etc/sudoers

#ssh
echo "UseDNS no" >> /etc/ssh/sshd_config
mkdir -p /home/vagrant/.ssh
wget --no-check-certificate \
    'https://github.com/mitchellh/vagrant/raw/master/keys/vagrant.pub' \
    -O /home/vagrant/.ssh/authorized_keys
chown -R vagrant /home/vagrant/.ssh
chmod -R go-rwsx /home/vagrant/.ssh


dd if=/dev/zero of=/EMPTY bs=1M
rm -f /EMPTY
# Block until the empty file has been removed, otherwise, Packer
# will try to kill the box while the disk is still full and that's bad
sync

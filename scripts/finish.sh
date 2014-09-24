#!/bin/bash
branch=${cloudstack_branch}

echo mysql-server-5.5 mysql-server/root_password password password| debconf-set-selections -v
echo mysql-server-5.5 mysql-server/root_password_again password password| debconf-set-selections -v
apt-get update
apt-get install -y chkconfig nfs-kernel-server python-setuptools maven python-pip dnsmasq openjdk-6-jdk libmysql-java mysql-client git mysql-server-5.5 python-dev 
mysql -u root -ppassword -e "SET PASSWORD FOR root@localhost=PASSWORD('');"

echo "==== Download CS Code ===="
repo_url='https://github.com/apache/cloudstack.git'

mkdir -p /automation/cloudstack
cd /automation/cloudstack
git init
git fetch $repo_url $branch:refs/remotes/origin/$branch
git checkout $branch 

echo "==== Simulator config and start ===="
cd /automation/cloudstack
mvn clean install -Pdeveloper -DskipTests -Dsimulator 
mvn -Pdeveloper -pl developer -Dsimulator -DskipTests clean install
mvn -Pdeveloper -pl developer -Ddeploydb
mvn -Pdeveloper -pl developer -Ddeploydb-simulator
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
aptitude -y purge virtualbox-ose-guest-x11 virtualbox-ose-guest-dkms virtualbox-ose-guest-utils
aptitude -y install dkms

# Install the VirtualBox guest additions
mkdir -p /mnt/virtualbox
mount -o loop /home/vagrant/VBoxGuest*.iso /mnt/virtualbox
yes|sh /mnt/virtualbox/VBoxLinuxAdditions.run
umount /mnt/virtualbox
rm -rf /home/vagrant/VBoxGuest*.iso

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

# init script
cat > /etc/init.d/cloudstack-simulator <<'SCRIPT'
#!/bin/bash
#
# cloudstack-simulator CloudStack Simulator
#
# chkconfig: 345 50 50
# description: CloudStack Simulator Service

M2_HOME=/usr/share/maven
PATH=${M2_HOME}/bin:${PATH}
CLOUDSTACK_HOME=/automation/cloudstack/
CLOUDSTACK_LOGFILE=/vagrant/cloudstack-simulator.log

case "$1" in
  start)
    echo -n "Starting CloudStack Simulator: "
    cd $CLOUDSTACK_HOME
    nohup mvn -Dnet.sf.ehcache.disabled=true -Dsimulator -pl client jetty:run > $CLOUDSTACK_LOGFILE 2>&1 &
    echo "OK"
    ;;
  stop)
    echo -n "Stopping CloudStack Simulator: "
    cd $CLOUDSTACK_HOME
    mvn -Dsimulator -pl client jetty:stop
    echo "OK"
    ;;
  reload|restart)
    $0 stop
    $0 start
    ;;
  *)
    echo "Usage: $0 start|stop|restart|reload"
    exit 1
esac
exit 0

SCRIPT
chmod +x /etc/init.d/cloudstack-simulator
cd /automation/cloudstack
nohup mvn -Dnet.sf.ehcache.disabled=true -Dsimulator -pl client jetty:run &
while ! nc -vz localhost 8080; do sleep 10; done # Wait for CloudStack to start
mysql -uroot cloud -e "update configuration set value = 'false' where name = 'router.version.check';"
mysql -uroot cloud -e "update user set api_key = 'F0Hrpezpz4D3RBrM6CBWadbhzwQMLESawX-yMzc5BCdmjMon3NtDhrwmJSB1IBl7qOrVIT4H39PTEJoDnN-4vA' where id = 2;"
mysql -uroot cloud -e "update user set secret_key = 'uWpZUVnqQB4MLrS_pjHCRaGQjX62BTk_HU8uiPhEShsY7qGsrKKFBLlkTYpKsg1MzBJ4qWL0yJ7W7beemp-_Ng' where id = 2;"
/etc/init.d/cloudstack-simulator stop

# chkconfig
ln -s /usr/lib/insserv/insserv /sbin/insserv
chkconfig --level 345 cloudstack-simulator on
chkconfig --level 345 mysql on

sudo apt-get clean

dd if=/dev/zero of=/EMPTY bs=1M
rm -f /EMPTY
# Block until the empty file has been removed, otherwise, Packer
# will try to kill the box while the disk is still full and that's bad
sync

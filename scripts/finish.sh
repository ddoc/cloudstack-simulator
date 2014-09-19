#!/bin/bash

# update root certs
#wget -O/etc/pki/tls/certs/ca-bundle.crt http://curl.haxx.se/ca/cacert.pem

echo xcp-networkd xcp-xapi/networking_type string openvswitch| debconf-set-selections -v
echo mysql-server-5.5 mysql-server/root_password password password| debconf-set-selections -v
echo mysql-server-5.5 mysql-server/root_password_again password password| debconf-set-selections -v
apt-get install -y git vim tcpdump ebtables --no-install-recommends
apt-get install -f -y 
apt-get install -y openjdk-6-jdk genisoimage python-pip mysql-server nfs-kernel-server --no-install-recommends
apt-get install -y linux-headers-3.2.0-4-686-pae xen-hypervisor-4.1-i386 xcp-xapi xcp-xe xcp-guest-templates xcp-vncterm xen-tools blktap-utils blktap-dkms qemu-keymaps qemu-utils --no-install-recommends
apt-get install -f -y 
apt-get install -y linux-headers-3.2.0-4-686-pae xen-hypervisor-4.1-i386 xcp-xapi xcp-xe xcp-guest-templates xcp-vncterm xen-tools blktap-utils blktap-dkms qemu-keymaps qemu-utils --no-install-recommends

pip install mysql-connector-python 

echo "bridge" > /etc/xcp/network.conf
update-rc.d xendomains disable
echo TOOLSTACK=xapi > /etc/default/xen
sed -i 's/GRUB_DEFAULT=.\+/GRUB_DEFAULT="Xen 4.1-i386"/' /etc/default/grub
sed -i 's/GRUB_CMDLINE_LINUX=.\+/GRUB_CMDLINE_LINUX="apparmor=0"\nGRUB_CMDLINE_XEN="dom0_mem=400M,max:500M dom0_max_vcpus=1"/' /etc/default/grub
update-grub
sed -i 's/VNCTERM_LISTEN=.\+/VNCTERM_LISTEN="-v 0.0.0.0:1"/' /usr/lib/xcp/lib/vncterm-wrapper
cat > /usr/lib/xcp/plugins/echo << EOF
#!/usr/bin/env python

# Simple XenAPI plugin
import XenAPIPlugin, time

def main(session, args):
    if args.has_key("sleep"):
        secs = int(args["sleep"])
        time.sleep(secs)
    return "args were: %s" % (repr(args))

if __name__ == "__main__":
    XenAPIPlugin.dispatch({"main": main})
EOF

chmod -R 777 /usr/lib/xcp
mkdir -p /root/.ssh
ssh-keygen -A -q

cat > /etc/network/interfaces <<DONE
auto lo
iface lo inet loopback

auto eth0
allow-hotplug eth0
iface eth0 inet manual

iface eth1 inet manual

auto xenbr0
iface xenbr0 inet static
        bridge_ports eth1
        address 192.168.56.10
        netmask 255.255.255.0
        network 192.168.56.0
        broadcast 192.168.56.255
        gateway 192.168.56.1
        dns_nameservers 8.8.8.8 8.8.4.4
        post-up route del default gw 192.168.56.1; route add default gw 192.168.56.1 metric 100;

auto xenbr1
iface xenbr1 inet dhcp
        bridge_ports eth0
        dns_nameservers 8.8.8.8 8.8.4.4
        post-up route add default gw 10.0.3.2
DONE

mkdir -p /opt/storage/secondary
mkdir -p /opt/storage/primary
hostuuid=`xe host-list |grep uuid|awk '{print $5}'`
xe sr-create host-uuid=$hostuuid name-label=local-storage shared=false type=file device-config:location=/opt/storage/primary
echo "/opt/storage/secondary *(rw,no_subtree_check,no_root_squash,fsid=0)" > /etc/exports
#preseed systemvm template, may be copy files from devcloud's /opt/storage/secondary
/etc/init.d/nfs-kernel-server restart

mysql -u root -ppassword -e "SET PASSWORD FOR root@localhost=PASSWORD('');"

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

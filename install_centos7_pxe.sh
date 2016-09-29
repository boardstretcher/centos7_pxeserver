#!/bin/bash

# get server, dhcp info from user
echo "This server's IP Address: "; read serverip;
echo "This server's subnet address: "; read subnet;
echo "This server's subnet mask: "; read mask;
echo "DHCP Range to use: "; read range;
echo "DNS server: "; read dns;
echo "Gateway :"; read gateway;
echo "Broadcast: "; read broadcast;

# update system and install required packages
yum -y update
yum -y install httpd xinetd syslinux tftp tftp-server dhcp vim

# disable firewall
systemctl disable firewalld; systemctl stop firewalld

# disable selinux
cat << EOF > /etc/sysconfig/selinux
SELINUX=disabled
SELINUXTYPE=targeted
EOF

# create the dhcp server config
cat << EOF > /etc/dhcp/dhcpd.conf
ddns-update-style interim;
 ignore client-updates;
 authoritative;
 allow booting;
 allow bootp;
 allow unknown-clients;
 subnet $subnet netmask $mask {
 range $range;
 option domain-name-servers $dns;
 option routers $gateway;
 option broadcast-address $broadcast;
 default-lease-time 600;
 max-lease-time 7200;
 next-server $serverip; #MODIFY
 filename "pxelinux.0";
 }
EOF

# enable tftp in xinetd
sed -i 's/disable.*=.*yes/disable = no/' /etc/xinetd.d/tftp

# copy centos pxe files to tftp server
mkdir -p /var/lib/tftpboot/centos7
cp -v /usr/share/syslinux/pxelinux.0 /var/lib/tftpboot/
cp -v /usr/share/syslinux/menu.c32 /var/lib/tftpboot/
cp -v /usr/share/syslinux/memdisk /var/lib/tftpboot/
cp -v /usr/share/syslinux/mboot.c32 /var/lib/tftpboot/
cp -v /usr/share/syslinux/chain.c32 /var/lib/tftpboot/

# get centos iso and mount
cd /root
curl -C - -O http://mirror.vtti.vt.edu/centos/7/isos/x86_64/CentOS-7-x86_64-Minimal-1511.iso
mount -o loop /root/XenServer-7.0.0-main.iso /mnt
cd /mnt

# create tftp boot menu
mkdir /var/lib/tftpboot/pxelinux.cfg
cat << EOF > /var/lib/tftpboot/pxelinux.cfg/default
DEFAULT local
UI menu.c32
PROMPT 1
TIMEOUT 60
LABEL local
        localboot 0
LABEL centos7_x64
 MENU LABEL CentOS 7 X64
 KERNEL /centos7/vmlinuz
 APPEND  initrd=/centos7/initrd.img  inst.repo=http://$serverip/centos7  ks=http://$serverip/ks.cfg
EOF

# create kickstart for config
cat << EOF > /var/www/html/ks.cfg
firewall --disabled
install
url --url="http://$serverip/centos7/"
# pw = r00tme
rootpw --iscrypted /hNTxhbZeFodHAO.D9uC.
auth  useshadow  passalgo=sha512
graphical
firstboot disable
keyboard us
lang en_US
selinux disabled
logging level=info
timezone America/Detroit
bootloader location=mbr
clearpart --all --initlabel
part swap --asprimary --fstype="swap" --size=1024
part /boot --fstype xfs --size=200
part pv.01 --size=1 --grow
volgroup rootvg01 pv.01
logvol / --fstype xfs --name=lv01 --vgname=rootvg01 --size=1 --grow

%packages
 @core
 %end
 %post
 %end
EOF

# copy installation packages to apache
cd /mnt
mkdir /var/www/html/centos7
rsync -varh --progress . /var/www/html/centos7/

# enable and restart all services - look for errors
systemctl enable xinetd; systemctl restart xinetd
systemctl enable httpd; systemctl restart httpd
systemctl enable dhcpd; systemctl restart dhcpd
reboot

# Modify this file BEFORE running it and Remove the 'exit' command to run the file
# 
# Search for #MODIFY and 192.168.201 and input the correct IP addresses for your environment

# This will install PXE/Dhcp and will serve up the Centos7 ISO with a kickstart file for
# autoinstallation

exit

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
 subnet 192.168.201.0 netmask 255.255.255.0 { #MODIFY
 range 192.168.201.55 192.168.201.59; #MODIFY
 option domain-name-servers 4.2.2.3; #MODIFY
 option routers 192.168.201.100; #MODIFY
 option broadcast-address 192.168.201.255;  #MODIFY
 default-lease-time 600;
 max-lease-time 7200;
 next-server 192.168.201.44; #MODIFY
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
 APPEND  initrd=/centos7/initrd.img  inst.repo=http://192.168.201.44/centos7  ks=http://192.168.201.44/ks.cfg
EOF

# create kickstart for config
cat << EOF > /var/www/html/ks.cfg
firewall --disabled
install
url --url="http://192.168.201.44/centos7/"
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
 wget
 net-tools
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

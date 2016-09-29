# Modify this file BEFORE running it and Remove the 'exit' command to run the file
# 
# Search for #MODIFY and 192.168.201 and input the correct IP addresses for your environment

# This will install PXE/Dhcp and will serve up the Xenserver ISO with an answer file for
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

# download and mount xenserver iso
cd /root
curl -C - -O http://downloadns.citrix.com.edgesuite.net/11616/XenServer-7.0.0-main.iso
mount -o loop /root/XenServer-7.0.0-main.iso /mnt
cd /mnt

# enable tftp in xinetd
sed -i 's/disable.*=.*yes/disable = no/' /etc/xinetd.d/tftp

# copy xenserver pxe files to tftp server
mkdir -p /var/lib/tftpboot/xenserver
cp ./boot/pxelinux/mboot.c32 /var/lib/tftpboot
cp ./boot/pxelinux/pxelinux.0 /var/lib/tftpboot
cp ./boot/vmlinuz /var/lib/tftpboot/xenserver
cp ./boot/xen.gz /var/lib/tftpboot/xenserver
cp ./install.img /var/lib/tftpboot/xenserver
cp /usr/share/syslinux/menu.c32 /var/lib/tftpboot/

# create tftp boot menu
mkdir /var/lib/tftpboot/pxelinux.cfg
cat << EOF > /var/lib/tftpboot/pxelinux.cfg/default
DEFAULT local
UI menu.c32
PROMPT 1
TIMEOUT 60
LABEL local
        localboot 0
LABEL install xenserver
        kernel mboot.c32
        append xenserver/xen.gz dom0_max_vcpus=2 dom0_mem=752M com1=115200,8n1 console=com1,vga --- xenserver/vmlinuz xencons=hvc console=hvc0 console=tty0 answerfile=http://192.168.201.44/answerfile install --- xenserver/install.img
EOF

# create xenserver answerfile for config
cat << EOF > /var/www/html/answerfile
<?xml version="1.0"?>
<installation srtype="ext">
<primary-disk>sda</primary-disk>
<keymap>us</keymap>
<root-password>#MODIFY</root-password>
<source type="url">http://192.168.201.44/xenserver/#MODIFY</source>
<ntp-server>#MODIFY</ntp-server>
<admin-interface name="eth0" proto="dhcp" />
<timezone>America/Detroit</timezone>
</installation>
EOF

# copy installation packages to apache
cd /mnt
mkdir /var/www/html/xenserver
rsync -varh --progress . /var/www/html/xenserver/

# enable and restart all services - look for errors
systemctl enable xinetd; systemctl restart xinetd
systemctl enable httpd; systemctl restart httpd
systemctl enable dhcpd; systemctl restart dhcpd
reboot

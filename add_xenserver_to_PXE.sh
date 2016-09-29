# Add XenServer 7.0 to your PXE boot environment selection

# get server info from user
echo "================= Example answers ====================="
echo "This server's IP Address: 192.168.1.42"
echo "======================================================="
echo -n "This server's IP Address: "; read serverip;

# download and mount xenserver iso
cd /root
umount /mnt
curl -C - -O http://downloadns.citrix.com.edgesuite.net/11616/XenServer-7.0.0-main.iso
mount -o loop /root/XenServer-7.0.0-main.iso /mnt
cd /mnt

# copy xenserver pxe files to tftp server
mkdir -p /var/lib/tftpboot/xenserver
cp ./boot/vmlinuz /var/lib/tftpboot/xenserver
cp ./boot/xen.gz /var/lib/tftpboot/xenserver
cp ./install.img /var/lib/tftpboot/xenserver

# create tftp boot menu
mkdir /var/lib/tftpboot/pxelinux.cfg
cat << EOF >> /var/lib/tftpboot/pxelinux.cfg/default
LABEL install xenserver
        kernel mboot.c32
        append xenserver/xen.gz dom0_max_vcpus=2 dom0_mem=752M com1=115200,8n1 console=com1,vga --- xenserver/vmlinuz xencons=hvc console=hvc0 console=tty0 answerfile=http://$serverip/answerfile install --- xenserver/install.img
EOF

# create xenserver answerfile for config
cat << EOF > /var/www/html/answerfile
<?xml version="1.0"?>
<installation srtype="ext">
<primary-disk>sda</primary-disk>
<keymap>us</keymap>
<root-password>#MODIFY</root-password>
<source type="url">http://$serverip/xenserver/#MODIFY</source>
<ntp-server>pool.ntp.org</ntp-server>
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

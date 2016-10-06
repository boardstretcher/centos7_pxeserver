# Add XenServer 7.0 to your PXE boot environment selection

# get server info from user
echo "================= Example answers ====================="
echo "This server's IP Address: 192.168.1.42"
echo "Timezone                : America/Detroit"
echo "Xenserver's IP Address  : 192.168.1.55"
echo "Xenserver's Subnet      : 255.255.255.0"
echo "Xenserver's Gateway     : 192.168.1.1"
echo "======================================================="
echo -n "This server's IP Address: "; read serverip;
echo -n "This server's Timezone  : "; read timezone;
echo -n "XenMaster IP Address: "; read xenip;
echo -n "XenMaster Subnet: "; read xensub;
echo -n "XenMaster Gateway: "; read xengw;

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
LABEL install xenserver_master
        kernel mboot.c32
        append xenserver/xen.gz dom0_max_vcpus=2 dom0_mem=2048M,max:2048M com1=115200,8n1 console=com1,vga --- xenserver/vmlinuz xencons=hvc console=hvc0 console=tty0 answerfile=http://$serverip/answerfile_master install --- xenserver/install.img
LABEL install xenserver_slave
        kernel mboot.c32
        append xenserver/xen.gz dom0_max_vcpus=2 dom0_mem=2048M,max:2048M com1=115200,8n1 console=com1,vga --- xenserver/vmlinuz xencons=hvc console=hvc0 console=tty0 answerfile=http://$serverip/answerfile_slave install --- xenserver/install.img
EOF

# create xenserver answerfile for config
cat << EOF > /var/www/html/answerfile_master
<?xml version="1.0"?>
<installation srtype="ext">
<primary-disk>sda</primary-disk>
<keymap>us</keymap>
<root-password>r00tme</root-password>
<source type="url">http://$serverip/xenserver/</source>
<ntp-server>pool.ntp.org</ntp-server>
<admin-interface name="eth0" proto="static">
<ipaddr>$xenip</ipaddr>
<subnet>$xensub</subnet>
<gateway>$xengw</gateway>
</admin-interface>
<timezone>$timezone</timezone>
</installation>
EOF

cat << EOF > /var/www/html/answerfile_slave
<?xml version="1.0"?>
<installation srtype="ext">
<primary-disk>sda</primary-disk>
<keymap>us</keymap>
<root-password>r00tme</root-password>
<source type="url">http://$serverip/xenserver/</source>
<ntp-server>pool.ntp.org</ntp-server>
<admin-interface name="eth0" proto="dhcp" />
<script stage="installation-complete" type="url">
http://$serverip/grab-postinstall.sh</script>
<timezone>$timezone</timezone>
</installation>
EOF

cat << EOF > /var/www/html/grab-postinstall.sha
#!/bin/sh
touch /tmp/post-executed
wget http://$serverip/first-run.sh -O /tmp/first-run.sh
chmod 755 /tmp/first-run.sh 
ln -s /tmp/first-run.sh /etc/rc3.d/S99zzpostinstall
EOF

cat << EOF > /var/www/html/first-run.sh
#!/bin/bash
xe pool-join master-address=$xenip master-username=root master-password=r00tme
EOF

# copy installation packages to apache
cd /mnt
mkdir /var/www/html/xenserver
rsync -varh --progress . /var/www/html/xenserver/

# enable and restart all services - look for errors
systemctl enable xinetd; systemctl restart xinetd
systemctl enable httpd; systemctl restart httpd
systemctl enable dhcpd; systemctl restart dhcpd

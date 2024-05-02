#!/bin/bash
IP=$1
# Install bogus-jce-jdk1.8.0_73-1.0-0.el7.x86_64.rpm
wget http://$IP/kickstart/extras/bogus-jce-jdk1.8.0_73-1.0-0.el7.x86_64.rpm
rpm -ivh  bogus-jce-jdk1.8.0_73-1.0-0.el7.x86_64.rpm 
rm -rf bogus-jce-jdk1.8.0_73-1.0-0.el7.x86_64.rpm

# Install racadm
cd /tmp
wget -r --no-parent  http://${IP}/kickstart/extras/dell/
cd /tmp/${IP}/kickstart/extras/dell/
rpm -ivh libsmbios* smbios-utils-bin*
rpm -ivh srvadmin-*
cd /tmp
rm -rf ${IP}

# Edit grub
sed -i 's/GRUB_TERMINAL_OUTPUT="console"/GRUB_TERMINAL="serial console"/' /etc/default/grub
grub2-mkconfig -o /boot/grub2/grub.cfg

# add repo for pkgs
cat <<EOF > /etc/yum.repos.d/post-install.repo
[post-install]
name=post-install
baseurl=http://192.168.1.2/kickstart/install/centos-7.4-updates/
gpgcheck=0
enabled=1
priority=1
EOF
script -c 'yum --disablerepo=* --enablerepo=post-install update -y' update-post-install.output
rm -rf /etc/yum.repos.d/post-install.repo


# add repos
mkdir -p /etc/yum/vars
echo CentOS > /etc/yum/vars/osname
cd /etc/yum.repos.d/

cat <<EOF > os.repo
[CentOS-7]
name=CentOS-7-x86_64
baseurl=http://bogushost.blahblah.com/repo/\$osname/\$releasever/os/\$basearch
enabled=1
gpgcheck=0

[CentOS-7-updates]
name=CentOS-7-updates-x86_64
baseurl=http://bogushost.blahblah.com/repo/\$osname/\$releasever/updates/\$basearch
enabled=1
gpgcheck=0
EOF

cat <<EOF > epel.repo
[epel]
name=epel-\$releasever-\$basearch
baseurl=http://bogushost.blahblah.com/repo/epel/\$releasever/\$basearch
enabled=1
gpgcheck=0
EOF

cat <<EOF > bogus.repo
[bogus-bogus-misc]
name=bogus-bogus-misc
baseurl=http://bogushost.blahblah.com/repo/bogus-bogus/misc/\$releasever/\$basearch
gpgcheck=0
enabled=1
priority=1

[bogus-bogus-jdk]
name=bogus-bogus-jdk
baseurl=http://bogushost.blahblah.com/repo/bogus-bogus/jdk/\$releasever/\$basearch
gpgcheck=0
enabled=1
priority=1

[bogus-bogus-ruby]
name=bogus-bogus-ruby
baseurl=http://bogushost.blahblah.com/repo/bogus-bogus/ruby/\$releasever/\$basearch
gpgcheck=0
enabled=1
priority=1

[ansible]
name=bogus-ansible
baseurl=http://bogushost.blahblah.com/repo/ansible/\$releasever/\$basearch
enabled=1
gpgcheck=0
priority=1
EOF

cat <<EOF > zabbix.repo
[bogus-zabbix]
name=bogus-zabbix
baseurl=http://bogushost.blahblah.com/repo/zabbix/\$releasever/\$basearch
gpgcheck=0
enabled=1
priority=1
EOF

# edit ntp.conf
cat <<EOF > /etc/ntp.conf
driftfile /var/lib/ntp/drift
restrict default nomodify notrap nopeer noquery
restrict 127.0.0.1
restrict ::1
server bogusntp1.blahblah.com iburst
server bogusntp2.blahblah.com iburst
includefile /etc/ntp/crypto/pw
keys /etc/ntp/keys
disable monitor
EOF

# add step tickers
cat <<EOF > /etc/ntp/step-tickers
bogusntp1.blahblah.com
bogusntp2.blahblah.com
EOF

# Add /etc/sysctl.d/101-b.conf
cat<<EOF > /etc/sysctl.d/101-b.conf
kernel.core_uses_pid=1
kernel.msgmax=65536
kernel.msgmnb=65536
kernel.sysrq=0
net.core.rmem_max=8388608
net.core.somaxconn=1024
net.core.wmem_max=8388608
net.ipv4.conf.default.accept_source_route=0
net.ipv4.conf.default.rp_filter=1
net.ipv4.ip_forward=0
net.ipv4.tcp_dsack=0
net.ipv4.tcp_fin_timeout=30
net.ipv4.tcp_keepalive_time=360
net.ipv4.tcp_max_tw_buckets=1440000
net.ipv4.tcp_rmem=4096  87380   8388608
net.ipv4.tcp_sack=0
net.ipv4.tcp_syncookies=1
net.ipv4.tcp_timestamps=0
net.ipv4.tcp_tw_recycle=1
net.ipv4.tcp_tw_reuse=1
net.ipv4.tcp_window_scaling=1
net.ipv4.tcp_wmem=4096  87380   8388608
vm.swappiness=0
EOF

# Add quotes around bond0 slave {1,2}.
cd /etc/sysconfig/network-scripts
sed -i -e 's/NAME=bond0\ slave\ 1/NAME=\"bond0\ slave\ 1\"/' ifcfg-bond0_slave_1
sed -i -e 's/NAME=bond0\ slave\ 2/NAME=\"bond0\ slave\ 2\"/' ifcfg-bond0_slave_2
# Add dns=none so that Network Manager does not trample /etc/resolv.conf
sed -i -e '/plugins/a dns=none' /etc/NetworkManager/NetworkManager.conf

# add PEERDNS=no to all interfaces, except local 
for ifcfg in $(ls -1v ifcfg-* | grep -v ifcfg-lo) ; do 
   echo PEERDNS=no >> $ifcfg 
done

# Make sure resolv.conf is correct
cd /etc/
rm -rf /etc/resolv.conf
cat <<EOF > /etc/resolv.conf
domain blahblah.blah.com
nameserver 192.168.1.2
nameserver 192.168.1.3
search blahblah.blah.com blah.againblah.com
options timeout:1 rotate
EOF

chmod 644 resolv.conf

# change UUID to LABEL for boot / and swap
cat <<EOF > /tmp/editFstab.bash
#!/bin/bash
UUID124=`blkid -o value -s UUID /dev/md124`
UUID125=`blkid -o value -s UUID /dev/md125`
UUID126=`blkid -o value -s UUID /dev/md126`
UUID127=`blkid -o value -s UUID /dev/md127`
fstabswapUUID=`grep swap /etc/fstab | cut -d= -f2 | cut -d" " -f1`
fstabbootUUID=`grep boot /etc/fstab | grep -v efi | cut -d= -f2 | cut -d" " -f1`
fstabrootUUID=`grep " / " /etc/fstab | cut -d= -f2 | cut -d" " -f1`

if [ \$UUID124 = \$fstabswapUUID ]; then
   sed -i "s/UUID=\$fstabswapUUID/LABEL=swap/g" /etc/fstab
elif [ \$UUID125 = \$fstabswapUUID ]; then
   sed -i "s/UUID=\$fstabswapUUID/LABEL=swap/g" /etc/fstab
elif [ \$UUID126 = \$fstabswapUUID ]; then
   sed -i "s/UUID=\$fstabswapUUID/LABEL=swap/g" /etc/fstab
elif [ \$UUID127 = \$fstabswapUUID ]; then
   sed -i "s/UUID=\$fstabswapUUID/LABEL=swap/g" /etc/fstab
fi
if [ \$UUID124 = \$fstabrootUUID ]; then
   sed -i "s/UUID=\$fstabrootUUID/LABEL=\/\ /g" /etc/fstab
elif [ \$UUID125 = \$fstabrootUUID ]; then
   sed -i "s/UUID=\$fstabrootUUID/LABEL=\/\ /g" /etc/fstab
elif [ \$UUID126 = \$fstabrootUUID ]; then
   sed -i "s/UUID=\$fstabrootUUID/LABEL=\/\ /g" /etc/fstab
elif [ \$UUID127 = \$fstabrootUUID ]; then
   sed -i "s/UUID=\$fstabrootUUID/LABEL=\/\ /g" /etc/fstab
fi
if [ \$UUID124 = \$fstabbootUUID ]; then
   sed -i "s/UUID=\$fstabbootUUID/LABEL=boot\ /g" /etc/fstab
elif [ \$UUID125 = \$fstabbootUUID ]; then
   sed -i "s/UUID=\$fstabbootUUID/LABEL=boot\ /g" /etc/fstab
elif [ \$UUID126 = \$fstabbootUUID ]; then
   sed -i "s/UUID=\$fstabbootUUID/LABEL=boot\ /g" /etc/fstab
elif [ \$UUID127 = \$fstabbootUUID ]; then
   sed -i "s/UUID=\$fstabbootUUID/LABEL=boot\ /g" /etc/fstab
fi
EOF

bash -xv /tmp/editFstab.bash
rm -rf /tmp/editFstab.bash

# BONDING_OPTS sometimes does not have all options in ifcfg-bond0 after reboot. Fix it. Add validation script to /tmp.
cd /tmp
cat <<EOF > /tmp/validate.sh
#!/bin/bash
HOST=`hostname`
FILE=\${HOST}_validation.txt
echo "=== \$HOST  ===" >> /tmp/\$FILE
echo " " >> /tmp/\$FILE
echo "=== OS release ===" >> /tmp/\$FILE
cat /etc/os-release >> /tmp/\$FILE
echo " " >> /tmp/\$FILE
echo "=== Kernel info ===" >> /tmp/\$FILE
grubby --info=ALL >> /tmp/\$FILE
echo " " >> /tmp/\$FILE
echo "=== bogus-jce-jdk1.8.0_73-1.0-0.el7.x86_64 ===" >> /tmp/\$FILE
rpm -q bogus-jce-jdk1.8.0_73-1.0-0.el7.x86_64 >> /tmp/\$FILE
echo " " >> /tmp/\$FILE
echo "=== df ===" >> /tmp/\$FILE
df -lh | sort -k 5 >> /tmp/\$FILE
echo " " >> /tmp/\$FILE
echo "=== lsblk ===" >> /tmp/\$FILE
lsblk -o name,mountpoint,label,size >> /tmp/\$FILE
echo " " >> /tmp/\$FILE
echo "=== IP Address ===" >> /tmp/\$FILE
ip addr show bond0 >> /tmp/\$FILE
echo " " >> /tmp/\$FILE
#echo "=== ifcfg-bond0 ===" >> /tmp/\$FILE
#cat /etc/sysconfig/network-scripts/ifcfg-bond0 >> /tmp/\$FILE
#echo " " >> /tmp/\$FILE
#echo "=== ifcfg-slave-1 ===" >> /tmp/\$FILE
#cat /etc/sysconfig/network-scripts/ifcfg-bond0_slave_1 >> /tmp/\$FILE
#echo " " >> /tmp/\$FILE
#echo "=== ifcfg-slave-2 ===" >> /tmp/\$FILE
#cat /etc/sysconfig/network-scripts/ifcfg-bond0_slave_2 >> /tmp/\$FILE
#echo " " >> /tmp/\$FILE
echo "=== ifcfg files ===" >> /tmp/\$FILE
cd /etc/sysconfig/network-scripts
for ifcfg in \$(ls -1v ifcfg-* | grep -v ifcfg-lo) ; do 
 echo "\$ifcfg" >> /tmp/\$FILE
 cat \$ifcfg  >> /tmp/\$FILE
 echo " " >> /tmp/\$FILE
done
echo '=== cat /proc/net/bonding/bond0 ===' >> /tmp/\$FILE
cat /proc/net/bonding/bond0 >> /tmp/\$FILE
echo " " >> /tmp/\$FILE
echo '=== cat /etc/modprobe.d/bonding.conf ===' >> /tmp/\$FILE
cat /etc/modprobe.d/bonding.conf >> /tmp/\$FILE
echo " " >> /tmp/\$FILE
echo '=== cat /etc/NetworkManager/NetworkManager.conf ===' >> /tmp/\$FILE
cat /etc/NetworkManager/NetworkManager.conf >> /tmp/\$FILE
echo " " >> /tmp/\$FILE
echo '=== cat /etc/resolv.conf ===' >> /tmp/\$FILE
cat /etc/resolv.conf >> /tmp/\$FILE
echo " " >> /tmp/\$FILE
echo '=== cat /etc/default/grub ===' >> /tmp/\$FILE
cat /etc/default/grub >> /tmp/\$FILE
echo " " >> /tmp/\$FILE
echo "=== Cipher Suite Priv Max  ===" >> /tmp/\$FILE
ipmitool lan print 1 | grep "Cipher Suite Priv Max" >> /tmp/\$FILE
echo " " >> /tmp/\$FILE
echo "=== racadm  ===" >> /tmp/\$FILE
/opt/dell/srvadmin/sbin/racadm version >> /tmp/\$FILE
echo " " >> /tmp/\$FILE
echo "=== cat /etc/fstab  ===" >> /tmp/\$FILE
cat /etc/fstab >> /tmp/\$FILE
echo " " >> /tmp/\$FILE
echo "=== cat /etc/ntp.conf  ===" >> /tmp/\$FILE
cat /etc/ntp.conf >> /tmp/\$FILE
echo " " >> /tmp/\$FILE
echo "=== cat /etc/ntp/step-tickers  ===" >> /tmp/\$FILE
cat /etc/ntp/step-tickers >> /tmp/\$FILE
echo " " >> /tmp/\$FILE
echo "=== cat /etc/yum/vars/osname ===" >> /tmp/\$FILE
cat /etc/yum/vars/osname >> /tmp/\$FILE
echo " " >> /tmp/\$FILE
echo "=== ls -1 /etc/yum.repos.d/*  ===" >> /tmp/\$FILE
ls -1 /etc/yum.repos.d/* >> /tmp/\$FILE
echo " " >> /tmp/\$FILE
echo "=== cat /etc/yum.repos.d/os.repo  ===" >> /tmp/\$FILE
cat /etc/yum.repos.d/os.repo >> /tmp/\$FILE
echo " " >> /tmp/\$FILE
echo "=== cat /etc/yum.repos.d/epel.repo ===" >> /tmp/\$FILE
cat /etc/yum.repos.d/epel.repo >> /tmp/\$FILE
echo " " >> /tmp/\$FILE
echo "=== cat /etc/yum.repos.d/bogus.repo ===" >> /tmp/\$FILE
cat /etc/yum.repos.d/bogus.repo >> /tmp/\$FILE
echo " " >> /tmp/\$FILE
echo "=== cat /etc/yum.repos.d/zabbix.repo ===" >> /tmp/\$FILE
cat /etc/yum.repos.d/zabbix.repo >> /tmp/\$FILE
echo " " >> /tmp/\$FILE
echo "=== cat /etc/sysctl.d/101-b.conf ===" >> /tmp/\$FILE
cat /etc/sysctl.d/101-b.conf >> /tmp/\$FILE
echo " " >> /tmp/\$FILE

cd /tmp
wget http://192.168.1.2/kickstart/install/rhel-server-7.2-x86_64/Packages/tftp-5.2-12.el7.x86_64.rpm
rpm -ivh tftp-5.2-12.el7.x86_64.rpm
tftp \${IP} -c put /tmp/\$FILE linux-install/validate/\$FILE
mv -f /etc/rc.d/rc.local.backup /etc/rc.d/rc.local
rpm -e tftp
rm -rf /tmp/tftp*
rm -rf /tmp/validate.sh
rm -rf \$FILE
rm -rf /tmp/rc.local.log
EOF

chmod +x /tmp/validate.sh

# Execute validation script after reboot
cd /etc/rc.d
cp -rp rc.local rc.local.backup
chmod 744 rc.local
systemctl start rc-local
cat <<EOF > rc.local
#!/bin/bash
exec 2> /tmp/rc.local.log
exec 1>&2
echo "rc.local started"
set -x
bash -xv /tmp/validate.sh
EOF

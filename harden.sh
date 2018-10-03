#!/bin/bash

########################################################################
# Server preparation script
#
# Upload to /tmp and run as root
# - Configures and enables ntp and ntpd
# - Enables TCP wrappers
# - Disables root login and passwordauthentication in sshd_config
# - Disables cups and ip6tables
# - Disables selinux
# - Adds time stamps to .bash_history
# - Sets global http_proxy
# - Configures and mount /u01 to /dev/sdb via LVM
# - Installs missing packages
# - Removes OpenJDK and installs Oracle JDK 8
# - Removes "quiet" and "graphical boot" options from grub.conf
# - Add's its own IP address and hostname to /etc/hosts
########################################################################

set -x

########################################################################
# Set the clock and enable ntp

export ntpConfig="driftfile /var/lib/ntp/drift
restrict default kod nomodify notrap nopeer noquery
restrict -6 default kod nomodify notrap nopeer noquery
restrict 127.0.0.1
restrict -6 ::1
server ntpserver1.foo.com
server ntpserver2.foo.com
includefile /etc/ntp/crypto/pw
keys /etc/ntp/keys"

cp -v /etc/{ntp.conf,ntp.conf.orig}

echo "$ntpConfig" > /etc/ntp.conf

service ntpd stop
ntpdate ntpserver2.foo.com
chkconfig ntpd on
service ntpd restart


########################################################################
## TCP Wrappers

cp -v /etc/{hosts.deny,hosts.deny.orig}
echo "ALL : ALL" >> /etc/hosts.deny
cp -v /etc/{hosts.allow,hosts.allow.orig}
echo "ALL : localhost" >> /etc/hosts.allow
echo "sshd : ALL" >> /etc/hosts.allow


########################################################################
# sshd_config

cp -v /etc/ssh/{sshd_config,sshd_config.orig}
echo "PermitRootLogin no" >> /etc/ssh/sshd_config
sed -i "s/PasswordAuthentication yes/PasswordAuthentication no/" /etc/ssh/sshd_config
sed -i "s/^#MaxAuthTries 6/MaxAuthTries 3/" /etc/ssh/sshd_config


########################################################################
# Disable cups

chkconfig cups off
service cups stop


########################################################################
# Disable ip6tables

chkconfig ip6tables off
service ip6tables stop


########################################################################
# Disable selinux

sed -i.orig "s/SELINUX=enforcing/SELINUX=disabled/" /etc/selinux/config


########################################################################
# Add time stamps to .bash_history

echo 'export HISTTIMEFORMAT="%d/%m/%y %T "' >> /etc/bashrc


########################################################################
# Enable http proxy

cp -v /etc/{bashrc,bashrc.orig}
echo 'export http_proxy="http://10.155.162.19:8080"' >> /etc/bashrc
echo 'export https_proxy="http://10.155.162.19:8080"' >> /etc/bashrc
source /etc/bashrc


########################################################################
# /u01 config via LVM

pvcreate /dev/sdb
vgcreate vg_sdb /dev/sdb
lvcreate -l 100%FREE -n lv_u01 vg_sdb
mkfs.ext4 /dev/vg_sdb/lv_u01
mkdir /u01
cp -v /etc/{fstab,fstab.orig}
echo "/dev/vg_sdb/lv_u01              /u01            ext4    defaults        1 2" >> /etc/fstab
mount /u01


########################################################################
# Install missing packages (admin only)

yum -y install gcc kernel-headers kernel-devel logwatch nmap screen yum-plugin-downloadonly yum-plugin-security 


########################################################################
# Install JDK 8

for i in `rpm -qa|grep -i "jdk"`;do rpm -e $i;done

wget --no-check-certificate --no-cookies --header "Cookie: oraclelicense=accept-securebackup-cookie" http://download.oracle.com/otn-pub/java/jdk/8u74-b02/jdk-8u74-linux-x64.rpm

rpm -ihv jdk-8u74-linux-x64.rpm


########################################################################
# Clean up grub.conf

sed -i.orig "s/ rhgb quiet/ vga=791/" /boot/grub/grub.conf


########################################################################
# Create a hosts file entry

HostName=`hostname`
IPAddr=`ifconfig eth0|grep "inet addr"|cut -d":" -f 2|awk '{print $1}'`
cp -v /etc/{hosts,hosts.orig}
echo "$IPAddr     $HostName" >> /etc/hosts

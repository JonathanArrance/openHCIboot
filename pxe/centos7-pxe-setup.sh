#!/bin/bash

#exit if a command fails
set -e

PXE_INTERFACE='enp0s3'
IP='192.168.56.2'
MASK='255.255.255.0'

#get the interface IP
FOUNDIP=`ip addr show $PXE_INTERFACE | grep "inet\b" | awk '{print $2}' | cut -d/ -f1`

#Dhcp range will need to be the same as the pxe interface
#EX. Allocate .100 - .110 for 4h period
DHCP_RANGE='192.168.56.100,192.168.56.110,4h'

#Name of the centOS iso image
ISO='CentOS-7-x86_64-Minimal-1804.iso'

#make sure you are root
if [ "$EUID" -ne 0 ];
  then echo "Please run as root"
  exit 1
fi

if [ -f ~/pxe_setup ];
  then echo "The pxe is already setup. Use the cleanup and setup scripts."
  exit 1
fi

echo 'Checking if PXE interface exists.'
if [ ! -f /etc/sysconfig/network-scripts/ifcfg-$PXE_INTERFACE ];
  then echo "The PXE interface does not exist."
  exit 1
fi

if [ grep -q "static" /etc/sysconfig/network-scripts/ifcfg-$PXE_INTERFACE ]; then
    if [ $IP != $FOUNDIP ]; then
        echo "The static ip found does not match the given ip, setting ip address to $IP."
        sed -i -e 's/IPADDR\=$FOUNDIP/IPADDR=$IP/' /etc/sysconfig/network-scripts/ifcfg-$PXE_INTERFACE
    else
        echo "The static ip is already set."
    fi
else
    echo "The interface is set to DHCP, the pxe interface should be statically assigned for reliability."
    echo "Setting the PXE interface to static ip $IP."
    sed -i -e 's/BOOTPROTO\="dhcp"/BOOTPROTO\="static"/' /etc/sysconfig/network-scripts/ifcfg-$PXE_INTERFACE
    echo "IPADDR=$IP" >> /etc/sysconfig/network-scripts/ifcfg-$PXE_INTERFACE
    echo "NETMASK=$MASK" >> /etc/sysconfig/network-scripts/ifcfg-$PXE_INTERFACE
fi

#keep getting error atthis if statement
#if [ grep -q "dhcp" /etc/sysconfig/network-scripts/ifcfg-$PXE_INTERFACE ]; then
#    echo "Setting the PXE interface to static ip $IP."
#    sed -i -e 's/BOOTPROTO\="dhcp"/BOOTPROTO\="static"/' /etc/sysconfig/network-scripts/ifcfg-$PXE_INTERFACE
#    echo "IPADDR=$IP" >> /etc/sysconfig/network-scripts/ifcfg-$PXE_INTERFACE
#    echo "NETMASK=$MASK" >> /etc/sysconfig/network-scripts/ifcfg-$PXE_INTERFACE
#fi

#check if the iso is available
if [ ! -f ~/$ISO ];
  then echo "The iso file does not exist."
  exit 1
fi

echo 'Disableing the firewall.'
systemctl disable firewalld || { echo "Could not disable the firewall."; exit 1; }
systemctl stop firewalld || { echo "Could not stop the firewall service."; exit 1; }

echo 'Disableing SElinux.'
sed -i -e 's/SELINUX=enforceing/SELINUX=disabled/g' /etc/sysconfig/selinux || { echo "Could not disable the SELINUX service."; exit 1; }

#update CentOS7
echo 'Getting latest updates for CentOS 7'
yum -y update || { echo "Could not update CentOS 7 to the latest updates."; exit 1; }

#install the packages needed
echo 'Installing CentOS 7 base packages.'
yum install -y epel-release net-tools wget || { echo "Could not download neccessary packages."; exit 1; }
yum install -y net-tools
yum install -y wget
yum install -y vsftpd

echo 'Installing syslinux pxe boot server.'
yum install -y syslinux || { echo "Could not download syslinux."; exit 1; }

mkdir -p /opt/isorepo
mkdir -p /mnt/cent7
mv ~/$ISO /opt/isorepo/$ISO
echo 'Automounting the CentOS 7 install iso.'
mount /opt/isorepo/$ISO /mnt/cent7
echo "mount /opt/isorepo/$ISO /mnt/cent7" >> /etc/rc.local

echo 'Installing dnsmasq for dhcp and tftpboot services.'
yum install -y dnsmasq || { echo "Could not download dnsmasq."; exit 1; }

echo 'Configureing dnsmaq dhcp and tftpboot.'
mkdir -p /opt/openhci || { echo "Could not create /opt/zerostack"; exit 1; }
chmod 777 /opt/openhci || { echo "Could chnage permissions on /opt/zerostack"; exit 1; }
mkdir -p /opt/openhci/pxelinux/pxelinux.cfg || { echo "Could not create /opt/zerostack/pxelinux/pxelinux.cfg"; exit 1; }

echo 'Adding the pxeboot files to the tftp directory.'
cp -v /usr/share/syslinux/pxelinux.0 /opt/openhci
cp -v /usr/share/syslinux/mboot.c32 /opt/openhci
cp -v /usr/share/syslinux/menu.c32 /opt/openhci
cp -v /usr/share/syslinux/memdisk /opt/openhci
cp -v /usr/share/syslinux/chain.c32 /opt/openhci
cp -v /usr/share/syslinux/vesamenu.c32 /opt/openhci

#need to build the ks files for the 
echo 'Creating the default boot file.'
cat > /opt/openhci/pxelinux/pxelinux.cfg/default <<EOF
default install
TIMEOUT 60
ONTIMEOUT BootLocal

label BootLocal
      menu label ^Local OS boot
      menu default
      localboot 0

label CoreNode
        menu label ^CoreNode install
        menu Core-vBeta
        kernel /opt/openhci/cent-7/vmlinuz
        append inst.ks=http://$IP/rhat_ic/ciac_files/version23_cent7/anaconda-openhci.cfg ksdevice=link vga=788 auto=true priority=critical initrd=redhat-installer/cent-7/initrd.img
EOF

echo 'Configureing dnsmasq.'
sed -i -e "s/\#interface=/interface=${PXE_INTERFACE}/g" /etc/dnsmasq.conf || { echo "Could not set pxe boot interface."; exit 1; }
sed -i -e 's/\#dhcp-boot\=pxelinux.0/dhcp-boot\=pxelinux\/pxelinux.0/g' /etc/dnsmasq.conf || { echo "Could not set pxeboot file."; exit 1; }
sed -i -e 's/\#enable-tftp/enable-tftp/g' /etc/dnsmasq.conf || { echo "Could not enable tftp in dnsmasq."; exit 1; }
sed -i -e 's/\#tftp-root\=\/var\/ftpd/tftp-root\=\/opt\/openhci/g' /etc/dnsmasq.conf || { echo "Could not set the tftp root"; exit 1; }
echo "dhcp-range=$DHCP_RANGE" >> /etc/dnsmasq.conf || { echo "Could not set the dhcp range."; exit 1; }

echo 'Starting the dnsmasq service.'
service dnsmasq start || { echo "Could not start the dnsmasq dhcp/tftpboot server."; exit 1; }
chkconfig dnsmasq on || { echo "Could not enable the dhcp/tftpboot server."; exit 1; }

#create a dummy pxe setup file if the script completes
touch ~/pxe_setup

#port=0
#interface=enp8s0
#bind-interfaces
#dhcp-range=192.168.0.50,192.168.0.150,12h
#enable-tftp
#dhcp-match=set:efi-x86_64,option:client-arch,7
#dhcp-boot=tag:efi-x86_64,grubx64.efi
#tftp-root=/tmp/tftpboot
#!/bin/bash -x

#add postgres to the yum repos files
mv /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.old
wget -P /etc/yum.repos.d/ http://192.168.10.10/rhat/ciac_files/CentOS-Base.repo

yum install -y xfsprogs

VERSION='nightly-v25'
MASTER_PWD="simpleprivatecloudsolutions"

#set the hostname to ciac-xxxxx random digits
echo "Setting the hostname."
mv /etc/hostname /etc/hostname.old
#RAND=$RANDOM

NODEONE=$(($RANDOM % 99999999 + 10000000))
NODETWO=$(($RANDOM % 99999 + 10000))

ADMIN_TOKEN=$(($RANDOM % 999999999999999999 + 100000000000000000))
#ADMIN_TOKEN="transcirrus109283"

HOSTNAME=sn-p-${NODETWO}

#ciac node id
NODEID=002-${NODEONE}-${NODETWO}

echo $NODEID > /etc/nodeid

#add the hostname
mv /etc/sysconfig/network /etc/sysconfig/network.old
echo 'HOSTNAME='$HOSTNAME > /etc/sysconfig/network
echo 'NETWORKING=yes' >> /etc/sysconfig/network

#change the hosts file
mv /etc/hosts /etc/hosts.old

echo '127.0.0.1   localhost' > /etc/hosts
echo "127.0.1.1   $HOSTNAME" >> /etc/hosts

echo '::1     ip6-localhost ip6-loopback' >> /etc/hosts
echo 'fe00::0 ip6-localnet' >> /etc/hosts
echo 'ff00::0 ip6-mcastprefix' >> /etc/hosts
echo 'ff02::1 ip6-allnodes' >> /etc/hosts
echo 'ff02::2 ip6-allrouters' >> /etc/hosts

sed -i 's/PATH=\$PATH:\$HOME\/bin/PATH=\$PATH:\$HOME\/bin:\/usr\/local\/bin/g' /root/.bash_profile
sed -i 's/secure_path = \/sbin:\/bin:\/usr\/sbin:\/usr\/bin/secure_path = \/sbin:\/bin:\/usr\/sbin:\/usr\/bin:\/usr\/local\/bin/g' /etc/sudoers
sleep 1

hostname $HOSTNAME

#scratch dir for transcirrus
mkdir /transcirrus
chmod -R 777 /transcirrus

#set up rbash
ln -s /bin/bash /bin/rbash
echo '/bin/rbash' >> /etc/shells
echo '/bin/admin.sh' >> /etc/shells

#create admin shell - admin.sh
touch /bin/admin.sh
(
cat <<'EOP'
#!/bin/rbash
python2.7 /usr/local/lib/python2.7/transcirrus/interfaces/shell/coalesce.py
EOP
) >> /bin/admin.sh
chmod +x /bin/admin.sh
chown transuser:transystem /bin/admin.sh

#add the admin user
useradd -d /home/admin -g transystem -s /bin/admin.sh admin

#set admin default password
echo -e 'password\npassword\n' | passwd admin

#make sure sudo can run in console
sed -i 's/Defaults    requiretty/#Defaults    requiretty/g' /etc/sudoers

echo "Setting up transuser sudo."
#set the transuser account up in sudo
(
cat <<'EOP'
transuser ALL=(ALL) NOPASSWD: ALL
admin ALL=(ALL) NOPASSWD: ALL
EOP
) >> /etc/sudoers

#fix postgres user groups
usermod -a -G postgres admin
usermod -a -G postgres transuser

#iceHouse repo
yum install -y http://192.168.10.10/rhat_ic/common/rdo-release-icehouse-4.noarch.rpm
yum install -y http://192.168.10.10/rhat_ic/common/epel-release-6-8.noarch.rpm

# install some additional packages
echo "Installing software on the system."
yum groupinstall -y "Development tools"
yum install -y zlib-devel bzip2-devel openssl-devel ncurses-devel sqlite-devel readline-devel tk-devel
yum install -y wget

#install python2.7
#/usr/local/bin/python2.7
wget -P /root http://192.168.10.10/rhat/common/Python-2.7.3.tar.bz2
cd /root
tar xf Python-2.7.3.tar.bz2
cd Python-2.7.3
./configure --prefix=/usr/local
make
make altinstall

#install python 2.7 pip
wget -P /root http://192.168.10.10/rhat/common/ez_setup.py
wget -P /root http://192.168.10.10/rhat/common/get-pip.py
python2.7 /root/ez_setup.py
python2.7 /root/get-pip.py

wget -P /root http://192.168.10.10/rhat/gluster/glusterfs-epel-35.repo
yum-config-manager --add-repo /root/glusterfs-epel-35.repo
yum install -y glusterfs-libs-3.5.2-1.el6.x86_64
yum install -y glusterfs-3.5.2-1.el6.x86_64
yum install -y glusterfs-devel-3.5.2-1.el6.x86_64
yum install -y glusterfs-server-3.5.2-1.el6.x86_64
yum install -y glusterfs-geo-replication-3.5.2-1.el6.x86_64

#yum
yum install -y redhat-lsb
yum install -y libguestfs-tools
yum install -y jwhois
yum install -y qpid-cpp-server
yum install -y ethtool net-tools
yum install -y python-setuptools python-devel python-simplejson
yum install -y python-psycopg2
yum install -y memcached xfsprogs openstack-utils python-keystone-auth-token
yum install -y dialog
yum install -y python-pip
yum install -y gcc

wget -P /root http://192.168.10.10/rhat/common/monit-5.8.1-1.x86_64.rpm
rpm -ivh /root/monit-5.8.1-1.x86_64.rpm

#get psycopg2 in python2.7
wget -P /root http://192.168.10.10/rhat/common/psycopg2-2.5.2.tar.gz
tar -zxvf /root/psycopg2-2.5.2.tar.gz -C /root
cd /root/psycopg2-2.5.2
python2.7 ./setup.py install

#get the RabbitMQ server
rpm --import http://192.168.10.10/rhat_ic/common/rabbitmq-signing-key-public.asc
yum install -y http://192.168.10.10/rhat_ic/common/rabbitmq-server-3.3.5-1.noarch.rpm

#mv /etc/dhcp/dhcpd.conf /etc/dhcp/dhcpd.conf.old
#wget -P /etc/dhcp http://192.168.10.10/rhat/ciac_files/dhcpd.conf

#add confparser
wget -P /root http://192.168.10.10/rhat/common/confparse-1.0a1-py2.5.egg
easy_install-2.7 /root/confparse-1.0a1-py2.5.egg

#not getting this package - check
wget -P /root http://192.168.10.10/rhat/common/python-ifconfig-0.1.tar.gz
tar -zxvf /root/python-ifconfig-0.1.tar.gz -C /root
cd /root/python-ifconfig-0.1
python2.7 ./setup.py install
python2.7 /root/python-ifconfig-0.1/test/test_ifconfig.py

#get the python dialog package
wget -P /root http://192.168.10.10/rhat/common/pythondialog-2.11.tar
tar -xvf /root/pythondialog-2.11.tar -C /root
cd /root/pythondialog-2.11
python2.7 ./setup.py build
python2.7 ./setup.py install

echo "Installing OpenStack Cinder components."
yum install -y openstack-cinder openstack-cinder-doc

rm -rf /etc/cinder

wget -P /etc http://192.168.10.10/rhat_ic/sn_files/sn_configs_ssd.tar
tar -xvf /etc/sn_configs_ssd.tar -C /etc

#make sure all service belong to thier user
chown -R cinder:cinder /etc/cinder

chmod -R 770 /etc/cinder

#add transuser to groups
usermod -a -G cinder transuser

#add admin to groups
usermod -a -G cinder admin

chmod g+w /var/log/cinder

sleep 1
mkdir -p /usr/local/lib/python2.7/transcirrus
#download the transcirrus code
wget -P /usr/local/lib/python2.7/transcirrus http://192.168.10.10/builds/rhat_ic/${VERSION}
sleep 1
tar -xvf /usr/local/lib/python2.7/transcirrus/${VERSION}-C /usr/local/lib/python2.7/transcirrus

#check to see if the log file exists
if [ -e /var/log/caclogs/system.log ]
then
echo "CAClog exists"
else
mkdir -p /var/log/caclogs
touch /var/log/caclogs/system.log
chmod -R 776 /var/log/caclogs
chown -R transuser:transystem /var/log/caclogs
fi

# We have to do this so multiple users/processes can write to the log file.
chmod -R g+s /var/log/caclogs
chmod -R 777 /var/log/caclogs

#add the chmod log hack
(crontab -l 2>/dev/null; echo "0 * * * * /bin/chmod 777 /var/log/caclogs/system.log") | crontab -

rm /usr/local/lib/python2.7/transcirrus/${VERSION}

#Format the raid 6 as xfs
parted -s -a optimal /dev/sda mklabel gpt -- mkpart primary xfs 1 -1
mkfs -t xfs /dev/sdc1

#set up glusterFS
mkdir -p /data/gluster'-'${HOSTNAME}

echo '/dev/sdc1 /data/gluster-'${HOSTNAME}' xfs defaults 1 2' >> /etc/fstab
mount -a && mount

#gluster log
mkdir -p /var/log/glusterfs/

#gluster mount dir
mkdir -p /mnt/gluster-vols

#open ports in the firewall 
for x in {'111','24007','24008','24009','24010','24011','24012','24013','24014','24015','24016','24017','24018','24019','24020','24021','24022','24023','24025','24026','24027','24028','24029','34865','34866','34867','2812'}
do
    iptables -A INPUT -p tcp --dport ${x} -j ACCEPT
    iptables -A INPUT -p udp --dport ${x} -j ACCEPT
done

iptables-save >> /transcirrus/iptables.rules

#create the gluster brick
sleep 1
#get some services ready for gluster/swift
chkconfig memcached on
service memcached start

#get the new /etc/glusterfs/glusterd.vol
mv /etc/glusterfs/glusterd.vol /etc/glusterfs/glusterd.old
wget -P /etc/glusterfs/ http://192.168.10.10/rhat_ic/gluster/glusterd.vol

chkconfig glusterfsd on
service glusterfsd start

chkconfig glusterd on
service glusterd start

echo "NODE_ID='"${NODEID}"'" >> /usr/local/lib/python2.7/transcirrus/common/config.py
echo "NODE_NAME='"${HOSTNAME}"'" >> /usr/local/lib/python2.7/transcirrus/common/config.py
echo "NODE_TYPE='sn'" >> /usr/local/lib/python2.7/transcirrus/common/config.py
echo "CLOUD_NAME='TransCirrusCloud'" >> /usr/local/lib/python2.7/transcirrus/common/config.py
echo "GLUSTER_BRICK='"gluster-${HOSTNAME}"'" >> /usr/local/lib/python2.7/transcirrus/common/config.py
echo "DISK_TYPE='ssd'" >> /usr/local/lib/python2.7/transcirrus/common/config.py
echo "MASTER_PWD='"$MASTER_PWD"'" >> /usr/local/lib/python2.7/transcirrus/common/config.py

echo "TRANSCIRRUS_DB='172.24.24.10'" >> /usr/local/lib/python2.7/transcirrus/common/config.py
echo "TRAN_DB_USER='transuser'" >> /usr/local/lib/python2.7/transcirrus/common/config.py
echo "TRAN_DB_PASS='"$MASTER_PWD"'" >> /usr/local/lib/python2.7/transcirrus/common/config.py
echo "TRAN_DB_NAME='transcirrus'" >> /usr/local/lib/python2.7/transcirrus/common/config.py
echo "TRAN_DB_PORT='5432'" >> /usr/local/lib/python2.7/transcirrus/common/config.py

##DEFAULT OPENSTACK DB SETTINGS##
echo "OS_DB='172.24.24.10'" >> /usr/local/lib/python2.7/transcirrus/common/config.py
echo "OS_DB_PORT='5432'" >> /usr/local/lib/python2.7/transcirrus/common/config.py
echo "OS_DB_USER='transuser'" >> /usr/local/lib/python2.7/transcirrus/common/config.py
echo "OS_DB_PASS='"$MASTER_PWD"'" >> /usr/local/lib/python2.7/transcirrus/common/config.py

yum update --skip-broken -y

mv /etc/sysctl.conf /etc/sysctl.conf.old
wget -P /etc http://192.168.10.10/rhat/ciac_files/sysctl.conf
chown root:root /etc/sysctl.conf
chmod 644 /etc/sysctl.conf
sysctl -e -p /etc/sysctl.conf

wget -P /etc http://192.168.10.10/rhat/ciac_files/dhclient.conf
chmod root:root /etc/dhclient.conf
chmod 644 /etc/dhclient.conf

#zero connect startup
wget -P /etc/init.d http://192.168.10.10/rhat/sn_files/sn_zero_connect
chmod 755 /etc/init.d/sn_zero_connect
chown root:root /etc/init.d/sn_zero_connect
chkconfig --levels 235 sn_zero_connect on

#turn off unneccessary services
chkconfig postfix off
chkconfig cups off
chkconfig ip6tables off
chkconfig iscsi off
chkconfig iscsid off
chkconfig lvm2-monitor off

rpm -e monit-5.14-1.el6.x86_64
rpm -ivh http://192.168.10.10/rhat_ic/common/monit-5.8.1-1.x86_64.rpm

#Fix monit
python2.7 /usr/local/lib/python2.7/transcirrus/operations/monit/fix_monit_conf.py sn

#psql -h 192.168.10.16 -U postgres -d transcirrusinternal -c "INSERT INTO manufacturing VALUES('"${NODEID}"','sn',NULL,NULL,'"${HOSTNAME}"','false','grizzly',current_date,NULL);"

#clean up roots home
rm -rf /root/*
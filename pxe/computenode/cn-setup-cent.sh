#!/bin/bash -x

#add postgres to the yum repos files
mv /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.old
wget -P /etc/yum.repos.d/ http://192.168.10.10/rhat_ic/ciac_files/CentOS-Base.repo

chkconfig ntpd on
service ntpd restart

#set the hostname to ciac-xxxxx random digits
echo "Setting the hostname."
mv /etc/hostname /etc/hostname.old

NODEONE=$(($RANDOM % 99999999 + 10000000))
NODETWO=$(($RANDOM % 99999 + 10000))

ADMIN_TOKEN=$(($RANDOM % 999999999999999999 + 100000000000000000))
#ADMIN_TOKEN="transcirrus109283"

HOSTNAME=cn-${NODETWO}

#ciac node id
NODEID=001-${NODEONE}-${NODETWO}

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
sed -i 's/secure_path = \/sbin:\/bin:\/usr\/sbin:\/usr\/bin/secure_path = \/sbin:\/bin:\/usr\/sbin:\/usr\/bin:\/usr\/local\/lib/g' /etc/sudoers

#diable selinux
sudo setenforce 0
sudo sed -i 's/=enforcing/=disabled/;s/=permissive/=disabled/' /etc/selinux/config

#make it so apaceh can run sudo
sed -i 's/Defaults    requiretty/#Defaults    requiretty/g' /etc/sudoers

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

#iceHouse repo
yum install -y http://192.168.10.10/rhat_ic/common/rdo-release-icehouse-4.noarch.rpm
yum install -y http://192.168.10.10/rhat_ic/common/epel-release-6-8.noarch.rpm

# install some additional packages
echo "Installing software on the system."
yum groupinstall -y "Development tools"
yum install -y ncurses-devel zlib-devel bzip2-devel openssl-devel sqlite-devel readline-devel tk-devel
yum install -y wget

#install python2.7
#/usr/local/bin/python2.7
wget -P /root http://192.168.10.10/rhat_ic/common/Python-2.7.3.tar.bz2
cd /root
tar xf Python-2.7.3.tar.bz2
cd Python-2.7.3
./configure --prefix=/usr/local
make
make altinstall

#install python 2.7 pip
wget -P /root http://192.168.10.10/rhat_ic/common/ez_setup.py
wget -P /root http://192.168.10.10/rhat_ic/common/get-pip.py
python2.7 /root/ez_setup.py
python2.7 /root/get-pip.py

#gluster3.5 repo
wget -P /root http://192.168.10.10/rhat_ic/gluster/glusterfs-epel-35.repo
yum-config-manager --add-repo /root/glusterfs-epel-35.repo
yum install -y glusterfs-libs-3.5.2-1.el6.x86_64
yum install -y glusterfs-3.5.2-1.el6.x86_64
yum install -y glusterfs-devel-3.5.2-1.el6.x86_64
yum install -y glusterfs-server-3.5.2-1.el6.x86_64
yum install -y glusterfs-geo-replication-3.5.2-1.el6.x86_64

#yum
yum install -y ntp
yum install -y redhat-lsb
yum install -y erlang
yum install -y libguestfs-tools
yum install -y qemu-kvm
yum install -y jwhois
yum install -y ethtool net-tools
yum install -y python-setuptools python-devel python-simplejson
yum install -y dnsmasq-utils
yum install -y python-psycopg2
yum install -y memcached xfsprogs openstack-utils python-keystone-auth-token
yum install -y gdbm-devel db4-devel libpcap-devel xz-devel
yum install -y dialog
yum install -y python-pip
yum install -y gcc
yum install -y git


#set the time
chkconfig ntpd on
service ntpd stop
ntpdate pool.ntp.org
service ntpd start

#get psycopg2 in python2.7
wget -P /root http://192.168.10.10/rhat_ic/common/psycopg2-2.5.2.tar.gz
tar -zxvf /root/psycopg2-2.5.2.tar.gz -C /root
cd /root/psycopg2-2.5.2
python2.7 ./setup.py install

#get the RabbitMQ server
rpm --import http://192.168.10.10/rhat_ic/common/rabbitmq-signing-key-public.asc
yum install -y http://192.168.10.10/rhat_ic/common/rabbitmq-server-3.3.5-1.noarch.rpm

#add confparser
wget -P /root http://192.168.10.10/rhat_ic/common/confparse-1.0a1-py2.5.egg
easy_install-2.7 /root/confparse-1.0a1-py2.5.egg

#used for the ssh update util
easy_install-2.7 paramiko

sudo pip2.7 install lxml

#not getting this package - check
wget -P /root http://192.168.10.10/rhat_ic/common/python-ifconfig-0.1.tar.gz
tar -zxvf /root/python-ifconfig-0.1.tar.gz -C /root
cd /root/python-ifconfig-0.1
python2.7 ./setup.py install
python2.7 /root/python-ifconfig-0.1/test/test_ifconfig.py

#get the python dialog package
wget -P /root http://192.168.10.10/rhat_ic/common/pythondialog-2.11.tar
tar -xvf /root/pythondialog-2.11.tar -C /root
cd /root/pythondialog-2.11
python2.7 ./setup.py build
python2.7 ./setup.py install

echo "Installing OpenStack Nova components."
yum install -y openstack-nova-compute
echo "Installing OpenStack Neutron components."
yum install -y openstack-neutron-ml2 openstack-neutron-openvswitch
echo "Installing OpenStack Ceilometer components."
yum install -y openstack-ceilometer-compute python-ceilometerclient python-pecan

#make sure all service belong to thier user
rm -rf /etc/neutron
rm -rf /etc/nova
rm -rf /etc/ceilometer

#setting up etc files
#get the new configs from the install repo
wget -P /etc http://192.168.10.10/rhat_ic/cn_files/version23/cn_configs_23.tar
tar -xvf /etc/cn_configs_23.tar -C /etc

#make sure all service belong to thier user
chown -R nova:nova /etc/nova
chown -R neutron:neutron /etc/neutron
chown -R ceilometer:ceilometer /etc/ceilometer

chmod -R 770 /etc/nova
chmod -R 770 /etc/neutron
chmod -R 770 /etc/ceilometer


#add transuser to groups
usermod -a -G nova transuser
usermod -a -G neutron transuser
usermod -a -G ceilometer transuser

#add admin to groups
usermod -a -G nova admin
usermod -a -G neutron admin
usermod -a -G ceilometer admin

#fix the log files
chmod g+w /var/log/neutron
chmod g+w /var/log/nova
chmod g+w /var/log/ceilometer

sleep 1
mkdir -p /usr/local/lib/python2.7/transcirrus
#download the transcirrus code
wget -P /usr/local/lib/python2.7/transcirrus http://192.168.10.10/builds/rhat_ic/nightly
sleep 1
tar -xvf /usr/local/lib/python2.7/transcirrus/nightly -C /usr/local/lib/python2.7/transcirrus

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

#ceilometer deamon
cp /usr/local/lib/python2.7/transcirrus/daemons/ceilometer_third_party_meters /etc/init.d
chmod 755 /etc/init.d/ceilometer_third_party_meters
chmod 755 /usr/local/lib/python2.7/transcirrus/daemons/ceilometer_third_party_meters
chown root:root /etc/init.d/ceilometer_third_party_meters
chkconfig --levels 235 ceilometer_third_party_meters on
chkconfig --add /etc/init.d/ceilometer_third_party_meters
service ceilometer_third_party_meters restart

# We have to do this so multiple users/processes can write to the log file.
chmod -R g+s /var/log/caclogs
chmod -R 777 /var/log/caclogs

#add the chmod log hack
(crontab -l 2>/dev/null; echo "0 * * * * /bin/chmod 777 /var/log/caclogs/system.log") | crontab -

rm /usr/local/lib/python2.7/transcirrus/nightly

echo "NODE_ID='"${NODEID}"'" >> /usr/local/lib/python2.7/transcirrus/common/config.py
echo "NODE_NAME='"${HOSTNAME}"'" >> /usr/local/lib/python2.7/transcirrus/common/config.py
echo "NODE_TYPE='cn'" >> /usr/local/lib/python2.7/transcirrus/common/config.py
echo "CLOUD_NAME='TransCirrusCloud'" >> /usr/local/lib/python2.7/transcirrus/common/config.py

echo "TRANSCIRRUS_DB='172.24.24.10'" >> /usr/local/lib/python2.7/transcirrus/common/config.py
echo "TRAN_DB_USER='transuser'" >> /usr/local/lib/python2.7/transcirrus/common/config.py
echo "TRAN_DB_PASS='transcirrus1'" >> /usr/local/lib/python2.7/transcirrus/common/config.py
echo "TRAN_DB_NAME='transcirrus'" >> /usr/local/lib/python2.7/transcirrus/common/config.py
echo "TRAN_DB_PORT='5432'" >> /usr/local/lib/python2.7/transcirrus/common/config.py

##DEFAULT OPENSTACK DB SETTINGS##
echo "OS_DB='172.24.24.10'" >> /usr/local/lib/python2.7/transcirrus/common/config.py
echo "OS_DB_PORT='5432'" >> /usr/local/lib/python2.7/transcirrus/common/config.py
echo "OS_DB_USER='transuser'" >> /usr/local/lib/python2.7/transcirrus/common/config.py
echo "OS_DB_PASS='transcirrus1'" >> /usr/local/lib/python2.7/transcirrus/common/config.py
echo "API_IP='172.24.24.10'" >> /usr/local/lib/python2.7/transcirrus/common/config.py

yum update --skip-broken -y

mv /etc/sysctl.conf /etc/sysctl.conf.old
wget -P /etc http://192.168.10.10/rhat_ic/cn_files/sysctl.conf
chown root:root /etc/sysctl.conf
chmod 644 /etc/sysctl.conf
sysctl -e -p /etc/sysctl.conf

wget -P /etc http://192.168.10.10/rhat_ic/cn_files/dhclient.conf
chmod root:root /etc/dhclient.conf
chmod 644 /etc/dhclient.conf

#zero connect startup
wget -P /etc/init.d http://192.168.10.10/rhat_ic/cn_files/cn_zero_connect
chmod 755 /etc/init.d/cn_zero_connect
chown root:root /etc/init.d/cn_zero_connect

usermod -s /bin/bash nova
#Add the ssh key for nova
wget -P /root http://192.168.10.10/rhat_ic/common/ssh.tar
tar -xvf /root/ssh.tar -C /var/lib/nova

#turn on zero connect
chkconfig --levels 35 cn_zero_connect on

#install monit
wget -P /root http://192.168.10.10/rhat_ic/common/monit-5.8.1-1.x86_64.rpm
rpm -ivh /root/monit-5.8.1-1.x86_64.rpm

#Fix monit
python2.7 /usr/local/lib/python2.7/transcirrus/operations/monit/fix_monit_conf.py cn

#create a link to the updater in transuser home
ln -s /usr/local/lib/python2.7/transcirrus/operations/upgrade.py /home/transuser/upgrade.py

#ceilometer
ln -s /usr/lib64/python2.6/site-packages/libvirt.py /usr/local/lib/python2.7/site-packages/libvirt.py
ln -s /usr/lib64/python2.6/site-packages/libvirtmod.so /usr/local/lib/python2.7/site-packages/libvirtmod.so

#nfs
mkdir -p /mnt/nfs-vol/cinder-volume
chown cinder:cinder /mnt/nfs-vol/cinder-volume

#add the glusterfs pool
echo '172.24.24.10:/instances /var/lib/nova/instances glusterfs defaults,_netdev,direct-io-mode=disable,transport=tcp 0 0' >> /etc/fstab
chown -R nova:nova /var/lib/nova/instances
echo 'chown -R nova:nova /var/lib/nova/instances' >> /etc/rc.local
mkdir /var/lock/nova
chown -R nova:nova /var/lock/nova

echo 'mount -a' >> /etc/rc.local
echo 'sleep 2' >> /etc/rc.local
echo 'service openstack-nova-compute restart' >> /etc/rc.local

#turn on openvswitch
chkconfig openvswitch on
service openvswitch start

#add an internal bridge
ovs-vsctl add-br br-int

#add this so OVS agent start correctly
ln -s /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugin.ini

#turn off unneccessary services
chkconfig postfix off
chkconfig cups off
chkconfig ip6tables off
chkconfig iscsi off
chkconfig iscsid off
chkconfig lvm2-monitor off

# add the shadow_admin linux user
useradd -d /home/shadow_admin -g transystem -s /bin/admin.sh shadow_admin

# set shadow_admin default password
echo -e 'manbehindthecurtain\nmanbehindthecurtain\n' | passwd shadow_admin

# set the shadow_admin account up in sudo
echo 'shadow_admin ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers

# add shadow_admin to groups
usermod -a -G nova shadow_admin
usermod -a -G neutron shadow_admin
usermod -a -G ceilometer shadow_admin

#clean up roots home
rm -rf /root/*
reboot
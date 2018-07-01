#!/bin/bash -x
wget -r http://repos.prod.transcirrus.com/transcirrus/CentOS/6/7/TCpackages/ ./
rm -f /root/repos.prod.transcirrus.com/transcirrus/CentOS/6/7/TCpackages/kernel*
rpm -Uvh --nodeps --force --nosignature /root/repos.prod.transcirrus.com/transcirrus/CentOS/6/7/TCpackages/*.rpm
rpm -Uvh --nodeps --force --nosignature /root/repos.prod.transcirrus.com/transcirrus/CentOS/6/7/TCpackages/oopenstack-neutron-openvswitch-2014.1.5-1.el6.noarch.rpm
rpm -Uvh --nodeps --force --nosignature /root/repos.prod.transcirrus.com/transcirrus/CentOS/6/7/TCpackages/openstack-neutron-vpn-agent-2014.1.5-1.el6.noarch.rpm

#add postgres to the yum repos files
mv /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.old
wget -P /etc/yum.repos.d/ http://192.168.10.10/rhat_ic/ciac_files/CentOS-Base.repo

#yum install -y xfsprogs

VERSION='nightly-v25'
MASTER_PWD="simpleprivatecloudsolutions"

chkconfig ntpd on
service ntpd restart

#set up postgresql
chkconfig postgresql on
service postgresql initdb

mv /var/lib/pgsql/data/pg_hba.conf /var/lib/pgsql/data/pg_hba.conf.old
mv /var/lib/pgsql/data/postgresql.conf /var/lib/pgsql/data/postgresql.conf.old
wget -P /var/lib/pgsql/data/ http://192.168.10.10/rhat_ic/ciac_files/pg_hba.conf
chown postgres:postgres /var/lib/pgsql/data/pg_hba.conf
wget -P /var/lib/pgsql/data/ http://192.168.10.10/rhat_ic/ciac_files/postgresql.conf
chown postgres:postgres /var/lib/pgsql/data/postgresql.conf
chmod 766 /var/lib/pgsql/data/pg_hba.conf
chmod 766 /var/lib/pgsql/data/postgresql.conf

#restart psql
service postgresql restart

sleep 10

#add the transuser account to postgres and set the password
#used as the admin account for all transcirrus and openstack databases/tables
psql -U postgres -c "CREATE USER transuser;"
psql -U postgres -c "ALTER USER transuser WITH PASSWORD '"${MASTER_PWD}"';"

#create all of the empty dbs for the openstack users
psql -U postgres -c "CREATE DATABASE nova;"
psql -U postgres -c "GRANT ALL PRIVILEGES ON DATABASE nova TO transuser;"
psql -U postgres -c "ALTER DATABASE nova OWNER TO transuser;"

psql -U postgres -c "CREATE DATABASE cinder;"
psql -U postgres -c "GRANT ALL PRIVILEGES ON DATABASE cinder TO transuser;"
psql -U postgres -c "ALTER DATABASE cinder OWNER TO transuser;"

psql -U postgres -c "CREATE DATABASE keystone;"
psql -U postgres -c "GRANT ALL PRIVILEGES ON DATABASE keystone TO transuser;"
psql -U postgres -c "ALTER DATABASE keystone OWNER TO transuser;"

psql -U postgres -c "CREATE DATABASE neutron;"
psql -U postgres -c "GRANT ALL PRIVILEGES ON DATABASE neutron TO transuser;"
psql -U postgres -c "ALTER DATABASE neutron OWNER TO transuser;"

psql -U postgres -c "CREATE DATABASE glance;"
psql -U postgres -c "GRANT ALL PRIVILEGES ON DATABASE glance TO transuser;"
psql -U postgres -c "ALTER DATABASE glance OWNER TO transuser;"

psql -U postgres -c "CREATE DATABASE heat;"
psql -U postgres -c "GRANT ALL PRIVILEGES ON DATABASE heat TO transuser;"
psql -U postgres -c "ALTER DATABASE heat OWNER TO transuser;"

psql -U postgres -c "CREATE DATABASE transcirrus;"
psql -U postgres -c "GRANT ALL PRIVILEGES ON DATABASE transcirrus TO transuser;"
psql -U postgres -c "ALTER DATABASE transcirrus OWNER TO transuser;"


#set the hostname to ciac-xxxxx random digits
echo "Setting the hostname."
mv /etc/hostname /etc/hostname.old
#RAND=$RANDOM

NODEONE=$(($RANDOM % 99999999 + 10000000))
NODETWO=$(($RANDOM % 99999 + 10000))

ADMIN_TOKEN=$(($RANDOM % 999999999999999999 + 100000000000000000))
#ADMIN_TOKEN="transcirrus109283"

HOSTNAME=ciac-${NODETWO}

#ciac node id
NODEID=000-${NODEONE}-${NODETWO}

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
sed -i 's/IPTABLES_SAVE_ON_STOP="no"/IPTABLES_SAVE_ON_STOP="yes"/g' /etc/sysconfig/iptables-config
sed -i 's/IPTABLES_SAVE_ON_RESTART="no"/IPTABLES_SAVE_ON_RESTART="yes"/g' /etc/sysconfig/iptables-config

#diable selinux
sudo setenforce 0
sudo sed -i 's/=enforcing/=disabled/;s/=permissive/=disabled/' /etc/selinux/config

#fix so sudo can use python2.7 
#echo 'DEFAULTS    secure_path += /usr/local/bin' >> /etc/sudoers

sleep 1

hostname $HOSTNAME

#scratch dir for transcirrus
mkdir /transcirrus
chmod -R 777 /transcirrus

#create the gluster mount file
touch /transcirrus/gluster-mounts
chmod 777 /transcirrus/gluster-mounts

#create a gluster-object mount file
touch /transcirrus/gluster-object-mount
chmod 777 /transcirrus/gluster-object-mount

wget -P /transcirrus http://192.168.10.5/images/cirros-0.3.1-x86_64-disk.img
wget -P /transcirrus http://192.168.10.5/images/centos-6.5-20140117.0.x86_64.qcow2
wget -P /transcirrus http://192.168.10.5/images/precise-server-cloudimg-amd64-disk1.img
wget -P /transcirrus http://192.168.10.10/rhat_ic/ciac_files/pg_hba.proto
chmod 777 /transcirrus/pg_hba.proto

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

#make it so apaceh can run sudo
sed -i 's/Defaults    requiretty/#Defaults    requiretty/g' /etc/sudoers

#echo "Setting up transuser sudo."
#set the transuser account up in sudo
(
cat <<'EOP'
transuser ALL=(ALL) NOPASSWD: ALL
admin ALL=(ALL) NOPASSWD: ALL
apache ALL=(ALL:ALL) NOPASSWD: ALL
EOP
) >> /etc/sudoers

#fix postgres user groups
usermod -a -G postgres admin
usermod -a -G postgres apache
usermod -a -G postgres transuser

#iceHouse repo
#yum install -y http://192.168.10.10/rhat_ic/common/rdo-release-icehouse-4.noarch.rpm
#yum install -y http://192.168.10.10/rhat_ic/common/epel-release-6-8.noarch.rpm

# install some additional packages
echo "Installing software on the system."
#yum groupinstall -y "Development tools"
#yum install -y zlib-devel bzip2-devel openssl-devel ncurses-devel sqlite-devel readline-devel tk-devel
#yum install -y wget

#gluster3.5 repo
wget -P /root http://192.168.10.10/rhat_ic/gluster/glusterfs-epel-35.repo
yum-config-manager --add-repo /root/glusterfs-epel-35.repo
#yum install -y glusterfs-libs-3.5.2-1.el6.x86_64
#yum install -y glusterfs-3.5.2-1.el6.x86_64
#yum install -y glusterfs-devel-3.5.2-1.el6.x86_64
#yum install -y glusterfs-server-3.5.2-1.el6.x86_64
#yum install -y glusterfs-geo-replication-3.5.2-1.el6.x86_64

#yum
#yum install -y ntp
#yum install -y redhat-lsb
#yum install -y erlang
#yum install -y mod_ssl openssl
#yum install -y libguestfs-tools
#yum install -y qemu-kvm
#yum install -y jwhois
#yum install -y dhcp
#yum install -y ethtool net-tools
#yum install -y python-setuptools python-devel python-simplejson
#yum install -y dnsmasq-utils
#yum install -y python-psycopg2
#yum install -y memcached openstack-utils python-keystone-auth-token
#yum install -y dialog
#yum install -y python-pip
#yum install -y gcc
#yum install -y avahi-autoipd
#yum install -y cluster-glue
#yum install -y resource-agents
#yum install -y pcs
#yum install -y ncurses-devel gdbm-devel db4-devel libpcap-devel xz-devel
#yum install -y httpd-devel
#yum install -y xauth
#yum install -y mongodb-server mongodb
#yum install -y conntrack-tools
#yum install -y iproute-2.6.32-130.el6ost.netns.2.x86_64
#yum install -y virtio-win


#set the time
chkconfig ntpd on
service ntpd stop
ntpdate pool.ntp.org
service ntpd start

#get the RabbitMQ server
rpm --import http://192.168.10.10/rhat_ic/common/rabbitmq-signing-key-public.asc
#yum install -y http://192.168.10.10/rhat_ic/common/rabbitmq-server-3.3.5-1.noarch.rpm


#may need to remove this with yum before openstack components
#yum erase python27-2.7.3-6.2.sdl6.2.x86_64

echo "Installing OpenStack Keystone components."
#yum install -y openstack-keystone python-keystoneclient
echo "Installing OpenStack Glance components."
#yum install -y openstack-glance python-glanceclient
echo "Installing OpenStack Nova components."
#yum install -y --skip-broken openstack-nova-api openstack-nova-scheduler openstack-nova-cert openstack-nova-console openstack-nova-doc genisoimage openstack-nova-novncproxy openstack-nova-conductor novnc openstack-nova-compute python-novaclient
echo "Installing OpenStack Cinder components."
#yum install -y openstack-cinder openstack-cinder-doc
echo "Installing OpenStack Neutron components."
#yum install -y openstack-neutron openstack-neutron-ml2 python-neutronclient openstack-neutron-openvswitch openswan openstack-neutron-vpn-agent
echo "installing OpenStack Ceilometer"
#yum install -y openstack-ceilometer-api openstack-ceilometer-collector openstack-ceilometer-notification openstack-ceilometer-central openstack-ceilometer-alarm python-ceilometerclient openstack-ceilometer-compute python-pecan
echo "Installing OpenStack Heat"
#yum install -y openstack-heat-api openstack-heat-engine openstack-heat-api-cfn
echo "Installing OpenStack Swift components"
#yum install -y openstack-swift-account openstack-swift-container openstack-swift-object xfsprogs xinetd openstack-swift-proxy python-swiftclient python-keystone-auth-token

#install monit
wget -P /root http://192.168.10.10/rhat_ic/common/monit-5.8.1-1.x86_64.rpm
#rpm -ivh /root/monit-5.8.1-1.x86_64.rpm

#install python2.7
#/usr/local/bin/python2.7
wget -P /root http://192.168.10.10/rhat_ic/common/Python-2.7.3.tar.bz2
cd /root
tar xf Python-2.7.3.tar.bz2
cd Python-2.7.3
./configure --prefix=/usr/local --enable-unicode=ucs4 --enable-shared LDFLAGS="-Wl,-rpath /usr/local/lib"
make
make altinstall

sleep 1
sudo ln -s /usr/local/lib/libpython2.7.so.1.0 /usr/lib/libpython2.7.so.1.0
ldd /usr/lib/libpython2.7.so.1.0
ldconfig

#enable https in apache
wget -P /etc/pki/tls/certs http://192.168.10.10/rhat_ic/ciac_files/keys/ca.crt
wget -P /etc/pki/tls/private http://192.168.10.10/rhat_ic/ciac_files/keys/ca.key
wget -P /etc/pki/tls/private http://192.168.10.10/rhat_ic/ciac_files/keys/ca.csr
mv /etc/httpd/conf.d/ssl.conf /etc/httpd/conf.d/ssl.old
wget -P /etc/httpd/conf.d http://192.168.10.10/rhat_ic/ciac_files/keys/ssl.conf

#python2.7 RPM version Hack needed for gluster swift.
wget -P /root http://192.168.10.10/rhat_ic/common/environment-modules-3.2.9c-6.el6.x86_64.rpm
wget -P /root http://192.168.10.10/rhat_ic/common/python27-libs-2.7.3-6.2.sdl6.2.x86_64.rpm
wget -P /root http://192.168.10.10/rhat_ic/common/python27-2.7.3-6.2.sdl6.2.x86_64.rpm
#rpm -ivh /root/environment-modules-3.2.9c-6.el6.x86_64.rpm
#rpm -ivh /root/python27-libs-2.7.3-6.2.sdl6.2.x86_64.rpm
#rpm -ivh /root/python27-2.7.3-6.2.sdl6.2.x86_64.rpm

#install python 2.7 pip
wget -P /root http://192.168.10.10/rhat_ic/common/ez_setup.py
wget -P /root http://192.168.10.10/rhat_ic/common/get-pip.py
python2.7 /root/ez_setup.py
python2.7 /root/get-pip.py

sleep 1
#install setuptools
wget -P /root http://192.168.10.10/rhat_ic/ciac_files/setuptools-0.6c11-py2.7.egg
cd /root
sh setuptools-0.6c11-py2.7.egg --prefix=/usr/local

#get psycopg2 in python2.7
wget -P /root http://192.168.10.10/rhat_ic/common/psycopg2-2.5.2.tar.gz
tar -zxvf /root/psycopg2-2.5.2.tar.gz -C /root
cd /root/psycopg2-2.5.2
python2.7 ./setup.py install

#install wget
wget -P /root http://192.168.10.10/rhat_ic/ciac_files/wget-2.2.tar.gz
tar -zxvf /root/wget-2.2.tar.gz -C /root
cd /root/wget-2.2
python2.7 ./setup.py install

#install lxml
sudo pip2.7 install lxml

# install ldap
sudo pip2.7 install python-ldap

#add the hack for loopback users in rabbitmq
echo '[{rabbit, [{loopback_users, []}]}].' >> /etc/rabbitmq/rabbitmq.config

#start Rabbit
chkconfig rabbitmq-server on
service rabbitmq-server start

#create a new rabbitmq user/password
#rabbitmqctl add_user transuser transcirrus1
#rabbitmqctl set_user_tags transuser administrator
rabbitmqctl change_password guest ${MASTER_PWD}

mv /etc/sysconfig/dhcpd /etc/sysconfig/dhcpd.old
mv /etc/dhcp/dhcpd.conf /etc/dhcp/dhcpd.conf.old
#get the config files
wget -P /etc/sysconfig http://192.168.10.10/rhat_ic/ciac_files/dhcpd
wget -P /etc/dhcp http://192.168.10.10/rhat_ic/ciac_files/dhcpd.conf
#dhcp on by default
chkconfig --levels 235 dhcpd on

#need to figure out or multi node stratagy this should be off by defualt.
#chkconfig --levels 235 dhcpd off

#add confparser
wget -P /root http://192.168.10.10/rhat_ic/common/confparse-1.0a1-py2.5.egg
easy_install-2.7 /root/confparse-1.0a1-py2.5.egg

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

#install celery to python 2.7
easy_install-2.7 Celery

#used for the ssh update util
easy_install-2.7 paramiko

#get FLASK - REST API framework
pip install Flask
pip2.7 install Flask

#install ipy
pip2.7 install ipy

#install django
pip2.7 install django==1.5
pip2.7 install django-bootstrap-toolkit==2.15.0
pip2.7 install django-tables2==1.0.4
pip2.7 install django-filter==0.11.0
pip2.7 install django-crispy-forms==1.5.2
pip2.7 install django-celery==3.1.17

#make sure all service belong to thier user
rm -rf /etc/neutron
rm -rf /etc/nova
rm -rf /etc/glance
rm -rf /etc/cinder
rm -rf /etc/heat
rm -rf /etc/ceilometer

#setting up etc files
#get the new configs from the install repo
wget -P /etc http://192.168.10.10/rhat_ic/ciac_files/version25/os_configs.tar
tar -xvf /etc/os_configs.tar -C /etc

#make sure all service belong to thier user
chown -R nova:nova /etc/nova
chown -R cinder:cinder /etc/cinder
chown -R glance:glance /etc/glance
chown -R neutron:neutron /etc/neutron
chown -R heat:heat /etc/heat
chown -R ceilometer:ceilometer /etc/ceilometer

chmod -R 770 /etc/nova
chmod -R 770 /etc/cinder
chmod -R 770 /etc/glance
chmod -R 770 /etc/neutron
chmod -R 770 /etc/keystone
chmod -R 770 /etc/heat
chmod -R 770 /etc/ceilometer


#add transuser to groups
usermod -a -G nova transuser
usermod -a -G cinder transuser
usermod -a -G glance transuser
usermod -a -G swift transuser
usermod -a -G neutron transuser
usermod -a -G keystone transuser
usermod -a -G heat transuser
usermod -a -G ceilometer transuser

#add admin to groups
usermod -a -G nova admin
usermod -a -G cinder admin
usermod -a -G glance admin
usermod -a -G swift admin
usermod -a -G neutron admin
usermod -a -G keystone admin
usermod -a -G heat admin
usermod -a -G ceilometer admin

#add apache webserver
usermod -a -G nova apache
usermod -a -G cinder apache
usermod -a -G glance apache
usermod -a -G swift apache
usermod -a -G neutron apache
usermod -a -G keystone apache
usermod -a -G transuser apache
usermod -a -G heat apache
usermod -a -G ceilometer apache

usermod -a -G apache glance

#update log file permissions - these did not work sice the log files do not exist.
chmod 664 /var/log/glance/registry.log
chmod 664 /var/log/nova/nova-manage.log

#this worked
chmod 664 /etc/neutron/l3_agent.ini

#fix the log files
chmod g+w /var/log/neutron
chmod g+w /var/log/nova
chmod g+w /var/log/cinder
chmod g+w /var/log/glance
chmod g+w /var/log/keystone
chmod g+w /var/log/heat
chmod g+w /var/log/ceilometer

chown neutron:neutron /var/log/neutron
chown nova:nova /var/log/nova
chown cinder:cinder /var/log/cinder
chown glance:glance /var/log/glance
chown keystone:keystone /var/log/keystone
chown heat:heat /var/log/heat
chown ceilometer:ceilometer /var/log/ceilometer

sleep 1
mkdir -p /usr/local/lib/python2.7/transcirrus
#download the transcirrus code
wget -P /usr/local/lib/python2.7/transcirrus http://192.168.10.10/builds/rhat_ic/${VERSION}
sleep 1
tar -xvf /usr/local/lib/python2.7/transcirrus/${VERSION} -C /usr/local/lib/python2.7/transcirrus

#check to see if the log file exists
if [ -e /var/log/caclogs/system.log ]
then
echo "CAClog exists"
else
mkdir -p /var/log/caclogs
touch /var/log/caclogs/system.log
chmod -R 777 /var/log/caclogs
chown -R transuser:transystem /var/log/caclogs
fi

# We have to do this so multiple users/processes can write to the log file.
chmod -R g+s /var/log/caclogs
chmod -R 777 /var/log/caclogs

#add the chmod log hack
(crontab -l 2>/dev/null; echo "0 * * * * /bin/chmod 777 /var/log/caclogs/system.log") | crontab -

#add the django site to its proper place in the file system
echo 'Adding Coalesce to the opt directory.'
cp -Rf /usr/local/lib/python2.7/transcirrus/interfaces/Coalesce /opt
chown -R apache:apache /opt/Coalesce

#restart the apache2 service
#Starting httpd: httpd: Syntax error on line 221 of /etc/httpd/conf/httpd.conf: Syntax error on line 12 of /etc/httpd/conf.d/ssl.conf: Cannot load /etc/httpd/modules/mod_ssl.so into server: /etc/httpd/modules/mod_ssl.so: cannot open shared object file: No such file or directory
chkconfig httpd on
service httpd restart

rm /usr/local/lib/python2.7/transcirrus/${VERSION}

#set up the postgres DB
psql -U postgres -d transcirrus -a -f /usr/local/lib/python2.7/transcirrus/SQL_files/transcirrus_default_db.sql

#set up the MongoDB - Ceilometer
mv /etc/mongodb.conf /etc/mongodb.orig
wget -P /etc http://192.168.10.10/rhat_ic/ciac_files/mongodb.conf
chmod 644 /etc/mongodb.conf

service mongod start
chkconfig mongod on
sleep 5
echo 'db.addUser({user: "ceilometer",pwd: "'${MASTER_PWD}'",roles: [ "readWrite", "dbAdmin" ]})' >> /transcirrus/mongo.js
echo 'db.changeUserPassword("ceilometer", "'${MASTER_PWD}'")' >> /transcirrus/update_mongo_pwd.js


#add the metering secret to ceilometer
CEILOMETER_TOKEN=$(openssl rand -hex 10)
psql -U postgres -d transcirrus -c "INSERT INTO ceilometer_default VALUES ('metering_secret','"${CEILOMETER_TOKEN}"','ceilometer.conf');"

#get link local ip
avahi-autoipd --force-bind -D bond3
sleep 10
IP=`ip addr | grep inet | grep bond3 | awk -F" " '{print $2}' | sed -e 's/\/.*$//'`
sed -i 's/IPADDR=/IPADDR='${IP}'/g' /etc/sysconfig/network-scripts/ifcfg-bond3
sed -i 's/NETMASK=/NETMASK="255.255.0.0"/g' /etc/sysconfig/network-scripts/ifcfg-bond3
psql -U postgres -d transcirrus -c "INSERT INTO net_adapter_settings VALUES (1, 'bond3', '"${IP}"', '255.255.0.0', NULL, NULL, NULL, '"${NODEID}"', '"${HOSTNAME}"', NULL, NULL, 'none', NULL, '1500', NULL, 'clust', 'localdomain');"

echo "Adding the default net adapter settings."
#set up the defualt network entries for the ciac node
psql -U postgres -d transcirrus -c "INSERT INTO net_adapter_settings VALUES (2, 'bond0', '192.168.0.2', '255.255.255.0', '8.8.8.8', '8.8.4.4', '204.85.3.3', '"${NODEID}"', '"${HOSTNAME}"', NULL, NULL, 'none', '192.168.0.1', '1500', NULL, 'mgmt', 'localdomain');"
psql -U postgres -d transcirrus -c "INSERT INTO net_adapter_settings VALUES (3, 'br-ex', '192.168.0.3', '255.255.255.0', '8.8.8.8', '8.8.4.4', '204.85.3.3', '"${NODEID}"', '"${HOSTNAME}"', NULL, NULL, 'none', '192.168.0.1', '9000', NULL, 'uplink', 'localdomain');"


#set up the Keystone service
#move the old file and write the new file in place
#set the auth token to some radom number
sleep 2
mv /etc/keystone/keystone.conf /etc/keystone/keystone.conf.old
echo [DEFAULT] > /etc/keystone/keystone.conf
echo admin_token = ${ADMIN_TOKEN} >> /etc/keystone/keystone.conf
(
cat <<'EOP'
bind_host = 0.0.0.0
public_port = 5000
admin_port = 35357
compute_port = 8774
debug = False
verbose = False
[sql]
connection = postgresql://transuser:${MASTER_PWD}@localhost/keystone
[identity]
driver = keystone.identity.backends.sql.Identity
[trust]
driver = keystone.trust.backends.sql.Trust
[catalog]
driver = keystone.catalog.backends.sql.Catalog
[token]
driver = keystone.token.backends.sql.Token
[policy]
driver = keystone.policy.backends.sql.Policy
[ec2]
driver = keystone.contrib.ec2.backends.sql.Ec2
[signing]
token_format = PKI
[auth]
methods = password,token
password = keystone.auth.plugins.password.Password
token = keystone.auth.plugins.token.Token

[filter:debug]
paste.filter_factory = keystone.common.wsgi:Debug.factory

[filter:token_auth]
paste.filter_factory = keystone.middleware:TokenAuthMiddleware.factory

[filter:admin_token_auth]
paste.filter_factory = keystone.middleware:AdminTokenAuthMiddleware.factory

#[filter:xml_body]
#paste.filter_factory = keystone.middleware:XmlBodyMiddleware.factory

[filter:json_body]
paste.filter_factory = keystone.middleware:JsonBodyMiddleware.factory

[filter:user_crud_extension]
paste.filter_factory = keystone.contrib.user_crud:CrudExtension.factory

[filter:crud_extension]
paste.filter_factory = keystone.contrib.admin_crud:CrudExtension.factory

[filter:ec2_extension]
paste.filter_factory = keystone.contrib.ec2:Ec2Extension.factory

[filter:s3_extension]
paste.filter_factory = keystone.contrib.s3:S3Extension.factory
[filter:url_normalize]
paste.filter_factory = keystone.middleware:NormalizingFilter.factory

[filter:sizelimit]
paste.filter_factory = keystone.middleware:RequestBodySizeLimiter.factory

[filter:stats_monitoring]
paste.filter_factory = keystone.contrib.stats:StatsMiddleware.factory

[filter:stats_reporting]
paste.filter_factory = keystone.contrib.stats:StatsExtension.factory

[filter:access_log]
paste.filter_factory = keystone.contrib.access:AccessLogMiddleware.factory

[app:public_service]
paste.app_factory = keystone.service:public_app_factory

[app:service_v3]
paste.app_factory = keystone.service:v3_app_factory

[app:admin_service]
paste.app_factory = keystone.service:admin_app_factory

[pipeline:public_api]
pipeline = access_log sizelimit stats_monitoring url_normalize token_auth admin_token_auth xml_body json_body debug ec2_extension user_crud_extension public_service

[pipeline:admin_api]
pipeline = access_log sizelimit stats_monitoring url_normalize token_auth admin_token_auth xml_body json_body debug stats_reporting ec2_extension s3_extension crud_extension admin_service

[app:public_version_service]
paste.app_factory = keystone.service:public_version_app_factory

[app:admin_version_service]
paste.app_factory = keystone.service:admin_version_app_factory

[pipeline:public_version_api]
pipeline = access_log sizelimit stats_monitoring url_normalize xml_body public_version_service

[pipeline:admin_version_api]
pipeline = access_log sizelimit stats_monitoring url_normalize xml_body admin_version_service

[pipeline:api_v3]
pipeline = access_log sizelimit stats_monitoring url_normalize token_auth admin_token_auth xml_body json_body debug stats_reporting ec2_extension s3_extension service_v3

[composite:main]
use = egg:Paste#urlmap
/v2.0 = public_api
/v3 = api_v3
/ = public_version_api

[composite:admin]
use = egg:Paste#urlmap
/v2.0 = admin_api
/v3 = api_v3
/ = admin_version_api
EOP
) >> /etc/keystone/keystone.conf
sed -i 's/connection = postgresql.*/connection=postgresql:\/\/transuser:'${MASTER_PWD}'@localhost\/keystone/g' /etc/keystone/keystone.conf

#make sure keystone owns the files
chown -R keystone:keystone /etc/keystone
#chmod -R 664 /etc/keystone

#create the keys
keystone-manage pki_setup --keystone-user keystone --keystone-group keystone
chown -R keystone:keystone /etc/keystone/ssl
chmod -R o-rwx /etc/keystone/ssl

chown -R keystone:keystone /var/log/keystone

#enable keystone
chkconfig openstack-keystone on
#restart keystone
service openstack-keystone restart
sleep 5
#sync keystone dbchmod 
keystone-manage db_sync
sleep 5


#create default factory creds file
echo "export OS_SERVICE_TOKEN="${ADMIN_TOKEN}"" > /home/transuser/factory_creds 
(
cat <<'EOP'
export OS_USERNAME=admin
export OS_PASSWORD=password
export OS_TENANT_NAME=trans_default
export OS_AUTH_URL=http://localhost:5000/v2.0
export OS_REGION_NAME=TransCirrusCloud
export OS_SERVICE_ENDPOINT=http://localhost:35357/v2.0
EOP
) >> /home/transuser/factory_creds

chmod 0666 /home/transuser/factory_creds
chown transuser:transystem /home/transuser/factory_creds
#source /home/transuser/factory_creds
export OS_SERVICE_TOKEN=${ADMIN_TOKEN}
export OS_USERNAME=admin
export OS_PASSWORD=password
export OS_TENANT_NAME=trans_default
export OS_AUTH_URL=http://localhost:5000/v2.0
export OS_REGION_NAME=TransCirrusCloud
export OS_SERVICE_ENDPOINT=http://localhost:35357/v2.0

# Shortcut function to get a newly generated ID
function get_field() {
    while read data; do
        if [ "$1" -lt 0 ]; then
            field="(\$(NF$1))"
        else
            field="\$$(($1 + 1))"
        fi
        echo "$data" | awk -F'[ \t]*\\|[ \t]*' "{print $field}"
    done
}

#set up keystone
#set up the initial keystone entries just to get things working
CONTROLLER_PUBLIC_ADDRESS=${CONTROLLER_PUBLIC_ADDRESS:-$HOSTNAME}
CONTROLLER_ADMIN_ADDRESS=${CONTROLLER_ADMIN_ADDRESS:-$HOSTNAME}
CONTROLLER_INTERNAL_ADDRESS=${CONTROLLER_INTERNAL_ADDRESS:-$HOSTNAME}

TOOLS_DIR=$(cd $(dirname "$0") && pwd)
KEYSTONE_CONF=${KEYSTONE_CONF:-/etc/keystone/keystone.conf}
if [[ -r "$KEYSTONE_CONF" ]]; then
    EC2RC="$(dirname "$KEYSTONE_CONF")/ec2rc"
elif [[ -r "$TOOLS_DIR/../etc/keystone.conf" ]]; then
    # assume git checkout
    KEYSTONE_CONF="$TOOLS_DIR/../etc/keystone.conf"
    EC2RC="$TOOLS_DIR/../etc/ec2rc"
else
    KEYSTONE_CONF="/etc/keystone/keystone.conf"
    EC2RC="ec2rc"
fi

# Extract some info from Keystone's configuration file
if [[ -r "$KEYSTONE_CONF" ]]; then
    CONFIG_SERVICE_TOKEN=$(sed 's/[[:space:]]//g' $KEYSTONE_CONF | grep ^admin_token= | cut -d'=' -f2)
    CONFIG_ADMIN_PORT=$(sed 's/[[:space:]]//g' $KEYSTONE_CONF | grep ^admin_port= | cut -d'=' -f2)
fi

export ADMIN_TOKEN=${SERVICE_TOKEN:-$CONFIG_SERVICE_TOKEN}
if [[ -z "$ADMIN_TOKEN" ]]; then
    echo "No service token found."
    echo "Set SERVICE_TOKEN manually from keystone.conf admin_token."
    exit 1
fi

export SERVICE_ENDPOINT=${SERVICE_ENDPOINT:-http://$CONTROLLER_PUBLIC_ADDRESS:${CONFIG_ADMIN_PORT:-35357}/v2.0}

#
# Default tenant
#
TRANS_TENANT=$(keystone tenant-create --name=trans_default --description "Default Tenant" | grep " id " | get_field 2)

ADMIN_USER=$(keystone user-create --name=admin --pass=password | grep " id " | get_field 2)

ADMIN_ROLE=$(keystone role-create --name=admin | grep " id " | get_field 2)
MEMBER_ROLE=$(keystone role-create --name=Member | grep " id " | get_field 2)
DEF_MEM_ROLE=$(keystone role-list | grep " _member_ " | get_field 1)

keystone user-role-add --user-id $ADMIN_USER \
                       --role-id $ADMIN_ROLE \
                       --tenant-id $TRANS_TENANT

#
# Service tenant
#
SERVICE_TENANT=$(keystone tenant-create --name=service \
                                               --description "Service Tenant" | grep " id " | get_field 2)

GLANCE_USER=$(keystone user-create --name=glance \
                                          --pass=$MASTER_PWD \
                                          --tenant-id $SERVICE_TENANT | grep " id " | get_field 2)

keystone user-role-add --user-id $GLANCE_USER \
                       --role-id $ADMIN_ROLE \
                       --tenant-id $SERVICE_TENANT


CINDER_USER=$(keystone user-create --name=cinder \
                                          --pass=$MASTER_PWD \
                                          --tenant-id $SERVICE_TENANT | grep " id " | get_field 2)

keystone user-role-add --user-id $CINDER_USER \
                       --role-id $ADMIN_ROLE \
                       --tenant-id $SERVICE_TENANT

NEUTRON_USER=$(keystone user-create --name=neutron \
                                          --pass=$MASTER_PWD \
                                          --tenant-id $SERVICE_TENANT | grep " id " | get_field 2)

keystone user-role-add --user-id $NEUTRON_USER \
                       --role-id $ADMIN_ROLE \
                       --tenant-id $SERVICE_TENANT


NOVA_USER=$(keystone user-create --name=nova \
                                        --pass=$MASTER_PWD \
                                        --tenant-id $SERVICE_TENANT | grep " id " | get_field 2)

keystone user-role-add --user-id $NOVA_USER \
                       --role-id $ADMIN_ROLE \
                       --tenant-id $SERVICE_TENANT

EC2_USER=$(keystone user-create --name=ec2 \
                                       --pass=$MASTER_PWD \
                                       --tenant-id $SERVICE_TENANT | grep " id " | get_field 2)

keystone user-role-add --user-id $EC2_USER \
                       --role-id $ADMIN_ROLE \
                       --tenant-id $SERVICE_TENANT

S3_USER=$(keystone user-create --name=s3 \
                                       --pass=$MASTER_PWD \
                                       --tenant-id $SERVICE_TENANT | grep " id " | get_field 2)

keystone user-role-add --user-id $S3_USER \
                       --role-id $ADMIN_ROLE \
                       --tenant-id $SERVICE_TENANT

SWIFT_USER=$(keystone user-create --name=swift \
                                         --pass=$MASTER_PWD \
                                         --tenant-id $SERVICE_TENANT | grep " id " | get_field 2)

keystone user-role-add --user-id $SWIFT_USER \
                       --role-id $ADMIN_ROLE \
                       --tenant-id $SERVICE_TENANT

CEILOMETER_USER=$(keystone user-create --name=ceilometer \
                                         --pass=$MASTER_PWD \
                                         --tenant-id $SERVICE_TENANT | grep " id " | get_field 2)

keystone user-role-add --user-id $CEILOMETER_USER \
                       --role-id $ADMIN_ROLE \
                       --tenant-id $SERVICE_TENANT

HEAT_USER=$(keystone user-create --name=heat \
                                         --pass=$MASTER_PWD \
                                         --tenant-id $SERVICE_TENANT | grep " id " | get_field 2)

keystone user-role-add --user-id $HEAT_USER \
                       --role-id $ADMIN_ROLE \
                       --tenant-id $SERVICE_TENANT

keystone-manage pki_setup
chown -R keystone:keystone /etc/keystone

#
# Keystone service
#
KEYSTONE_SERVICE=$(keystone service-create --name=keystone \
                        --type=identity \
                        --description="Keystone Identity Service" | grep " id " | get_field 2)
if [[ -z "$DISABLE_ENDPOINTS" ]]; then
    keystone endpoint-create --region TransCirrusCloud --service-id $KEYSTONE_SERVICE \
        --publicurl "http://$CONTROLLER_PUBLIC_ADDRESS:5000/v2.0" \
        --adminurl "http://$CONTROLLER_ADMIN_ADDRESS:35357/v2.0" \
        --internalurl "http://$CONTROLLER_INTERNAL_ADDRESS:5000/v2.0"
fi

#insert the Service tenant and Default admin project into trans_system_settings
psql -U postgres -d transcirrus -c "INSERT INTO trans_system_settings VALUES ('trans_default_id','"${TRANS_TENANT}"','"${HOSTNAME}"');"
psql -U postgres -d transcirrus -c "INSERT INTO trans_system_settings VALUES ('service_id','"${SERVICE_TENANT}"','"${HOSTNAME}"');"

#add admin and trans_default project to transcirrus db
psql -U postgres -d transcirrus -c "INSERT INTO trans_user_info VALUES (0, 'admin', 'admin', 0, 'TRUE', '"${ADMIN_USER}"', 'trans_default','"${TRANS_TENANT}"', 'admin', NULL);"
psql -U postgres -d transcirrus -c "INSERT INTO projects VALUES ('"${TRANS_TENANT}"', 'trans_default',NULL,NULL,NULL,NULL,'"${HOSTNAME}"','172.24.24.10',NULL,NULL);"

#add the default availability zone
psql -U postgres -d transcirrus -c "INSERT INTO trans_user_info VALUES (0, 'nova', 'The default availability zone.');"

#update the keystone endpoint
psql -U postgres -d transcirrus -c "UPDATE trans_service_settings SET service_id='"${KEYSTONE_SERVICE}"',service_admin_ip='"${CONTROLLER_PUBLIC_ADDRESS}"',service_int_ip='"${CONTROLLER_PUBLIC_ADDRESS}"',service_public_ip='"${CONTROLLER_PUBLIC_ADDRESS}"',service_endpoint_id='"${KEYSTONE_ENDPOINT}"' WHERE service_port=5000;"
psql -U postgres -d transcirrus -c "UPDATE trans_service_settings SET service_id='"${KEYSTONE_SERVICE}"',service_admin_ip='"${CONTROLLER_PUBLIC_ADDRESS}"',service_int_ip='"${CONTROLLER_PUBLIC_ADDRESS}"',service_public_ip='"${CONTROLLER_PUBLIC_ADDRESS}"',service_endpoint_id='"${KEYSTONE_ENDPOINT}"' WHERE service_port=35357;"

#Add in the default system values THESE WILL NEVER BE TOUCHED AGAIN. Used to keep
#system from turning into mush at initial setup.
echo "Adding the default system settings."
psql -U postgres -d transcirrus -c "INSERT INTO trans_system_settings VALUES ('member_role_id','"${MEMBER_ROLE}"','"${HOSTNAME}"');"
psql -U postgres -d transcirrus -c "INSERT INTO trans_system_settings VALUES ('def_member_role_id','"${DEF_MEM_ROLE}"','"${HOSTNAME}"');"
psql -U postgres -d transcirrus -c "INSERT INTO trans_system_settings VALUES ('admin_token','"${ADMIN_TOKEN}"','"${HOSTNAME}"');"
psql -U postgres -d transcirrus -c "INSERT INTO trans_system_settings VALUES ('mgmt_ip','"${CONTROLLER_PUBLIC_ADDRESS}"','"${HOSTNAME}"');"
psql -U postgres -d transcirrus -c "INSERT INTO trans_system_settings VALUES ('hosted_flavor','0','"${HOSTNAME}"');"
psql -U postgres -d transcirrus -c "INSERT INTO trans_system_settings VALUES ('api_ip','"${CONTROLLER_PUBLIC_ADDRESS}"','"${HOSTNAME}"');"
psql -U postgres -d transcirrus -c "INSERT INTO trans_system_settings VALUES ('admin_role_id','"${ADMIN_ROLE}"','"${HOSTNAME}"');"
psql -U postgres -d transcirrus -c "INSERT INTO trans_system_settings VALUES ('node_type','cc','"${HOSTNAME}"');"
psql -U postgres -d transcirrus -c "INSERT INTO trans_system_settings VALUES ('admin_api_ip','"${CONTROLLER_PUBLIC_ADDRESS}"','"${HOSTNAME}"');"
psql -U postgres -d transcirrus -c "INSERT INTO trans_system_settings VALUES ('int_api_ip','"${CONTROLLER_PUBLIC_ADDRESS}"','"${HOSTNAME}"');"
psql -U postgres -d transcirrus -c "INSERT INTO trans_system_settings VALUES ('admin_pass_set','0','"${HOSTNAME}"');"
psql -U postgres -d transcirrus -c "INSERT INTO trans_system_settings VALUES ('first_time_boot','1','"${HOSTNAME}"');"
psql -U postgres -d transcirrus -c "INSERT INTO trans_system_settings VALUES ('cloud_name','TransCirrusCloud','"${HOSTNAME}"');"
psql -U postgres -d transcirrus -c "INSERT INTO trans_system_settings VALUES ('single_node','1','"${HOSTNAME}"');"
psql -U postgres -d transcirrus -c "INSERT INTO trans_system_settings VALUES ('transcirrus_db','172.24.24.10','"${HOSTNAME}"');"
psql -U postgres -d transcirrus -c "INSERT INTO trans_system_settings VALUES ('tran_db_user','transuser','"${HOSTNAME}"');"
psql -U postgres -d transcirrus -c "INSERT INTO trans_system_settings VALUES ('tran_db_pass','"$MASTER_PWD"','"${HOSTNAME}"');"
psql -U postgres -d transcirrus -c "INSERT INTO trans_system_settings VALUES ('tran_db_name','transcirrus','"${HOSTNAME}"');"
psql -U postgres -d transcirrus -c "INSERT INTO trans_system_settings VALUES ('tran_db_port','5432','"${HOSTNAME}"');"
psql -U postgres -d transcirrus -c "INSERT INTO trans_system_settings VALUES ('cloud_controller_id','"${NODEID}"','"${HOSTNAME}"');"
psql -U postgres -d transcirrus -c "INSERT INTO trans_system_settings VALUES ('os_db','172.24.24.10','"${HOSTNAME}"');"
psql -U postgres -d transcirrus -c "INSERT INTO trans_system_settings VALUES ('vm_ip_min','0.0.0.0','"${HOSTNAME}"');"
psql -U postgres -d transcirrus -c "INSERT INTO trans_system_settings VALUES ('vm_ip_max','0.0.0.0','"${HOSTNAME}"');"
psql -U postgres -d transcirrus -c "INSERT INTO trans_system_settings VALUES ('os_db_user','transuser','"${HOSTNAME}"');"
psql -U postgres -d transcirrus -c "INSERT INTO trans_system_settings VALUES ('os_db_pass','"$MASTER_PWD"','"${HOSTNAME}"');"
psql -U postgres -d transcirrus -c "INSERT INTO trans_system_settings VALUES ('os_db_port','5432','"${HOSTNAME}"');"
psql -U postgres -d transcirrus -c "INSERT INTO trans_system_settings VALUES ('node_id','"${NODEID}"','"${HOSTNAME}"');"
psql -U postgres -d transcirrus -c "INSERT INTO trans_system_settings VALUES ('hosted_os','0','"${HOSTNAME}"');"
psql -U postgres -d transcirrus -c "INSERT INTO trans_system_settings VALUES ('cloud_controller','"${HOSTNAME}"','"${HOSTNAME}"');"
psql -U postgres -d transcirrus -c "INSERT INTO trans_system_settings VALUES ('uplink_ip','0.0.0.0','"${HOSTNAME}"');"
psql -U postgres -d transcirrus -c "INSERT INTO trans_system_settings VALUES ('node_name','"${HOSTNAME}"','"${HOSTNAME}"');"
psql -U postgres -d transcirrus -c "INSERT INTO trans_system_settings VALUES ('default_pub_net_id','0','"${HOSTNAME}"');"
psql -U postgres -d transcirrus -c "INSERT INTO trans_system_settings VALUES ('default_pub_subnet_id','0','"${HOSTNAME}"');"
psql -U postgres -d transcirrus -c "INSERT INTO trans_system_settings VALUES ('software_version','alpo.0','"${HOSTNAME}"');"
psql -U postgres -d transcirrus -c "INSERT INTO trans_system_settings VALUES ('uplink_subnet','255.255.255.0','"${HOSTNAME}"');"
psql -U postgres -d transcirrus -c "INSERT INTO trans_system_settings VALUES ('uplink_gateway','0.0.0.0','"${HOSTNAME}"');"
psql -U postgres -d transcirrus -c "INSERT INTO trans_system_settings VALUES ('uplink_dns','0.0.0.0','"${HOSTNAME}"');"
psql -U postgres -d transcirrus -c "INSERT INTO trans_system_settings VALUES ('uplink_domain_name','localdomain','"${HOSTNAME}"');"
psql -U postgres -d transcirrus -c "INSERT INTO trans_system_settings VALUES ('mgmt_subnet','255.255.255.0','"${HOSTNAME}"');"
psql -U postgres -d transcirrus -c "INSERT INTO trans_system_settings VALUES ('mgmt_dns','0.0.0.0','"${HOSTNAME}"');"
psql -U postgres -d transcirrus -c "INSERT INTO trans_system_settings VALUES ('mgmt_domain_name','localdomain','"${HOSTNAME}"');"
psql -U postgres -d transcirrus -c "INSERT INTO trans_system_settings VALUES ('cluster_ip','"${IP}"','"${HOSTNAME}"');"
psql -U postgres -d transcirrus -c "INSERT INTO trans_system_settings VALUES ('physical_node','0','"${HOSTNAME}"');"
psql -U postgres -d transcirrus -c "INSERT INTO trans_system_settings VALUES ('spindle_node','0','"${HOSTNAME}"');"
psql -U postgres -d transcirrus -c "INSERT INTO trans_system_settings VALUES ('hybrid_node','0','"${HOSTNAME}"');"
psql -U postgres -d transcirrus -c "INSERT INTO trans_system_settings VALUES ('master_pwd','"$MASTER_PWD"','"${HOSTNAME}"');"
#psql -U postgres -d transcirrus -c "INSERT INTO trans_system_settings VALUES ('host_system','"${HOSTNAME}"','"${HOSTNAME}"');"

#add the system defaults setting. These settings are the exact same but will never be touched again.Used to reset to factory default
psql -U postgres -d transcirrus -c "INSERT INTO factory_defaults VALUES ('member_role_id','"${MEMBER_ROLE}"','"${HOSTNAME}"');"
psql -U postgres -d transcirrus -c "INSERT INTO factory_defaults VALUES ('def_member_role_id','"${DEF_MEM_ROLE}"','"${HOSTNAME}"');"
psql -U postgres -d transcirrus -c "INSERT INTO factory_defaults VALUES ('admin_token','"${ADMIN_TOKEN}"','"${HOSTNAME}"');"
psql -U postgres -d transcirrus -c "INSERT INTO factory_defaults VALUES ('mgmt_ip','"${CONTROLLER_PUBLIC_ADDRESS}"','"${HOSTNAME}"');"
psql -U postgres -d transcirrus -c "INSERT INTO factory_defaults VALUES ('hosted_flavor','0','"${HOSTNAME}"');"
psql -U postgres -d transcirrus -c "INSERT INTO factory_defaults VALUES ('api_ip','"${CONTROLLER_PUBLIC_ADDRESS}"','"${HOSTNAME}"');"
psql -U postgres -d transcirrus -c "INSERT INTO factory_defaults VALUES ('admin_role_id','"${ADMIN_ROLE}"','"${HOSTNAME}"');"
psql -U postgres -d transcirrus -c "INSERT INTO factory_defaults VALUES ('node_type','cc','"${HOSTNAME}"');"
psql -U postgres -d transcirrus -c "INSERT INTO factory_defaults VALUES ('admin_api_ip','"${CONTROLLER_PUBLIC_ADDRESS}"','"${HOSTNAME}"');"
psql -U postgres -d transcirrus -c "INSERT INTO factory_defaults VALUES ('int_api_ip','"${CONTROLLER_PUBLIC_ADDRESS}"','"${HOSTNAME}"');"
psql -U postgres -d transcirrus -c "INSERT INTO factory_defaults VALUES ('admin_pass_set','0','"${HOSTNAME}"');"
psql -U postgres -d transcirrus -c "INSERT INTO factory_defaults VALUES ('first_time_boot','1','"${HOSTNAME}"');"
psql -U postgres -d transcirrus -c "INSERT INTO factory_defaults VALUES ('cloud_name','TransCirrusCloud','"${HOSTNAME}"');"
psql -U postgres -d transcirrus -c "INSERT INTO factory_defaults VALUES ('single_node','1','"${HOSTNAME}"');"
psql -U postgres -d transcirrus -c "INSERT INTO factory_defaults VALUES ('transcirrus_db','172.24.24.10','"${HOSTNAME}"');"
psql -U postgres -d transcirrus -c "INSERT INTO factory_defaults VALUES ('tran_db_user','transuser','"${HOSTNAME}"');"
psql -U postgres -d transcirrus -c "INSERT INTO factory_defaults VALUES ('tran_db_pass','"$MASTER_PWD"','"${HOSTNAME}"');"
psql -U postgres -d transcirrus -c "INSERT INTO factory_defaults VALUES ('tran_db_name','transcirrus','"${HOSTNAME}"');"
psql -U postgres -d transcirrus -c "INSERT INTO factory_defaults VALUES ('tran_db_port','5432','"${HOSTNAME}"');"
psql -U postgres -d transcirrus -c "INSERT INTO factory_defaults VALUES ('cloud_controller_id','"${NODEID}"','"${HOSTNAME}"');"
psql -U postgres -d transcirrus -c "INSERT INTO factory_defaults VALUES ('os_db','172.24.24.10','"${HOSTNAME}"');"
psql -U postgres -d transcirrus -c "INSERT INTO factory_defaults VALUES ('vm_ip_min','0.0.0.0','"${HOSTNAME}"');"
psql -U postgres -d transcirrus -c "INSERT INTO factory_defaults VALUES ('vm_ip_max','0.0.0.0','"${HOSTNAME}"');"
psql -U postgres -d transcirrus -c "INSERT INTO factory_defaults VALUES ('os_db_user','transuser','"${HOSTNAME}"');"
psql -U postgres -d transcirrus -c "INSERT INTO factory_defaults VALUES ('os_db_pass','"$MASTER_PWD"','"${HOSTNAME}"');"
psql -U postgres -d transcirrus -c "INSERT INTO factory_defaults VALUES ('os_db_port','5432','"${HOSTNAME}"');"
psql -U postgres -d transcirrus -c "INSERT INTO factory_defaults VALUES ('node_id','"${NODEID}"','"${HOSTNAME}"');"
psql -U postgres -d transcirrus -c "INSERT INTO factory_defaults VALUES ('hosted_os','0','"${HOSTNAME}"');"
psql -U postgres -d transcirrus -c "INSERT INTO factory_defaults VALUES ('cloud_controller','"${HOSTNAME}"','"${HOSTNAME}"');"
psql -U postgres -d transcirrus -c "INSERT INTO factory_defaults VALUES ('uplink_ip','0.0.0.0','"${HOSTNAME}"');"
psql -U postgres -d transcirrus -c "INSERT INTO factory_defaults VALUES ('node_name','"${HOSTNAME}"','"${HOSTNAME}"');"
psql -U postgres -d transcirrus -c "INSERT INTO factory_defaults VALUES ('default_pub_net_id','0','"${HOSTNAME}"');"
psql -U postgres -d transcirrus -c "INSERT INTO factory_defaults VALUES ('default_pub_subnet_id','0','"${HOSTNAME}"');"
psql -U postgres -d transcirrus -c "INSERT INTO factory_defaults VALUES ('uplink_subnet','255.255.255.0','"${HOSTNAME}"');"
psql -U postgres -d transcirrus -c "INSERT INTO factory_defaults VALUES ('uplink_gateway','0.0.0.0','"${HOSTNAME}"');"
psql -U postgres -d transcirrus -c "INSERT INTO factory_defaults VALUES ('uplink_dns','0.0.0.0','"${HOSTNAME}"');"
psql -U postgres -d transcirrus -c "INSERT INTO factory_defaults VALUES ('uplink_domain_name','localdomain','"${HOSTNAME}"');"
psql -U postgres -d transcirrus -c "INSERT INTO factory_defaults VALUES ('mgmt_subnet','255.255.255.0','"${HOSTNAME}"');"
psql -U postgres -d transcirrus -c "INSERT INTO factory_defaults VALUES ('mgmt_dns','0.0.0.0','"${HOSTNAME}"');"
psql -U postgres -d transcirrus -c "INSERT INTO factory_defaults VALUES ('mgmt_domain_name','localdomain','"${HOSTNAME}"');"
psql -U postgres -d transcirrus -c "INSERT INTO factory_defaults VALUES ('cluster_ip','"${IP}"','"${HOSTNAME}"');"
psql -U postgres -d transcirrus -c "INSERT INTO factory_defaults VALUES ('physical_node','0','"${HOSTNAME}"');"
psql -U postgres -d transcirrus -c "INSERT INTO factory_defaults VALUES ('spindle_node','0','"${HOSTNAME}"');"
psql -U postgres -d transcirrus -c "INSERT INTO factory_defaults VALUES ('hybrid_node','0','"${HOSTNAME}"');"
psql -U postgres -d transcirrus -c "INSERT INTO factory_defaults VALUES ('master_pwd','"$MASTER_PWD"','"${HOSTNAME}"');"
#psql -U postgres -d transcirrus -c "INSERT INTO factory_defaults VALUES ('host_system','"${HOSTNAME}"','"${HOSTNAME}"');"

#insert the default private subnets
for x in {0..3}
do
    for i in {0..254}
    do
        psql -U postgres -d transcirrus -c "INSERT INTO trans_subnets VALUES('$(($x * 255 + $i))',NULL,'c','4','10.$x.$(($i % 255)).0/24','10.$x.$(($i % 255)).1','10.$x.$(($i % 255)).2','10.$x.$(($i % 255)).254',NULL,NULL,NULL,'false',0,'int-sub-$(($x * 255 + $i))','255.255.255.0');"
    done
done

#general configuration in SQL
psql -U postgres -d transcirrus -c "INSERT INTO heat_default VALUES ('rabbit_password', '"${MASTER_PWD}"', 'heat.conf');"
psql -U postgres -d transcirrus -c "INSERT INTO heat_default VALUES ('admin_password', '"${MASTER_PWD}"', 'heat.conf');"
psql -U postgres -d transcirrus -c "INSERT INTO ceilometer_default VALUES ('rabbit_password', '"${MASTER_PWD}"', 'ceilometer.conf');"
psql -U postgres -d transcirrus -c "INSERT INTO ceilometer_default VALUES ('admin_password', '"${MASTER_PWD}"', 'ceilometer.conf');"
psql -U postgres -d transcirrus -c "INSERT INTO ceilometer_default VALUES ('os_password', '"${MASTER_PWD}"', 'ceilometer.conf');"\
psql -U postgres -d transcirrus -c "INSERT INTO cinder_default VALUES ('admin_password', '"${MASTER_PWD}"', 'api-paste.ini');"
psql -U postgres -d transcirrus -c "INSERT INTO cinder_default VALUES ('admin_password', '"${MASTER_PWD}"', 'cinder.conf');"
psql -U postgres -d transcirrus -c "INSERT INTO cinder_default VALUES ('rabbit_password', '"${MASTER_PWD}"', 'cinder.conf');"
psql -U postgres -d transcirrus -c "INSERT INTO glance_defaults VALUES ('rabbit_password', '"${MASTER_PWD}"','NULL','glance-api.conf');"
psql -U postgres -d transcirrus -c "INSERT INTO glance_defaults VALUES ('admin_password', '"${MASTER_PWD}"','NULL','glance-api.conf');"
psql -U postgres -d transcirrus -c "INSERT INTO glance_defaults VALUES ('rabbit_password', '"${MASTER_PWD}"','NULL','glance-registry.conf');"
psql -U postgres -d transcirrus -c "INSERT INTO glance_defaults VALUES ('admin_password', '"${MASTER_PWD}"','NULL','glance-registry.conf');"
psql -U postgres -d transcirrus -c "INSERT INTO glance_defaults VALUES ('admin_password', '"${MASTER_PWD}"','NULL','glance-scrubber.conf');"
psql -U postgres -d transcirrus -c "INSERT INTO neutron_default VALUES ('admin_password', '"${MASTER_PWD}"','metadata_agent.ini');"
psql -U postgres -d transcirrus -c "INSERT INTO neutron_default VALUES ('metadata_proxy_shared_secret', '"${MASTER_PWD}"','metadata_agent.ini');"
psql -U postgres -d transcirrus -c "INSERT INTO neutron_default VALUES ('rabbit_password', '"${MASTER_PWD}"','neutron.conf');"
psql -U postgres -d transcirrus -c "INSERT INTO neutron_default VALUES ('nova_admin_password', '"${MASTER_PWD}"','neutron.conf');"
psql -U postgres -d transcirrus -c "INSERT INTO neutron_default VALUES ('admin_password', '"${MASTER_PWD}"','neutron.conf');"
psql -U postgres -d transcirrus -c "INSERT INTO nova_default VALUES ('rabbit_password', '"${MASTER_PWD}"','nova.conf');"
psql -U postgres -d transcirrus -c "INSERT INTO nova_default VALUES ('neutron_metadata_proxy_shared_secret', '"${MASTER_PWD}"','nova.conf');"
psql -U postgres -d transcirrus -c "INSERT INTO nova_default VALUES ('neutron_admin_password', '"${MASTER_PWD}"','nova.conf');"
psql -U postgres -d transcirrus -c "INSERT INTO nova_default VALUES ('admin_password', '"${MASTER_PWD}"','nova.conf');"


echo "NODE_ID='"${NODEID}"'" >> /usr/local/lib/python2.7/transcirrus/common/config.py
echo "NODE_NAME='"${HOSTNAME}"'" >> /usr/local/lib/python2.7/transcirrus/common/config.py
echo "NODE_TYPE='cc'" >> /usr/local/lib/python2.7/transcirrus/common/config.py
echo "MASTER_PWD='"$MASTER_PWD"'" >> /usr/local/lib/python2.7/transcirrus/common/config.py

echo "TRANSCIRRUS_DB='172.24.24.10'" >> /usr/local/lib/python2.7/transcirrus/common/config.py
echo "TRAN_DB_USER='transuser'" >> /usr/local/lib/python2.7/transcirrus/common/config.py
echo "TRAN_DB_PASS='"$MASTER_PWD"'" >> /usr/local/lib/python2.7/transcirrus/common/config.py
echo "TRAN_DB_NAME='transcirrus'" >> /usr/local/lib/python2.7/transcirrus/common/config.py
echo "TRAN_DB_PORT='5432'" >> /usr/local/lib/python2.7/transcirrus/common/config.py
echo "UPLINK_IP='0.0.0.0'" >> /usr/local/lib/python2.7/transcirrus/common/config.py
echo "CLUSTER_IP='"${IP}"'" >> /usr/local/lib/python2.7/transcirrus/common/config.py

#change during setup if needed from DB vars
echo "ADMIN_TOKEN='"${ADMIN_TOKEN}"'" >> /usr/local/lib/python2.7/transcirrus/common/config.py
echo "API_IP='"${CONTROLLER_INTERNAL_ADDRESS}"'" >> /usr/local/lib/python2.7/transcirrus/common/config.py

#change this, update as neccessary from setup operation
echo "CLOUD_CONTROLLER='"${HOSTNAME}"'" >> /usr/local/lib/python2.7/transcirrus/common/config.py
echo "CLOUD_CONTROLLER_ID='"${NODEID}"'" >> /usr/local/lib/python2.7/transcirrus/common/config.py
echo "CLOUD_NAME='TransCirrusCloud'" >> /usr/local/lib/python2.7/transcirrus/common/config.py

#DEFAULT openstack roles
echo "MEMBER_ROLE_ID='"${MEMBER_ROLE}"'" >> /usr/local/lib/python2.7/transcirrus/common/config.py
echo "ADMIN_ROLE_ID='"${ADMIN_ROLE}"'" >> /usr/local/lib/python2.7/transcirrus/common/config.py
echo "DEF_MEMBER_ROLE_ID='"${DEF_MEM_ROLE}"'" >> /usr/local/lib/python2.7/transcirrus/common/config.py

#this needs to be added when initial setup is done
#echo 'DEFAULT_PUB_NET_ID="a1c45bf0-af33-4fa0-b53a-5bd4f9d3276e"'>> /usr/local/lib/python2.7/dist-packages/transcirrus/common/config.py

##DEFAULT OPENSTACK DB SETTINGS##
echo "OS_DB='172.24.24.10'" >> /usr/local/lib/python2.7/transcirrus/common/config.py
echo "OS_DB_PORT='5432'" >> /usr/local/lib/python2.7/transcirrus/common/config.py
echo "OS_DB_USER='transuser'" >> /usr/local/lib/python2.7/transcirrus/common/config.py
echo "OS_DB_PASS='"$MASTER_PWD"'" >> /usr/local/lib/python2.7/transcirrus/common/config.py
echo "MGMT_IP='192.168.0.3'" >> /usr/local/lib/python2.7/transcirrus/common/config.py


#Format the raid 6 as xfs - ssd
parted -s -a optimal /dev/sdb mklabel gpt -- mkpart primary xfs 1 -1
mkfs.xfs -f /dev/sdb1

#Format the raid 6 as xfs - spindle
parted -s -a optimal /dev/sdc mklabel gpt -- mkpart primary xfs 1 -1
mkfs.xfs -f /dev/sdc1

#set up glusterFS
mkdir -p /data/gluster
mkdir -p /data/gluster-spindle

echo '/dev/sdb1 /data/gluster xfs defaults 1 2' >> /etc/fstab
echo '/dev/sdc1 /data/gluster-spindle xfs defaults 1 2' >> /etc/fstab
mount -a && mount

#gluster log
mkdir -p /var/log/glusterfs/

#gluster mount dir
mkdir -p /mnt/gluster-vols/cinder-volume
chown -R cinder:cinder /mnt/gluster-vols/cinder-volume

#open ports in the firewall 
for x in {'111','24007','24008','24009','24010','24011','24012','24013','24014','24015','24016','24017','24018','24019','24020','24021','24022','24023','24025','24026','24027','24028','24029','34865','34866','34867'}
do
    iptables -A INPUT -p tcp --dport ${x} -j ACCEPT
    iptables -A INPUT -p udp --dport ${x} -j ACCEPT
done

iptables-save >> /transcirrus/iptables.rules

#install pylons
#easy_install pylons

#add libffi-devel
wget -P /root http://192.168.10.10/rhat_ic/ciac_files/libffi-devel-3.0.5-3.2.el6.x86_64.rpm
#rpm -ivh /root/libffi-devel-3.0.5-3.2.el6.x86_64.rpm

#build swift 1.13.1
#wget -P /root http://192.168.10.10/rhat_ic/ciac_files/swift-1.13.1.tar.gz
#tar -zxvf /root/swift-1.13.1.tar.gz -C /root
#cd /root/swift-1.13.1
#python ./setup.py build
#python ./setup.py install

#wget -P /root http://192.168.10.10/rhat_ic/gluster/gluster-swift-1.13.1-2.tar
#tar -xvf /root/gluster-swift-1.13.1-2.tar -C /root
wget -P /root http://192.168.10.10/rhat_ic/gluster/swiftonfile-1.13.1-2.tar
tar -xvf /root/swiftonfile-1.13.1-2.tar -C /root
cd /root/swiftonfile-1.13.1-2
python ./setup.py install
cd /root/swiftonfile-1.13.1-2/etc/
mv /etc/swift/account-server.conf /etc/swift/account-server.conf.old
mv /etc/swift/container-server.conf /etc/swift/container-server.conf.old
mv /etc/swift/object-server.conf /etc/swift/object-server.conf.old
mv /etc/swift/proxy-server.conf /etc/swift/proxy-server.conf.old
mv /etc/swift/swift.conf /etc/swift/swift.conf.old
#move gluster swift files into place
mv /root/swiftonfile-1.13.1-2/etc/account-server.conf-gluster /etc/swift/account-server.conf
mv /root/swiftonfile-1.13.1-2/etc/container-server.conf-gluster /etc/swift/container-server.conf
mv /root/swiftonfile-1.13.1-2/etc/object-server.conf-gluster /etc/swift/object-server.conf
mv /root/swiftonfile-1.13.1-2/etc/proxy-server.conf-gluster /etc/swift/proxy-server.conf
mv /root/swiftonfile-1.13.1-2/etc/swift.conf-gluster /etc/swift/swift.conf


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

#create the cinder volume
gluster volume create cinder-volume-ssd 172.24.24.10:/data/gluster/cinder-volume-ssd
gluster volume start cinder-volume-ssd
gluster vol set cinder-volume-ssd storage.owner-uid 165
gluster vol set cinder-volume-ssd storage.owner-gid 165
gluster vol set cinder-volume-ssd network.remote-dio enable
gluster vol set cinder-volume-ssd cluster.eager-lock enable
gluster vol set cinder-volume-ssd performance.stat-prefetch off
gluster vol set cinder-volume-ssd performance.read-ahead off
gluster vol set cinder-volume-ssd performance.quick-read off
gluster vol set cinder-volume-ssd performance.io-cache off
gluster vol set cinder-volume-ssd server.allow-insecure on

chmod 775 /data/gluster
chown -R cinder:cinder /data/gluster

gluster volume create cinder-volume-spindle 172.24.24.10:/data/gluster-spindle/cinder-volume-spindle
gluster volume start cinder-volume-spindle
gluster vol set cinder-volume-spindle storage.owner-uid 165
gluster vol set cinder-volume-spindle storage.owner-gid 165
gluster vol set cinder-volume-spindle network.remote-dio enable
gluster vol set cinder-volume-spindle cluster.eager-lock enable
gluster vol set cinder-volume-spindle performance.stat-prefetch off
gluster vol set cinder-volume-spindle performance.read-ahead off
gluster vol set cinder-volume-spindle performance.quick-read off
gluster vol set cinder-volume-spindle performance.io-cache off
gluster vol set cinder-volume-spindle server.allow-insecure on

chmod 775 /data/gluster-spindle
chown -R cinder:cinder /data/gluster-spindle


gluster volume create instances 172.24.24.10:/data/gluster/instances
gluster volume start instances
mount -t glusterfs 172.24.24.10:/instances /var/lib/nova/instances
gluster vol set instances storage.owner-uid 162
gluster vol set instances storage.owner-gid 162
gluster vol set instances network.remote-dio enable
gluster vol set instances cluster.eager-lock enable
gluster vol set instances performance.stat-prefetch off
gluster vol set instances performance.read-ahead off
gluster vol set instances performance.quick-read off
gluster vol set instances performance.io-cache off

echo '172.24.24.10:/instances /var/lib/nova/instances glusterfs defaults,_netdev 0 0' >> /etc/fstab
chown -R nova:nova /var/lib/nova/instances
echo 'chown -R nova:nova /var/lib/nova/instances' >> /etc/rc.local

gluster volume create glance 172.24.24.10:/data/gluster-spindle/glance
gluster volume start glance
mount -t glusterfs 172.24.24.10:/glance /var/lib/glance
gluster vol set glance storage.owner-uid 161
gluster vol set glance storage.owner-gid 99
gluster vol set glance network.remote-dio enable
gluster vol set glance cluster.eager-lock enable
gluster vol set glance performance.stat-prefetch off
gluster vol set glance performance.read-ahead off
gluster vol set glance performance.quick-read off
gluster vol set glance performance.io-cache off

echo '172.24.24.10:/glance /var/lib/glance glusterfs defaults,_netdev 0 0' >> /etc/fstab
chown -R glance:nobody /var/lib/glance
echo 'chown glance:nobody /var/lib/glance' >> /etc/rc.local

#turn on swift
chkconfig openstack-swift-proxy on
chkconfig openstack-swift-account on
chkconfig openstack-swift-container on
chkconfig openstack-swift-object on

#set up disks for swift object storage
gluster-swift-gen-builders storage

service openstack-swift-object start
service openstack-swift-container start
service openstack-swift-account start
service openstack-swift-proxy start

#build the swift endpoint
SWIFT_SERVICE=$(keystone service-create --name=swift \
                        --type=object-store \
                        --description="OpenStack Object Storage" | grep " id " | get_field 2)
if [[ -z "$DISABLE_ENDPOINTS" ]]; then
    keystone endpoint-create --region TransCirrusCloud --service-id $SWIFT_SERVICE \
        --publicurl 'http://'"$CONTROLLER_PUBLIC_ADDRESS"':8080/v1/AUTH_$(tenant_id)s' \
        --adminurl 'http://'"$CONTROLLER_ADMIN_ADDRESS"':8080/v1' \
        --internalurl 'http://'"$CONTROLLER_INTERNAL_ADDRESS"':8080/v1/AUTH_$(tenant_id)s'
fi

psql -U postgres -d transcirrus -c "UPDATE trans_service_settings SET service_id='"${SWIFT_SERVICE}"',service_admin_ip='"${CONTROLLER_PUBLIC_ADDRESS}"',service_int_ip='"${CONTROLLER_PUBLIC_ADDRESS}"',service_public_ip='"${CONTROLLER_PUBLIC_ADDRESS}"',service_endpoint_id='"${SWIFT_ENDPOINT}"' WHERE service_port=8080;"

mv /etc/sysctl.conf /etc/sysctl.conf.old
wget -P /etc http://192.168.10.10/rhat_ic/ciac_files/sysctl.conf
chown root:root /etc/sysctl.conf
chmod 644 /etc/sysctl.conf
sysctl -e -p /etc/sysctl.conf

wget -P /etc http://192.168.10.10/rhat_ic/ciac_files/dhclient.conf
chmod root:root /etc/dhclient.conf
chmod 644 /etc/dhclient.conf

#zero connect startup
wget -P /etc/init.d http://192.168.10.10/rhat_ic/ciac_files/zero_connect
chmod 755 /etc/init.d/zero_connect
chown root:root /etc/init.d/zero_connect
#turn on zero connect
chkconfig --levels 235 zero_connect on

#ceilometer deamon
cp /usr/local/lib/python2.7/transcirrus/daemons/ceilometer_third_party_meters /etc/init.d
chmod 755 /etc/init.d/ceilometer_third_party_meters
chmod 755 /usr/local/lib/python2.7/transcirrus/daemons/ceilometer_third_party_meters
chown root:root /etc/init.d/ceilometer_third_party_meters
chkconfig --levels 235 ceilometer_third_party_meters on
chkconfig --add /etc/init.d/ceilometer_third_party_meters
service ceilometer_third_party_meters restart

#move the openstack interface file out of conf.d
mv /etc/httpd/conf.d/openstack-dashboard.conf ..

#install mod_wsgi
rm -rf /usr/lib64/httpd/modules/mod_wsgi.so
wget -P /root http://192.168.10.10/rhat_ic/ciac_files/mod_wsgi-3.3.tar.gz
tar -zxvf /root/mod_wsgi-3.3.tar.gz -C /root
cd /root/mod_wsgi-3.3
./configure --with-python=/usr/local/bin/python2.7
make
make install

usermod -s /bin/bash nova
#Add the ssh key for nova
wget -P /root http://192.168.10.10/rhat_ic/common/ssh.tar
tar -xvf /root/ssh.tar -C /var/lib/nova

# Load mod wsgi
touch /etc/httpd/conf.d/wsgi.conf
echo "LoadModule wsgi_module modules/mod_wsgi.so" >> /etc/httpd/conf.d/wsgi.conf

#get the web/django server config
wget -P /etc/httpd/conf.d http://192.168.10.10/rhat_ic/ciac_files/transcirrus.conf
chmod 644 /etc/httpd/conf.d/transcirrus.conf
chown root:root /etc/httpd/conf.d/transcirrus.conf

#replace wsgi.so pointer
sed -i 's/modules\/mod_wsgi.so/\/usr\/lib64\/httpd\/modules\/mod_wsgi.so/' /etc/httpd/conf.d/wsgi.conf

#change doc root to /opt/Coalesce
sed -i 's/DocumentRoot \"\/var\/www\/html\"/DocumentRoot \"\/opt\/Coalesce\"/' /etc/httpd/conf/httpd.conf

#turn on openvswitch
chkconfig openvswitch on
service openvswitch start

#set up br-ex
sed -i 's/TYPE=\"Bridge\"/TYPE=\"OVSBridge\"/' /etc/sysconfig/network-scripts/ifcfg-br-ex
#echo 'DEVICETYPE="ovs"' >> /etc/sysconfig/network-scripts/ifcfg-br-ex
sleep 2

sed -i 's/BRIDGE=\"br-ex\"/#BRIDGE=\"br-ex\"/' /etc/sysconfig/network-scripts/ifcfg-eth6
sed -i 's/HWADDR=/#HWADDR=/' /etc/sysconfig/network-scripts/ifcfg-eth6
sed -i 's/HWADDR=/#HWADDR=/' /etc/sysconfig/network-scripts/ifcfg-eth7

#create a link to the updater in transuser home
ln -s /usr/local/lib/python2.7/transcirrus/operations/upgrade.py /home/transuser/upgrade.py
#roll up the support
ln -s /usr/local/lib/python2.7/transcirrus/operations/support_create.py /home/transuser/support_create.py

#purge old tokens every hour
(crontab -l -u keystone 2>&1 | grep -q token_flush) || echo '@hourly /usr/bin/keystone-manage token_flush >/var/log/keystone/keystone-tokenflush.log 2>&1' >> /var/spool/cron/keystone

#Fix monit
python2.7 /usr/local/lib/python2.7/transcirrus/operations/monit/fix_monit_conf.py cc

#put ovs-command in rc.local
ip link set eth6 promisc on
ip link set eth7 promisc on
ovs-vsctl add-br br-ex

#change glance
chmod 775 /var/lib/glance/images

#create promisc script
echo '#!/bin/bash' >> /transcirrus/promisc
echo 'ip link set eth6 promisc on' >> /transcirrus/promisc
echo 'ip link set eth7 promisc on' >> /transcirrus/promisc
echo 'ovs-vsctl add-bond br-ex bond2 eth6 eth7' >> /transcirrus/promisc
chmod 775 /transcirrus/promisc

echo 'mount -a' >> /etc/rc.local
echo 'source /transcirrus/promisc' >> /etc/rc.local
echo 'iptables-restore < /transcirrus/iptables.rules' >> /etc/rc.local
echo 'chmod 775 /var/lib/glance/images' >> /etc/rc.local
echo 'source /transcirrus/gluster-mounts' >> /etc/rc.local
echo 'source /transcirrus/gluster-object-mount' >> /etc/rc.local

#get rid of the raw SQL code
rm -rf /usr/local/lib/python2.7/transcirrus/SQL_files
rm -rf /usr/local/lib/python2.7/transcirrus/Coalesce

#compile the transcirrus code
#python2.7 /usr/local/lib/python2.7/transcirrus/compiler.py

#experiment - ceilometer
ln -s /usr/lib64/python2.6/site-packages/libvirt.py /usr/local/lib/python2.7/site-packages/libvirt.py
ln -s /usr/lib64/python2.6/site-packages/libvirtmod.so /usr/local/lib/python2.7/site-packages/libvirtmod.so

#cinder
mkdir -p /mnt/nfs-vols/cinder-volume
chown cinder:cinder /mnt/nfs-vols/cinder-volume

#turn off unneccessary services
chkconfig postfix off
chkconfig cups off
chkconfig ip6tables off
chkconfig iscsi off
chkconfig iscsid off
chkconfig lvm2-monitor off

#Manufacturing Data
#psql -h 192.168.10.16 -U postgres -d transcirrusinternal -c "INSERT INTO manufacturing VALUES('"${NODEID}"','cc',NULL,NULL,'"${HOSTNAME}"','true','icehouse',current_date,NULL);"

# add the shadow_admin linux user
useradd -d /home/shadow_admin -g transystem -s /bin/admin.sh shadow_admin

# set shadow_admin default password
echo -e 'manbehindthecurtain\nmanbehindthecurtain\n' | passwd shadow_admin

# set the shadow_admin account up in sudo
echo 'shadow_admin ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers

# add shadow_admin to groups
usermod -a -G nova shadow_admin
usermod -a -G cinder shadow_admin
usermod -a -G glance shadow_admin
usermod -a -G swift shadow_admin
usermod -a -G neutron shadow_admin
usermod -a -G keystone shadow_admin
usermod -a -G heat shadow_admin
usermod -a -G ceilometer shadow_admin
usermod -a -G postgres shadow_admin

# add the shadow_admin openstack user
SHADOW_ADMIN_USER=$(keystone user-create --name=shadow_admin --pass=manbehindthecurtain | grep " id " | get_field 2)

keystone user-role-add --user-id $SHADOW_ADMIN_USER \
                       --role-id $ADMIN_ROLE \
                       --tenant-id $TRANS_TENANT

# add shadow_admin to transcirrus db
psql -U postgres -d transcirrus -c "INSERT INTO trans_user_info VALUES (1, 'shadow_admin', 'admin', 0, 'TRUE', '"${SHADOW_ADMIN_USER}"', 'trans_default','"${TRANS_TENANT}"', 'admin', NULL);"

# Install python ldap lib "Offline"
if [ ! -f /usr/local/lib/python2.7/site-packages/ldap/__init__.py ]
then
    /usr/local/bin/pip2.7 install /usr/local/lib/python2.7/transcirrus/upgrade_resources/python-ldap-2.4.20.tar.gz
fi

# Write ldap_config.py
/bin/echo "Writing ldap_config.py..."
/bin/touch /usr/local/lib/python2.7/transcirrus/operations/third_party_auth/ldap/ldap_config.py
/bin/echo 'CONFIGURED=False' >> /usr/local/lib/python2.7/transcirrus/operations/third_party_auth/ldap/ldap_config.py
/bin/chmod 777 /usr/local/lib/python2.7/transcirrus/operations/third_party_auth/ldap/ldap_config.py

# Install flasgger package
/usr/local/bin/pip2.7 install flasgger

# aPersona unique email update
sudo service postgresql restart
/usr/bin/psql -U postgres -d transcirrus -c "ALTER TABLE ONLY trans_user_info ADD CONSTRAINT trans_user_info_user_email_key UNIQUE (user_email);"

# add aPersona
#yum install java-1.7.0-openjdk -y
#yum install tomcat6 -y
/sbin/service tomcat6 start
/sbin/chkconfig tomcat6 on
#yum install tomcat6-webapps -y
/sbin/service tomcat6 restart
/bin/rm -rf /var/lib/tomcat6/webapps/*
/bin/cp -r /usr/local/lib/python2.7/transcirrus/upgrade_resources/aPersona/ap* /var/lib/tomcat6/webapps/
/usr/bin/psql -U postgres -f /usr/local/lib/python2.7/transcirrus/upgrade_resources/aPersona/apersona_configured.sql
sed -i 's/8080/8090/g' /usr/share/tomcat6/conf/server.xml
/sbin/service tomcat6 restart

# Commands to setup our rest api daemon
/bin/cp /usr/local/lib/python2.7/transcirrus/daemons/transcirrus_api /etc/init.d
/bin/chmod 755 /etc/init.d/transcirrus_api
/bin/chmod 755 /usr/local/lib/python2.7/transcirrus/daemons/transcirrus_api
/bin/chown root:root /etc/init.d/transcirrus_api
/sbin/chkconfig --levels 235 transcirrus_api on
/sbin/chkconfig --add /etc/init.d/transcirrus_api
/sbin/service transcirrus_api restart

# Commands to build and install gmp which fixes some security issues
# which also requires pycrpto to be re-installed.
cwd=$(pwd)
cd /tmp
tar -xvjpf /usr/local/lib/python2.7/transcirrus/upgrade_resources/gmp-6.1.0.tar.bz2
cd gmp-6.1.0
./configure
make
make check
make install

/usr/local/bin/pip2.7 install --ignore-installed /usr/local/lib/python2.7/transcirrus/upgrade_resources/pycrypto-2.6.1.tar.gz
cd $cwd

#update the system
#yum update -y --skip-broken
yum downgrade -y python-websockify-0.5.1-1.el6.noarch

#fix monit
rpm -e monit-5.14-1.el6.x86_64
#rpm -ivh http://192.168.10.10/rhat_ic/common/monit-5.8.1-1.x86_64.rpm

# add email for shadow_admin
python2.7 -c "from transcirrus.common import extras; from transcirrus.component.keystone.keystone_users import user_ops; auth = extras.shadow_auth(); uo = user_ops(auth); uo.update_user({'username': 'shadow_admin', 'email': 'bugs@transcirrus.com'})"

# pycrypto / cryptography fix
pip install cryptography --force-reinstall
service httpd restart

#clean up roots home
rm -rf /root/*

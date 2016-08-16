#!/bin/bash

# The MIT License (MIT)
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#
#
# Install MariaDB Galera Cluster, by Julio Sene & Paulo Teixeira
#
# $1 - number of nodes; $2 - cluster name;
#
#
# Script location: https://raw.githubusercontent.com/pateixei/MoodleAzure/master/scripts/

NNODES=${1-1}
MYSQLPASSWORD=${2:-""}
USERPASSWORD=${4:-$MYSQLPASSWORD}
IPPREFIX=${3:-"172.18.2."}
DEBPASSWORD=${5:-`date +%D%A%B | md5sum| sha256sum | base64| fold -w16| head -n1`}
IPLIST=`echo ""`
MYIP=`ip route get ${IPPREFIX}70 | awk 'NR==1 {print $NF}'`
MYNAME=`echo "Node$MYIP" | sed 's/$IPPREFIX.1/-/'`
CNAME=${6:-"GaleraCluster"}
FIRSTNODE=`echo "${IPPREFIX}$(( $NNODES + 9 ))"`

for (( n=1; n<=$NNODES; n++ ))
do
   IPLIST+=`echo "${IPPREFIX}$(( $n + 9 ))"`
   if [ "$n" -lt $NNODES ];
   then
        IPLIST+=`echo ","`
   fi
done

apt-get update > /dev/null
apt-get install -f -y > /dev/null

apt-get install lsb-release bc > /dev/null
REL=`lsb_release -sc`
DISTRO=`lsb_release -is | tr [:upper:] [:lower:]`

apt-get install -y --fix-missing python-software-properties > /dev/null
apt-get install software-properties-common 
if [ "$REL" = "trusty" ];
then
sudo apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 0xcbcb082a1bb943db
sudo add-apt-repository 'deb http://mirror.edatel.net.co/mariadb/repo/10.1/ubuntu trusty main'
else
sudo apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 0xF1656F24C74CD1D8
sudo add-apt-repository 'deb http://mirror.edatel.net.co/mariadb/repo/10.1/ubuntu xenial main'
fi

apt-get update > /dev/null

echo "Installing MariaDB Custer for $NNODES on $DISTRO $REL ..."

DEBIAN_FRONTEND=noninteractive apt-get install -y rsync mariadb-server

echo "Configuring MariaDB Cluster"
# Remplace Debian maintenance config file

echo -e '# Automatically generated for Debian scripts. DO NOT TOUCH!
    [client]
    host     = localhost
    user     = debian-sys-maint
    password = '$DEBPASSWORD '
    socket   = /var/run/mysqld/mysqld.sock

    [mysql_upgrade]
    host     = localhost
    user     = debian-sys-maint
    password = '$DEBPASSWORD '
    socket   = /var/run/mysqld/mysqld.sock
    basedir  = /usr' > ~/debian.cnf 

mv ~/debian.cnf /etc/mysql/

mysql -u root <<EOF
CREATE DATABASE moodle;
GRANT ALL PRIVILEGES ON moodle.* TO 'moodledba'@'%'
IDENTIFIED BY '$USERPASSWORD';
FLUSH PRIVILEGES;

GRANT ALL PRIVILEGES on *.* TO 'debian-sys-maint'@'localhost' IDENTIFIED BY '$DEBPASSWORD' WITH GRANT OPTION;
SET PASSWORD FOR 'root'@'localhost' = PASSWORD('$MYSQLPASSWORD');
CREATE USER 'root'@'%' IDENTIFIED BY '$MYSQLPASSWORD';
GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION;
FLUSH PRIVILEGES;
EOF

# To create another MariaDB root user:
#CREATE USER '$MYSQLUSER'@'localhost' IDENTIFIED BY '$MYSQLUSERPASS';
#GRANT ALL PRIVILEGES ON *.* TO '$MYSQLUSER'@'localhost' WITH GRANT OPTION;
#CREATE USER '$MYSQLUSER'@'%' IDENTIFIED BY '$MYSQLUSERPASS';
#GRANT ALL PRIVILEGES ON *.* TO '$MYSQLUSER'@'%' WITH GRANT OPTION;

service mysql stop

# adjust my.cnf
# sed -i "s/#wsrep_on=ON/wsrep_on=ON/g" /etc/mysql/my.cnf

# create Galera config file

wget https://raw.githubusercontent.com/pateixei/azure-nginx-php-mariadb-cluster/master/files/cluster.cnf > /dev/null
echo -e '[mysqld]
#mysql settings
#wsrep_on=ON
binlog_format=ROW
default-storage-engine=innodb
innodb_autoinc_lock_mode=2
query_cache_size=0
query_cache_type=0
bind-address=0.0.0.0

#galera settings
wsrep_provider=/usr/lib/galera/libgalera_smm.so
wsrep_cluster_name="CLUSTERNAME"
wsrep_cluster_address="gcomm://IPLIST"
wsrep_sst_method=rsync

# Galera Node Configuration
wsrep_node_address="MYIP" 
wsrep_node_name="MYNAME"' > ~/cluster.cnf 

if [ "$FIRSTNODE" = "$MYIP" ];
then
   sed -i "s/#wsrep_on=ON/wsrep_on=ON/g;s/IPLIST//g;s/MYIP/$MYIP/g;s/MYNAME/$MYNAME/g;s/CLUSTERNAME/$CNAME/g" ~/cluster.cnf
else
   sed -i "s/#wsrep_on=ON/wsrep_on=ON/g;s/IPLIST/$IPLIST/g;s/MYIP/$MYIP/g;s/MYNAME/$MYNAME/g;s/CLUSTERNAME/$CNAME/g" ~/cluster.cnf
fi

mv ~/cluster.cnf /etc/mysql/conf.d/

# Create the raid disk 
wget https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/shared_scripts/ubuntu/vm-disk-utils-0.1.sh
bash vm-disk-utils-0.1.sh -s
mkdir /datadisks/disk1/data
cp -R -p /var/lib/mysql /datadisks/disk1/data/
sed -i "s,/var/lib/mysql,/datadisks/disk1/data/mysql,g" /etc/mysql/my.cnf

# Starts a cluster if is the first node
if [ "$FIRSTNODE" = "$MYIP" ];
then
    service mysql start --wsrep-new-cluster > /dev/null
    sed -i "s;gcomm://;gcomm://$IPLIST;g" /etc/mysql/conf.d/cluster.cnf
else
    service mysql start > /dev/null
fi

echo "MariaDB Cluster instalation finished"

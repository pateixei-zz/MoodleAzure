# Custom Script for Linux

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

glusterNode=$2
glusterVolume=$3 

# install pre-requisites
apt-get -y install python-software-properties

#configure gluster repository & install gluster client
add-apt-repository ppa:gluster/glusterfs-3.7 -y
apt-get -y update
apt-get -y install glusterfs-client mysql-client git 

# install the LAMP stack
apt-get -y install apache2 php5

# install moodle requirements
apt-get -y install graphviz aspell php5-pspell php5-curl php5-gd php5-intl php5-mysql php5-xmlrpc php5-ldap

# create gluster mount point
mkdir -p /moodle
 
# mount gluster files system
mount -t glusterfs $glusterNode:/$glusterVolume /moodle

# make the moodle directory writable for owner
chown www-data moodle
chmod 770 moodle

# create moodledata directory
mkdir /moodle/moodledata
chown www-data /moodle/moodledata
chmod 770 /moodle/moodledata

# updapte Apache configuration
cp /etc/apache2/apache2.conf apache2.conf.bak
sed -i 's/\/var\/www/\/\moodle/g' /etc/apache2/apache2.conf
echo ServerName \"localhost\"  >> /etc/apache2/apache2.conf

#update virtual site configuration 
sed -i 's/\/var\/www\/html/\/\moodle\/html\/moodle/g' /etc/apache2/sites-enabled/000-default.conf

# restart Apache
service apache2 restart 


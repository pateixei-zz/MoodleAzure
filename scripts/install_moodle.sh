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

#parameters 

moodleVersion=$1
glusterNode=$2
glusterVolume=$3 

# create gluster mount point
mkdir -p /moodle

#configure gluster repository & install gluster client
add-apt-repository ppa:gluster/glusterfs-3.7 -y
apt-get -y update
apt-get -y install glusterfs-client mysql-client git 

# mount gluster files system
echo 'Installing GlusterFS on '$glusterNode':/'$glusterVolume '/moodle' 
mount -t glusterfs $glusterNode:/$glusterVolume /moodle

#create html directory for storing moodle files
mkdir /moodle/html
# install pre-requisites
apt-get install -y --fix-missing python-software-properties unzip

# install the LAMP stack
apt-get install -y apache2 mysql-client php5

# install moodle requirements
apt-get install -y --fix-missing graphviz aspell php5-pspell php5-curl php5-gd php5-intl php5-mysql php5-xmlrpc php5-ldap


# install Moodle 
echo '#!/bin/bash
mkdir /moodle/html
cd /tmp

# downloading moodle 
curl -k --max-redirs 10 https://github.com/moodle/moodle/archive/'$moodleVersion'.zip -L -o moodle.zip
unzip moodle.zip
mv moodle-'$moodleVersion' /moodle/html/moodle

# make the moodle directory writable for owner
chown -R www-data /moodle/html/moodle
chmod -R 770 /moodle/html/moodle

# install Office 365 plugins
#if [ "$installOfficePlugins" = "True" ]; then
        curl -k --max-redirs 10 https://github.com/Microsoft/o365-moodle/archive/'$moodleVersion'.zip -L -o o365.zip
        unzip o365.zip
        cp -r o365-moodle-'$moodleVersion'/* /moodle/html/moodle
        rm -rf o365-moodle-'$moodleVersion'
#fi
# create moodledata directory
mkdir /moodle/moodledata
chown -R www-data /moodle/moodledata
chmod -R 770 /moodle/moodledata
' > /tmp/setup-moodle.sh 
chmod +x /tmp/setup-moodle.sh
/tmp/setup-moodle.sh 


# create cron entry
# It is scheduled for once per day. It can be changed as needed.
echo '0 0 * * * php /moodle/html/moodle/admin/cli/cron.php > /dev/null 2>&1' > cronjob
crontab cronjob

# updapte Apache configuration
cp /etc/apache2/apache2.conf apache2.conf.bak
sed -i 's/\/var\/www/\/\moodle/g' /etc/apache2/apache2.conf
echo ServerName \"localhost\"  >> /etc/apache2/apache2.conf

#update virtual site configuration 
sed -i 's/\/var\/www\/html/\/\moodle\/html\/moodle/g' /etc/apache2/sites-enabled/000-default.conf

# restart Apache
service apache2 restart 


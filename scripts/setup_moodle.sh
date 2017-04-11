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

glusterNode=$1
glusterVolume=$2 


echo $glusterNode    >> /tmp/vars.txt
echo $glusterVolume  >> /tmp/vars.txt

{

# install pre-requisites
sudo apt-get -y install python-software-properties

#configure gluster repository & install gluster client
sudo add-apt-repository -y ppa:gluster/glusterfs-3.8
sudo add-apt-repository -y ppa:ondrej/php

sudo apt-get -y update
sudo apt-get -y --force-yes install glusterfs-client mysql-client git 

# install the LAMP stack
sudo apt-get -y --force-yes install apache2 php5.6 

# install moodle requirements
# sudo apt-get -y install graphviz aspell php5.6-curl php5.6-zip php5.6-pspell php5.6-curl php5.6-gd php5.6-intl php5.6-mysql php5.6-xmlrpc php5.6-ldap php5.6-redis
sudo apt-get install -y --force-yes graphviz aspell php5.6-common php5.6-soap php5.6-json php5.6-zip php5.6-bcmath php5.6-gd php5.6-mysql php5.6-xmlrpc php5.6-intl php5.6-xml php5.6-bz2 php5.6-redis php5.6-curl 

# create gluster mount point
sudo mkdir -p /moodle

# make the moodle directory writable for owner
sudo chown www-data /moodle
sudo chmod 770 /moodle
 
# mount gluster files system
sudo echo -e 'mount -t glusterfs '$glusterNode':/'$glusterVolume' /moodle' > /tmp/mount.log 
#sudo mount -t glusterfs $glusterNode:/$glusterVolume /moodle
sudo echo -e $glusterNode':/'$glusterVolume'   /moodle         glusterfs       defaults,_netdev,log-level=WARNING,log-file=/var/log/gluster.log 0 0' >> /etc/fstab
sudo mount -a
# updapte Apache configuration
sudo cp /etc/apache2/apache2.conf /etc/apache2/apache2.conf.bak
sudo sed -i 's/\/var\/www/\/\moodle/g' /etc/apache2/apache2.conf
sudo echo ServerName \"localhost\"  >> /etc/apache2/apache2.conf

#enable ssl 
sudo a2enmod rewrite ssl

#update virtual site configuration 
echo -e '
<VirtualHost *:80>
        #ServerName www.example.com
        ServerAdmin webmaster@localhost
        DocumentRoot /moodle/html/moodle
        #LogLevel info ssl:warn
        ErrorLog ${APACHE_LOG_DIR}/error.log
        CustomLog ${APACHE_LOG_DIR}/access.log combined
        #Include conf-available/serve-cgi-bin.conf
</VirtualHost>
<VirtualHost *:443>
        DocumentRoot /moodle/html/moodle
        ErrorLog ${APACHE_LOG_DIR}/error.log
        CustomLog ${APACHE_LOG_DIR}/access.log combined

        SSLEngine on
        SSLCertificateFile /moodle/certs/apache.crt
        SSLCertificateKeyFile /moodle/certs/apache.key

        BrowserMatch "MSIE [2-6]" \
                        nokeepalive ssl-unclean-shutdown \
                        downgrade-1.0 force-response-1.0
        BrowserMatch "MSIE [17-9]" ssl-unclean-shutdown

</VirtualHost>' > /etc/apache2/sites-enabled/000-default.conf

# php config 
PhpIni=/etc/php/5/apache2/php.ini
sed -i "s/memory_limit.*/memory_limit = 512M/" $PhpIni
sed -i "s/;opcache.use_cwd.*1/opcache.use_cwd = 1/" $PhpIni
sed -i "s/;opcache.validate_timestamps.*/opcache.validate_timestamps = 1/" $PhpIni
sed -i "s/;opcache.save_comments.*/opcache.save_comments = 1/" $PhpIni
sed -i "s/;opcache.enable_file_override.*/opcache.enable_file_override = 0/" $PhpIni
sed -i "s/;opcache.enable.*/opcache.enable = 1/" $PhpIni
sed -i "s/;opcache.memory_consumption.*/opcache.memory_consumption = 256/" $PhpIni
sed -i "s/;opcache.max_accelerated_files.*/opcache.max_accelerated_files = 8000/" $PhpIni

# restart Apache
sudo service apache2 restart 

}  > /tmp/setup.log
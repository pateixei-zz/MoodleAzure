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

# install pre-requisites
apt-get -y install python-software-properties

#configure gluster repository & install gluster client
add-apt-repository ppa:gluster/glusterfs-3.7 -y
apt-get -y update
apt-get -y --force-yes install glusterfs-client mysql-client git 


# install the LAMP stack
apt-get -y install apache2 php5

# install moodle requirements
apt-get -y install graphviz aspell php5-pspell php5-curl php5-gd php5-intl php5-mysql php5-xmlrpc php5-ldap php5-redis

# create gluster mount point
mkdir -p /moodle

# make the moodle directory writable for owner
chown www-data moodle
chmod 770 moodle
 
# mount gluster files system
echo -e 'mount -t glusterfs '$glusterNode':/'$glusterVolume' /moodle' > /tmp/mount.log 
mount -t glusterfs $glusterNode:/$glusterVolume /moodle

# updapte Apache configuration
cp /etc/apache2/apache2.conf /etc/apache2/apache2.conf.bak
sed -i 's/\/var\/www/\/\moodle/g' /etc/apache2/apache2.conf
echo ServerName \"localhost\"  >> /etc/apache2/apache2.conf

#enable ssl 
a2enmod rewrite ssl

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
PhpIni=/etc/php5/apache2/php.ini
sed -i "s/memory_limit.*/memory_limit = 512M/" $PhpIni
sed -i "s/;opcache.use_cwd = 1/opcache.use_cwd = 1/" $PhpIni
sed -i "s/;opcache.validate_timestamps = 1/opcache.validate_timestamps = 1/" $PhpIni
sed -i "s/;opcache.save_comments = 1/opcache.save_comments = 1/" $PhpIni
sed -i "s/;opcache.enable_file_override = 0/opcache.enable_file_override = 0/" $PhpIni
sed -i "s/;opcache.enable = 0/opcache.enable = 1/" $PhpIni
sed -i "s/;opcache.memory_consumption.*/opcache.memory_consumption = 256/" $PhpIni
sed -i "s/;opcache.max_accelerated_files.*/opcache.max_accelerated_files = 8000/" $PhpIni

# restart Apache
service apache2 restart 


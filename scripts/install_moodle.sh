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


function install_gluster
{
        #configure gluster repository & install gluster client
        add-apt-repository ppa:gluster/glusterfs-3.7 -y
        apt-get -y update
        apt-get -y install glusterfs-client mysql-client git 

        # create gluster mount point
        mkdir -p /moodle
        
        # mount gluster files system
        mount -t glusterfs $glusterNode:/$glusterVolume /moodle

        #create html directory for storing moodle files
        mkdir /moodle/html
    
}


#parameters 

moodleVersion=$1
glusterNode=$2
glusterVolume=$3 

cd ~

install_gluster

apt-get update > /dev/null
apt-get install -f -y > /dev/null

# install pre-requisites
apt-get install -y --fix-missing python-software-properties unzip

# install the LAMP stack
apt-get install -y apache2 mysql-client php5

# install moodle requirements
apt-get install -y --fix-missing graphviz aspell php5-pspell php5-curl php5-gd php5-intl php5-mysql php5-xmlrpc php5-ldap

# install Moodle
cd /moodle/html
curl -k --max-redirs 10 https://github.com/moodle/moodle/archive/$moodleVersion.zip -L -o moodle.zip
unzip moodle.zip
mv moodle-$moodleVersion moodle

# install Office 365 plugins

#if [ "$installOfficePlugins" = "True" ]; then
cd ~
curl -k --max-redirs 10 https://github.com/Microsoft/o365-moodle/archive/$moodleVersion.zip -L -o o365.zip
unzip o365.zip
cp -r o365-moodle-$moodleVersion/* /moodle/html/moodle
rm -rf o365-moodle-$moodleVersion
#fi

# make the moodle directory writable for owner
chown -R www-data moodle
chmod -R 770 moodle

# create moodledata directory
mkdir /moodle/moodledata
chown -R www-data /moodle/moodledata
chmod -R 770 /moodle/moodledata

# create cron entry
# It is scheduled for once per day. It can be changed as needed.
echo '0 0 * * * php /moodle/html/moodle/admin/cli/cron.php > /dev/null 2>&1' > cronjob
crontab cronjob

# updapte Apache configuration
cp /etc/apache2/apache2.conf apache2.conf.bak
sed -i 's/\/var\/www/\/\moodle/g' /etc/apache2/apache2.conf

#update virtual site configuration 
sed -i 's/\/var\/www\/html/\/\moodle\/html\/moodle/g' /etc/apache2/sites.enabled/000-default.conf

# restart Apache
service apache2 restart 

function install_nginx
{
        apt-get update
        apt-get -fy dist-upgrade
        apt-get -fy upgrade
        apt-get install lsb-release bc

        REL=`lsb_release -sc`
        DISTRO=`lsb_release -is | tr [:upper:] [:lower:]`
        NCORES=` cat /proc/cpuinfo | grep cores | wc -l`
        WORKER=`bc -l <<< "4*$NCORES"`

        wget http://nginx.org/keys/nginx_signing.key
        echo "deb http://nginx.org/packages/$DISTRO/ $REL nginx" >> /etc/apt/sources.list
        echo "deb-src http://nginx.org/packages/$DISTRO/ $REL nginx" >> /etc/apt/sources.list

        apt-key add nginx_signing.key
        apt-get update
        apt-get install -fy nginx
        apt-get install -fy php5-fpm php5-cli php5-mysql
        apt-get install -fy php-apc php5-gd

        # replace www-data to nginx into /etc/php5/fpm/pool.d/www.conf
        sed -i 's/www-data/nginx/g' /etc/php5/fpm/pool.d/www.conf
        service php5-fpm restart

        # backup default Nginx configuration
        mkdir /etc/nginx/conf-bkp
        cp /etc/nginx/conf.d/default.conf /etc/nginx/conf-bkp/default.conf
        cp /etc/nginx/nginx.conf /etc/nginx/nginx-conf.old

        #
        # Replace nginx.conf
        #
        echo -e "user nginx www-data;\nworker_processes $WORKER;" > /etc/nginx/nginx.conf
        echo -e 'pid /var/run/nginx.pid;

        events {
                worker_connections 768;
                # multi_accept on;
        }

        http {
        # Basic Settings
                sendfile on;
                tcp_nopush on;
                tcp_nodelay on;
                keepalive_timeout 5;
                types_hash_max_size 2048;
                # server_tokens off;

                # server_names_hash_bucket_size 64;
                # server_name_in_redirect off;

                include /etc/nginx/mime.types;
                default_type application/octet-stream;

        # Logging Settings
        log_format gzip '$remote_addr - $remote_user [$time_local]  '
                        '"$request" $status $bytes_sent '
                        '"$http_referer" "$http_user_agent" "$gzip_ratio"';

                access_log /var/log/nginx/access.log gzip buffer=32k;
                error_log /var/log/nginx/error.log notice;

        # Gzip Settings
                gzip on;
                gzip_disable "msie6";

                gzip_vary on;
                gzip_proxied any;
                gzip_comp_level 6;
                gzip_buffers 16 8k;
                gzip_http_version 1.1;
                gzip_types text/plain text/css application/json application/x-javascript text/xml application/xml application/xml+rss t
        ext/javascript;

        # Virtual Host Configs
                include /etc/nginx/conf.d/*.conf;
                include /etc/nginx/sites-enabled/*;

        }' >> /etc/nginx/nginx.conf

        # replace Nginx default.conf
        #

        echo -e '# Upstream to abstract backend connection(s) for php
        upstream php {
            server unix:/var/run/php5-fpm.sock;
        #        server unix:/tmp/php-cgi.socket;
        #        server 127.0.0.1:9000;
        }
        
        server {
                listen       80;

                #charset koi8-r;
                #access_log  /var/log/nginx/log/host.access.log  main;
                ## Your website name goes here.

                server_name localhost;

                ## Your only path reference.
                root /moodle/html;

                ## This should be in your http block and if it is, it`s not needed here.
                index index.htm index.html index.php;
                gzip on;
                gzip_types text/css text/x-component application/x-javascript application/javascript text/javascript text/x-js text/richtext image/svg+xml text/plain text/xsd text/xsl text/xml image/x-icon;

                location = /favicon.ico {
                        log_not_found off;
                        access_log off;
                }
        
                location = /robots.txt {
                        allow all;
                        log_not_found off;
                        access_log off;
                }
        
                location / {
                        # This is cool because no php is touched for static content. 
                        # include the "?$args" part so non-default permalinks doesn`t break when using query string
                        try_files $uri $uri/ /index.php?$args;
                }
                location ~ \.php$ {
                    #NOTE: You should have "cgi.fix_pathinfo = 0;" in php.ini
                    
                    # root           html;
                    # fastcgi_pass   127.0.0.1:9000;

                    fastcgi_index  index.php;
                    fastcgi_param  SCRIPT_FILENAME  /scripts$fastcgi_script_name;
                    include        fastcgi_params;
                    
                    # include fastcgi.conf;
                    fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
                    fastcgi_intercept_errors on;
                    fastcgi_pass php;
                }
            location ~ \.(ttf|ttc|otf|eot|woff|font.css)$ {
                add_header Access-Control-Allow-Origin "*";
            }
                location ~* \.(js|css|png|jpg|jpeg|gif|ico)$ {
                        expires max;
                        log_not_found off;
                }
        }' > /etc/nginx/conf.d/default.conf

        service php5-fpm restart
        service nginx restart    
}

#!/bin/bash
# Install Nginx + php-fpm + apc cache for Ubuntu and Debian distributions
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
    	listen       8080;

    	#charset koi8-r;
    	#access_log  /var/log/nginx/log/host.access.log  main;
        ## Your website name goes here.

        server_name localhost;

        ## Your only path reference.
        root /usr/share/nginx/html;

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

#
# Edit default page to show php info
#
# mv /usr/share/nginx/html/index.html /usr/share/nginx/html/index.php
# echo -e "\n<?php\nphpinfo();\n?>" >> /usr/share/nginx/html/index.php
#
# Services restart
#
service php5-fpm restart
service nginx restart
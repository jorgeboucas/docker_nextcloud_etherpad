FROM ubuntu

LABEL maintainer "jboucas@gmail.com"

# for generating strong passwords follow the instructions here:
# https://www.rosehosting.com/blog/generate-password-linux-command-line/

##### USER GIVEN VARIABLES #####

# root password
ENV ROOTPASS=my_root_pass

# password for mysql
ENV myqsl_password=sqpass

# user and password for the database used by nextcloud
ENV MAINDB=nextcloud
ENV PASSWDDB=ncdbpass

# user and password for the nextcloud administrator
ENV ADMIN=nextcloud
ENV ADMINPASS=ncpass

# server info for ssl certificates
ENV SERVER_ADDRESS=nextcloud.myhostname.com
ENV SERVER_ADMIN="my.email@email.com"

# company info for hacking the nextcloud's landing page
ENV COMPANY_NAME=company_name
ENV COMPANY_WEBPAGE='http:\/\/www.company.com'
ENV COMPANY_SLOGAN='My Company Slogan'

# internal host ip for trusted hosts
ENV HOST_INTERNAL_IP=pi_ip_on_my_network

# user and password for the database used by etherpad
ENV ETHERPAD_MYSQL_USER=ETHERPAD_MYSQL_USER
ENV ETHERPAD_MYSQL_PASS=ETHERPAD_MYSQL_PASS

# user and password for the etherpad administrator
ENV ETHERPAD_ADMIN=ETHERPAD_ADMIN
ENV ETHERPAD_ADMIN_PASS=ETHERPAD_ADMIN_PASS

# etherpad address, ip bind,  and port
ENV ETHERPAD_WEB_ADDRESS=etherpad.myhostname.com

##### END OF USER GIVEN VARIABLES #####

ENV ETHERPAD_IP_BIND=0.0.0.0
ENV ETHERPAD_PORT=9001

# do not change the initial mysql_user from root
ENV mysql_user=root

USER root

ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update

RUN apt-get install -y apache2 systemd && \
sed -i "s/Options Indexes FollowSymLinks/Options FollowSymLinks/" /etc/apache2/apache2.conf && \
echo "ServerName localhost" >> /etc/apache2/apache2.conf && \
service apache2 start

RUN apt-get install -y mariadb-server mariadb-client 

COPY mysql_secure_installation.sh /tmp/mysql_secure_installation.sh

RUN /bin/bash -c 'service mysql start && \
chmod +x /tmp/mysql_secure_installation.sh && \
/tmp/mysql_secure_installation.sh && \
rm -rf /tmp/mysql_secure_installation.sh'

RUN apt-get install -y software-properties-common

RUN add-apt-repository ppa:ondrej/php

RUN apt-get update

RUN apt-get install -y php7.1 libapache2-mod-php7.1 php7.1-common \
libapache2-mod-php7.1 php7.1-mbstring php7.1-xmlrpc php7.1-soap \
php7.1-apcu php7.1-smbclient php7.1-ldap php7.1-redis php7.1-gd \
php7.1-xml php7.1-intl php7.1-json php7.1-imagick php7.1-mysql \
php7.1-cli php7.1-mcrypt php7.1-ldap php7.1-zip php7.1-curl

RUN sed -i 's/memory_limit = 128M/memory_limit = 256M/g' /etc/php/7.1/apache2/php.ini && \
sed -i 's/upload_max_filesize = 2M/upload_max_filesize = 64M/g' /etc/php/7.1/apache2/php.ini && \
sed -i 's/max_execution_time = 30/max_execution_time = 360/g' /etc/php/7.1/apache2/php.ini && \
sed -i 's/;date.timezone =/date.timezone = America\/Chicago/g' /etc/php/7.1/apache2/php.ini

COPY create.mysql.db.sh  /tmp/create.mysql.db.sh 

RUN /bin/bash -c 'service mysql start && \
chmod +x /tmp/create.mysql.db.sh && \
/tmp/create.mysql.db.sh && \
rm /tmp/create.mysql.db.sh'

RUN apt-get install -y wget && \
cd tmp && \
wget https://download.nextcloud.com/server/releases/nextcloud-15.0.4.tar.bz2 && \
tar jxvf nextcloud-15.0.4.tar.bz2 && \
mv nextcloud/* /var/www/html/ && \
chown -R www-data:www-data /var/www/html && \
chmod -R 755 /var/www/html

COPY http.nextcloud.conf /etc/apache2/sites-available/nextcloud.conf
COPY http.nextcloud.ssl.conf /etc/apache2/sites-available/nextcloud.ssl.conf

RUN sed -i 's/SERVER_ADDRESS/'"${SERVER_ADDRESS}"'/g' /etc/apache2/sites-available/nextcloud.conf && \ 
sed -i 's/SERVER_ADMIN/'"${SERVER_ADMIN}"'/g' /etc/apache2/sites-available/nextcloud.conf

RUN sed -i 's/SERVER_ADDRESS/'"${SERVER_ADDRESS}"'/g' /etc/apache2/sites-available/nextcloud.ssl.conf && \
sed -i 's/SERVER_ADMIN/'"${SERVER_ADMIN}"'/g' /etc/apache2/sites-available/nextcloud.ssl.conf

RUN /bin/bash -c 'a2ensite nextcloud.conf && \
a2enmod rewrite && \
a2enmod headers && \
a2enmod env && \
a2enmod dir && \
a2enmod mime && \
a2enmod proxy  && \
a2enmod proxy_http && \
a2enmod proxy_wstunnel && \
a2enmod deflate && \
a2enmod ssl && \
service apache2 start'

RUN apt-get install -y vim sudo

RUN /bin/bash -c 'service mysql restart && service apache2 start && \
cd /var/www/html && \
sudo -u www-data php occ  maintenance:install --database "mysql" \
--database-name "${MAINDB}"  --database-user "${MAINDB}" \
--database-pass "${PASSWDDB}" --admin-user "${ADMIN}" --admin-pass "${ADMINPASS}" && \
sudo -u www-data php occ app:install spreed'

RUN apt-get install -y python-certbot-apache ssl-cert-check

RUN echo "0 1 * * * /usr/bin/certbot renew & > /dev/null" | crontab

RUN sed -i "s/0 => 'localhost',/0 => 'localhost', 1 => '"${SERVER_ADDRESS}"', 2 => '"${HOST_INTERNAL_IP}"',/g" /var/www/html/config/config.php 

RUN sed -i "s/= 'Nextcloud';/= '""${COMPANY_NAME}""';/g" /var/www/html/lib/private/legacy/defaults.php && \
sed -i "s/= 'https:\/\/nextcloud.com';/= '""${COMPANY_WEBPAGE}""';/g" /var/www/html/lib/private/legacy/defaults.php && \
sed -i "s/'a safe home for all your data'/'""${COMPANY_SLOGAN}""'/g" /var/www/html/lib/private/legacy/defaults.php

RUN mkdir -p /etc/letsencrypt

RUN echo "root:${ROOTPASS}" | chpasswd

## etherpad installation starts here

RUN apt-get install -y curl git

RUN curl -sL https://deb.nodesource.com/setup_9.x | sudo -E bash -

RUN apt-get install nodejs
# gcc g++ make
RUN npm i npm@latest -g

ENV NODE_ENV=production

COPY create.mysql.db.etherpad.sh /tmp/

RUN /bin/bash -c 'service mysql start && \
chmod +x /tmp/create.mysql.db.etherpad.sh && \
/tmp/create.mysql.db.etherpad.sh && \
rm -rf /tmp/create.mysql.db.etherpad.sh'

RUN git clone --branch master git://github.com/ether/etherpad-lite.git

COPY settings.json.template /etherpad-lite/settings.json.template

RUN sed -i 's/ETHERPAD_MYSQL_USER/'"${ETHERPAD_MYSQL_USER}"'/g' /etherpad-lite/settings.json.template && \
sed -i 's/ETHERPAD_MYSQL_PASS/'"${ETHERPAD_MYSQL_PASS}"'/g' /etherpad-lite/settings.json.template && \
sed -i 's/ETHERPAD_ADMIN/'"${ETHERPAD_ADMIN}"'/g' /etherpad-lite/settings.json.template && \
sed -i 's/ETHERPAD_ADMIN_PASS/'"${ETHERPAD_ADMIN_PASS}"'/g' /etherpad-lite/settings.json.template && \
sed -i 's/ETHERPAD_IP_BIND/'"${ETHERPAD_IP_BIND}"'/g' /etherpad-lite/settings.json.template && \
sed -i 's/ETHERPAD_PORT/'"${ETHERPAD_PORT}"'/g' /etherpad-lite/settings.json.template

RUN sudo apt-get install -y rsync binutils

RUN cd /etherpad-lite && \
bin/installDeps.sh && \
cd /etherpad-lite/node_modules && \
npm i ep_mypads && \
npm i ep_adminpads
# homepage is available at http://localhost:9001/mypads/index.html
# admin page http://localhost:9001/mypads/?/admin

COPY etherpad.conf /etc/apache2/sites-available/etherpad.conf
COPY etherpad.ssl.conf /etc/apache2/sites-available/etherpad.ssl.conf

RUN sed -i 's/ETHERPAD_WEB_ADDRESS/'"${ETHERPAD_WEB_ADDRESS}"'/g' /etc/apache2/sites-available/etherpad.conf && \ 
sed -i 's/ETHERPAD_PORT/'"${ETHERPAD_PORT}"'/g' /etc/apache2/sites-available/etherpad.conf

RUN sed -i 's/ETHERPAD_WEB_ADDRESS/'"${ETHERPAD_WEB_ADDRESS}"'/g' /etc/apache2/sites-available/etherpad.ssl.conf && \ 
sed -i 's/ETHERPAD_PORT/'"${ETHERPAD_PORT}"'/g' /etc/apache2/sites-available/etherpad.ssl.conf 

RUN /bin/bash -c 'service mysql restart && service apache2 start && \
a2dissite 000-default.conf && \
a2ensite etherpad.conf && service apache2 reload && service apache2 restart'

ENV PERSISTENT_DATA="/var/www/html /var/lib/mysql /etc/letsencrypt /etherpad-lite"

RUN for f in ${PERSISTENT_DATA} ; \
do mkdir ${f}_ ; for c in $(ls ${f}); do mv ${f}/${c} ${f}_/ ; done ; \
done

# entrypoint with http
#ENTRYPOINT for f in ${PERSISTENT_DATA} ; \
#do for c in $(ls ${f}_ ); \
#do if [ ! -e ${f}/${c} ] ; then mv ${f}_/${c} ${f}/ ; fi ; \
#done ; \
#done && \
#service mysql start && service apache2 start && \
#cd /etherpad-lite && \
#node node_modules/ep_etherpad-lite/node/server.js

# entrypoint without with https over certbot
ENTRYPOINT for f in ${PERSISTENT_DATA} ; \
do for c in $(ls ${f}_ ); \
do if [ ! -e ${f}/${c} ] ; then mv ${f}_/${c} ${f}/ ; fi ; \
done ; \
done && \
service mysql restart && service apache2 start && \ 
if [ ! -e /etc/letsencrypt/live/${SERVER_ADDRESS}/fullchain.pem ] ; \
then certbot --apache --non-interactive --agree-tos -m ${SERVER_ADMIN} -d ${SERVER_ADDRESS} ; a2dissite nextcloud-le-ssl.conf ; \
elif [ "$(ssl-cert-check -b -c /etc/letsencrypt/live/${SERVER_ADDRESS}/cert.pem | awk '{ print $2 }')" != "Valid" ] ; then certbot renew ; \
fi && \
a2dissite nextcloud.conf && a2ensite nextcloud.ssl.conf && \
if [ ! -e /etc/letsencrypt/live/${ETHERPAD_WEB_ADDRESS}/fullchain.pem ] ; \
then certbot --apache --non-interactive --agree-tos -m ${SERVER_ADMIN} -d ${ETHERPAD_WEB_ADDRESS} ; a2dissite etherpad-le-ssl.conf ; \
elif [ "$(ssl-cert-check -b -c /etc/letsencrypt/live/${ETHERPAD_WEB_ADDRESS}/cert.pem | awk '{ print $2 }')" != "Valid" ] ; then certbot renew ; \
fi && \
a2dissite etherpad.conf && a2ensite etherpad.ssl.conf && \
service apache2 reload && service apache2 restart && \
cd /etherpad-lite && \
node node_modules/ep_etherpad-lite/node/server.js

## usage
# docker stop cloud ; docker rm cloud
# docker build -t webserver . && \
# mkdir -p persistent_data/letsencrypt persistent_data/nextcloud persistent_data/db persistent_data/etherpad && \
# docker run \
# -v $(pwd)/persistent_data/letsencrypt:/etc/letsencrypt \
# -v $(pwd)/persistent_data/nextcloud:/var/www/html \
# -v $(pwd)/persistent_data/db:/var/lib/mysql \
# -v $(pwd)/persistent_data/etherpad:/etherpad-lite \
# --name cloud -d -p 80:80 -p 443:443 -p 9001:9001 webserver
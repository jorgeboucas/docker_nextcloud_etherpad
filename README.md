## Nextcloud with WebRTC and etherpad with private and group pads 

The `Dockerfile` used here starts with `FROM ubuntu` which means that by each build you run you will be starting from the latest ubuntu image available on Docker. It also means you can use this `Dockerfile` to build this image for diferent architectures eg. x86_64 (Mac); ARM (Rasbperry Pi).

As we will be generating ssl certificates with a Certificate Authority you will need to make sure
 your raspberry pi is accessible to the world. For this you will need to make sure your router is 
**forwarding ports 80 (http) and 443 (https)** to your raspberry pi. For instructions of how to do this consult your router's manual. 

Also, as you might not have a fixed IP you might wanna create a public *Hostname* with a *Free Dynamic DNS*. A good place for this is [noip.com](https://www.noip.com) for which you can install the *Dynamic Update Client (DUC)* so that your web address continuously points to your router's external IP address. You will need 2 hostnames, 1 for Nextcloud, 1 for etherpad.

To test that this is working you can have your router forward port 22 to your raspberry pi 
and try to ssh to your pi over the *Hostname* you created at noip.com. For safety reasons you might stop this forwarding once your test comes through.

Clone the repo:
```
cd ~/
git clone https://github.com/jorgeboucas/docker_nextcloud_etherpad.git
```
Edit the variables in the `Dockerfile` between `##### USER GIVEN VARIABLES #####` and `##### END OF USER GIVEN VARIABLES #####`. You might wanna check this [blog post](https://www.rosehosting.com/blog/generate-password-linux-command-line/) for help on choosing passwords.
```
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
```
Build the image and run the container:
```
cd ~/docker_nextcloud_etherpad
docker built -t webserver .
```
Run the container mapping the certificates `/etc/letsencrypt`, nextcloud `/var/www/html`, 
databases `var/lib/mysql`, and etherpad `/etherpad-lite` folders to your host. If you wish to create backups of your Nextcloud and etherpad instances these are the folders you need to copy/backup to a separate/3rd drive. If you ever restart your raspberry pi you can relaunch your instances by starting here:
```
cd ~/docker_nextcloud_etherpad
mkdir -p persistent_data/letsencrypt \
persistent_data/nextcloud \
persistent_data/db \
persistent_data/etherpad && \
docker run \
-v $(pwd)/persistent_data/letsencrypt:/etc/letsencrypt \
-v $(pwd)/persistent_data/nextcloud:/var/www/html \
-v $(pwd)/persistent_data/db:/var/lib/mysql \
-v $(pwd)/persistent_data/etherpad:/etherpad-lite \
--name cloud -d -p 80:80 -p 443:443 -p 9001:9001 webserver /bin/bash
```
If you wish to get a shell on the running container you can do so by 
```
docker exec -it cloud /bin/bash
```
You can now access your Nextcloud instance at your defined hostname `nextcloud.myhostname.com` and etherpad at your defined `etherpad.myhostname.com`. 

For login in to Nextcloud you can use the values you've set for `ADMIN` and  `ADMINPASS`. You can add users to yout Nextcloud instace by using the managment console inside Nexcloud. 

For *WebRTC* you can use the *Talk* app inside Nextcloud.

For login to etherpad you can use the values you've set to `ETHERPAD_ADMIN` and `ETHERPAD_ADMIN_PASS`. For private pads you can access `etherpad.myhostname.com/mypads` which you 
can administrate on `etherpad.myhostname.com/mypads/?/admin`.
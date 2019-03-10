#!/bin/bash
docker stop cloud ; docker rm cloud
docker build -t webserver . && \
mkdir -p persistent_data/letsencrypt persistent_data/nextcloud persistent_data/db persistent_data/etherpad && \
docker run \
-v $(pwd)/persistent_data/letsencrypt:/etc/letsencrypt \
-v $(pwd)/persistent_data/nextcloud:/var/www/html \
-v $(pwd)/persistent_data/db:/var/lib/mysql \
-v $(pwd)/persistent_data/etherpad:/etherpad-lite \
--name cloud -d -p 80:80 -p 443:443 -p 9001:9001 webserver /bin/bash
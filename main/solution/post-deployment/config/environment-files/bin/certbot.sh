#!/bin/bash

set -e

# Install certbot, request a certificate, and update nginx
# configuration to point to the newly issued cert

amazon-linux-extras install -y epel
yum -y install certbot certbot-dns-route53
systemctl enable certbot-renew.timer
systemctl start certbot-renew.timer

PUBLIC_HOSTNAME=$(cat /etc/public-hostname)
if [[ -n ${PUBLIC_HOSTNAME} ]]; then
    ZONE=${PUBLIC_HOSTNAME#*.}
    
    certbot certonly -n --dns-route53 --agree-tos -m administrator@${ZONE} \
            -d ${PUBLIC_HOSTNAME}

    rm /etc/nginx/cert.pem /etc/nginx/cert.key
    ln -s /etc/letsencrypt/live/${PUBLIC_HOSTNAME}/fullchain.pem /etc/nginx/cert.pem
    ln -s /etc/letsencrypt/live/${PUBLIC_HOSTNAME}/privkey.pem /etc/nginx/cert.key
    systemctl restart nginx
else
    echo "No public hostname set, skipping automatic cert issuance"
    exit 1
fi

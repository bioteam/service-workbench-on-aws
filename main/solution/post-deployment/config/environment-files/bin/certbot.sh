#!/bin/bash

set -e

# Install certbot, request a certificate, and update nginx
# configuration to point to the newly issued cert

amazon-linux-extras install -y epel
yum -y install certbot certbot-dns-route53
systemctl enable certbot-renew.timer
systemctl start certbot-renew.timer

# Service Workbench doesn't currently have a data path providing the
# public facing DNS name of this instance. So instead, we scan through
# the account's hosted zones looking for records pointing to the
# public hostname known by the EC2 instance's metadata.
EC2_HOSTNAME=$(ec2-metadata --public-hostname | awk '{print $2}')
HOSTED_ZONES=$(aws route53 list-hosted-zones \
                   --query 'HostedZones[*].Id' --output text \
                   | sed -r 's,/hostedzone/,,g')
for zoneid in ${HOSTED_ZONES}; do
    PUBLIC_HOSTNAME=$(aws route53 list-resource-record-sets \
                          --hosted-zone-id ${zoneid} \
                          --query "ResourceRecordSets[?ResourceRecords[0].Value == '${EC2_HOSTNAME}'] | [0].Name" \
                          --output text)
    if [[ ${PUBLIC_HOSTNAME} != "None" ]]; then
        PUBLIC_HOSTNAME=${PUBLIC_HOSTNAME%.}
        ZONE=$(aws route53 list-resource-record-sets \
                   --hosted-zone-id ${zoneid} \
                   --query "ResourceRecordSets[?Type == 'SOA'].Name" \
                   --output text)
        ZONE=${ZONE%.}
        break
    fi
done

certbot certonly -n --dns-route53 --agree-tos -m administrator@${ZONE} \
        -d ${PUBLIC_HOSTNAME}

rm /etc/nginx/cert.pem /etc/nginx/cert.key
ln -s /etc/letsencrypt/live/${PUBLIC_HOSTNAME}/fullchain.pem /etc/nginx/cert.pem
ln -s /etc/letsencrypt/live/${PUBLIC_HOSTNAME}/privkey.pem /etc/nginx/cert.key
systemctl restart nginx

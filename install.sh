#!/bin/bash

# warnanya
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# input
function prompt_user() {
    read -p "$(echo -e ${YELLOW}$1 ${NC}[$2]): " input
    echo ${input:-$2}
}

# input domain var
api_domain=$(prompt_user "Your API Domain (e.g., api.chiwa.my.id)" "api.chiwa.my.id")
root_domain=$(prompt_user "Your root domain (e.g., chiwa.my.id)" "chiwa.my.id")

# verif dom
echo -e "${YELLOW}Verifying domain pointing...${NC}"
ip_address=$(curl -s http://ipinfo.io/ip)
api_domain_ip=$(dig +short $api_domain)
root_domain_ip=$(dig +short $root_domain)

if [[ $api_domain_ip != $ip_address ]]; then
    echo -e "${RED}ERROR: API domain ($api_domain) is not pointing to the IP address of this VPS ($ip_address).${NC}"
    exit 1
fi

if [[ $root_domain_ip != $ip_address ]]; then
    echo -e "${RED}ERROR: Root domain ($root_domain) is not pointing to the IP address of this VPS ($ip_address).${NC}"
    exit 1
fi

echo -e "${GREEN}Domain verification passed.${NC}"

# nginx ins
echo -e "${YELLOW}Updating and installing Nginx...${NC}"
apt update
apt install -y nginx unzip

# dir for web
echo -e "${YELLOW}Creating directories...${NC}"
mkdir -p /var/www/api
mkdir -p /var/www/$root_domain/html

# dl
echo -e "${YELLOW}Downloading website files from GitHub...${NC}"
wget https://github.com/aiprojectchiwa/simple-nginx-api/archive/refs/heads/main.zip -O /tmp/simple-nginx-api.zip
unzip /tmp/simple-nginx-api.zip -d /tmp

# Pindahkan file ke direktori web root
echo -e "${YELLOW}Moving files to web root...${NC}"
cp -r /tmp/simple-nginx-api-main/api/* /var/www/api/
cp -r /tmp/simple-nginx-api-main/chiwa.my.id/html/* /var/www/$root_domain/html/

# del temp
rm -rf /tmp/simple-nginx-api.zip /tmp/simple-nginx-api-main

# copy sinet-avail
echo -e "${YELLOW}Configuring Nginx...${NC}"
cat <<EOL > /etc/nginx/sites-available/$root_domain
server {
    listen 80;
    server_name $root_domain www.$root_domain;

    root /var/www/$root_domain/html;
    index index.html;

    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOL

cat <<EOL > /etc/nginx/sites-available/$api_domain
server {
    listen 80;
    server_name $api_domain;

    location / {
        default_type text/html;
        root /var/www/api;
        index index.html;
    }

    location /banned/list {
        default_type application/json;
        alias /var/www/api/banned.json;
    }
    location /mail {
        default_type application/json;
        alias /var/www/api/mail.json;
    }
}
EOL

# symlink
ln -s /etc/nginx/sites-available/$root_domain /etc/nginx/sites-enabled/
ln -s /etc/nginx/sites-available/$api_domain /etc/nginx/sites-enabled/

# test
echo -e "${YELLOW}Testing Nginx configuration...${NC}"
nginx -t

# restart
echo -e "${YELLOW}Restarting Nginx...${NC}"
systemctl restart nginx

echo -e "${GREEN}Installation and configuration completed successfully.${NC}"

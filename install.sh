#!/bin/bash

# Fungsi untuk menambahkan warna
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Fungsi untuk menanyakan input dari pengguna
function prompt_user() {
    read -p "$(echo -e ${YELLOW}$1 ${NC}[$2]): " input
    echo ${input:-$2}
}

# Menanyakan informasi dari pengguna
api_domain=$(prompt_user "Your API Domain (e.g., api.chiwa.my.id)" "api.chiwa.my.id")
root_domain=$(prompt_user "Your root domain (e.g., chiwa.my.id)" "chiwa.my.id")
email=$(prompt_user "Your email for SSL certificate" "your-email@example.com")

# Verifikasi apakah domain sudah dipointing ke IP VPS
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

# Perbarui dan instal Nginx
echo -e "${YELLOW}Updating and installing Nginx...${NC}"
apt update
apt install -y nginx unzip certbot python3-certbot-nginx

# Buat direktori untuk website
echo -e "${YELLOW}Creating directories...${NC}"
mkdir -p /var/www/api
mkdir -p /var/www/$root_domain/html

# Unduh file dari repositori GitHub
echo -e "${YELLOW}Downloading website files from GitHub...${NC}"
wget https://github.com/aiprojectchiwa/simple-nginx-api/archive/refs/heads/main.zip -O /tmp/simple-nginx-api.zip
unzip /tmp/simple-nginx-api.zip -d /tmp

# Pindahkan file ke direktori web root
echo -e "${YELLOW}Moving files to web root...${NC}"
cp -r /tmp/simple-nginx-api-main/api/* /var/www/api/
cp -r /tmp/simple-nginx-api-main/chiwa.my.id/html/* /var/www/$root_domain/html/

# Hapus file sementara
rm -rf /tmp/simple-nginx-api.zip /tmp/simple-nginx-api-main

# Salin file konfigurasi Nginx ke sites-available
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

# Buat symlink ke sites-enabled
ln -s /etc/nginx/sites-available/$root_domain /etc/nginx/sites-enabled/
ln -s /etc/nginx/sites-available/$api_domain /etc/nginx/sites-enabled/

# Uji konfigurasi Nginx
echo -e "${YELLOW}Testing Nginx configuration...${NC}"
nginx -t

# Restart Nginx untuk menerapkan konfigurasi baru
echo -e "${YELLOW}Restarting Nginx...${NC}"
systemctl restart nginx

# Dapatkan sertifikat SSL
echo -e "${YELLOW}Obtaining SSL certificate...${NC}"
certbot --nginx -d $api_domain -d $root_domain -d www.$root_domain --non-interactive --agree-tos --email $email

echo -e "${GREEN}Installation and configuration completed successfully.${NC}"

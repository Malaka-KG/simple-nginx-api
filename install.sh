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

# Install website otomatis
function install_website() {
    # Menanyakan informasi dari pengguna
    api_domain=$(prompt_user "Your API Domain (e.g., api.chiwa.my.id)" "api.chiwa.my.id")
    root_domain=$(prompt_user "Your root domain (e.g., chiwa.my.id)" "chiwa.my.id")
    email=$(prompt_user "Your email for SSL certificate" "your-email@example.com")

    # Verifikasi apakah domain sudah dipointing ke IP VPS
    verify_domain

    # Install Nginx dan Certbot
    install_dependencies

    # Buat direktori untuk website
    create_directories

    # Unduh file dari repositori GitHub
    download_files

    # Pindahkan file ke direktori web root
    move_files

    # Konfigurasi Nginx
    configure_nginx

    # Dapatkan sertifikat SSL
    obtain_ssl_certificate

    # Kembalikan pesan
    echo -e "${GREEN}Website telah terinstall dan seharusnya bisa diakses pada http://$root_domain dan http://$api_domain.${NC}"
}

# Uninstall website otomatis
function uninstall_website() {
    # Menanyakan informasi dari pengguna
    api_domain=$(prompt_user "Your API Domain (e.g., api.chiwa.my.id)" "api.chiwa.my.id")
    root_domain=$(prompt_user "Your root domain (e.g., chiwa.my.id)" "chiwa.my.id")

    # Hapus konfigurasi Nginx
    rm -f /etc/nginx/sites-available/$api_domain
    rm -f /etc/nginx/sites-available/$root_domain
    rm -f /etc/nginx/sites-enabled/$api_domain
    rm -f /etc/nginx/sites-enabled/$root_domain

    # Hapus direktori website
    rm -rf /var/www/api
    rm -rf /var/www/$root_domain

    # Kembalikan pesan
    echo -e "${GREEN}Website telah diuninstall.${NC}"
    exit 1
}

# Verifikasi apakah domain sudah dipointing ke IP VPS
function verify_domain() {
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
}

# Install Nginx dan Certbot
function install_dependencies() {
    echo -e "${YELLOW}Updating and installing Nginx...${NC}"
    apt update
    apt install -y nginx unzip certbot python3-certbot-nginx
}

# Buat direktori untuk website
function create_directories() {
    echo -e "${YELLOW}Creating directories...${NC}"
    mkdir -p /var/www/api
    mkdir -p /var/www/$root_domain/html
}

# Unduh file dari repositori GitHub
function download_files() {
    echo -e "${YELLOW}Downloading website files from GitHub...${NC}"
    wget https://github.com/aiprojectchiwa/simple-nginx-api/archive/refs/heads/main.zip -O /tmp/simple-nginx-api.zip
    unzip /tmp/simple-nginx-api.zip -d /tmp
}

# Pindahkan file ke direktori web root
function move_files() {
    echo -e "${YELLOW}Moving files to web root...${NC}"
    cp -r /tmp/simple-nginx-api-main/api/* /var/www/api/
    cp -r /tmp/simple-nginx-api-main/chiwa.my.id/html/* /var/www/$root_domain/html/
    rm -rf /tmp/simple-nginx-api.zip /tmp/simple-nginx-api-main
}

# Konfigurasi Nginx
function configure_nginx() {
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

    ln -s /etc/nginx/sites-available/$root_domain /etc/nginx/sites-enabled/
    ln -s /etc/nginx/sites-available/$api_domain /etc/nginx/sites-enabled/

    nginx -t
    systemctl restart nginx
}

# Dapatkan sertifikat SSL
function obtain_ssl_certificate() {
    echo -e "${YELLOW}Obtaining SSL certificate...${NC}"
    certbot --nginx -d $api_domain -d $root_domain -d www.$root_domain --non-interactive --agree-tos --email $email
}

# Opsi menu untuk pilihan instalasi
PS3='Please enter your choice: '
options=("Install Website Automatically" "Uninstall Website Automatically" "Quit")
select opt in "${options[@]}"
do
    case $opt in
        "Install Website Automatically")
            install_website
            ;;
        "Uninstall Website Automatically")
            uninstall_website
            ;;
        "Quit")
            break
            ;;
        *) echo -e "${RED}Invalid option${NC}";;
    esac
done

echo -e "${GREEN}Operation completed.${NC}"

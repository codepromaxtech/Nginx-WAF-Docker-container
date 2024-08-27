# Use Ubuntu 22.04 as the base image
FROM ubuntu:22.04

# Set environment variables to avoid interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Update the system and install necessary prerequisites
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y nginx php-fpm php-mysql php-xml php-mbstring php-curl php-zip mysql-server git gcc build-essential libtool libpcre3 libpcre3-dev zlib1g zlib1g-dev libssl-dev wget

# Download and compile ModSecurity
RUN cd /usr/local/src && \
    git clone --depth 1 https://github.com/SpiderLabs/ModSecurity && \
    cd ModSecurity && \
    git submodule init && \
    git submodule update && \
    ./build.sh && \
    ./configure && \
    make && \
    make install

# Download and compile ModSecurity NGINX connector
RUN cd /usr/local/src && \
    git clone --depth 1 https://github.com/SpiderLabs/ModSecurity-nginx.git

# Download and compile NGINX with ModSecurity
RUN wget http://nginx.org/download/nginx-1.18.0.tar.gz && \
    tar -zxvf nginx-1.18.0.tar.gz && \
    cd nginx-1.18.0 && \
    ./configure --with-compat --add-dynamic-module=../ModSecurity-nginx && \
    make modules && \
    mkdir -p /etc/nginx/modules && \
    cp objs/ngx_http_modsecurity_module.so /etc/nginx/modules/

# Configure NGINX to load ModSecurity module
RUN echo "load_module modules/ngx_http_modsecurity_module.so;" > /etc/nginx/nginx.conf

# Configure ModSecurity
RUN mv /usr/local/src/ModSecurity/modsecurity.conf-recommended /etc/nginx/modsecurity.conf && \
    mv /usr/local/src/ModSecurity/unicode.mapping /etc/nginx/ && \
    sed -i 's/SecRuleEngine DetectionOnly/SecRuleEngine On/' /etc/nginx/modsecurity.conf

# Download OWASP Core Rule Set and configure ModSecurity
RUN git clone https://github.com/coreruleset/coreruleset /etc/nginx/owasp-crs && \
    cp /etc/nginx/owasp-crs/crs-setup.conf.example /etc/nginx/owasp-crs/crs-setup.conf && \
    echo 'Include /etc/nginx/owasp-crs/crs-setup.conf' >> /etc/nginx/modsecurity.conf && \
    echo 'Include /etc/nginx/owasp-crs/rules/*.conf' >> /etc/nginx/modsecurity.conf

# Create a directory for future projects
RUN mkdir -p /www/project && \
    chown -R www-data:www-data /www/project && \
    chmod -R 755 /www/project

# Configure NGINX to serve from /www/project
# Configure NGINX to serve from /www/project
RUN echo 'server {
    listen 80;
    server_name localhost;
    root /www/project;
    index index.php index.html index.htm;
    location / {
        try_files $uri $uri/ =404;
    }
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php8.1-fpm.sock;
    }
    location ~ /\.ht {
        deny all;
    }
    modsecurity on;
    modsecurity_rules_file /etc/nginx/modsecurity.conf;
}' > /etc/nginx/sites-available/default


# Expose port 80 to the host
EXPOSE 80

# Start NGINX and MySQL
CMD service mysql start && service nginx start && tail -f /var/log/nginx/access.log

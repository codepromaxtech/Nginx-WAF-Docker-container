# Use Ubuntu 22.04 as the base image
FROM ubuntu:22.04

# Set environment variables to non-interactive
ENV DEBIAN_FRONTEND=noninteractive

# Update the system and install necessary prerequisites
RUN apt-get update && apt-get upgrade -y && \
    apt-get install -y nginx php-fpm php-mysql php-xml php-mbstring php-curl php-zip mysql-server git gcc build-essential libtool libpcre3 libpcre3-dev zlib1g zlib1g-dev libssl-dev wget composer

# Secure MySQL installation (assuming default settings)
RUN service mysql start && \
    mysql_secure_installation --use-default

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

# Download and compile ModSecurity NGINX Connector
RUN cd /usr/local/src && \
    git clone --depth 1 https://github.com/SpiderLabs/ModSecurity-nginx.git

# Download and compile NGINX with ModSecurity module
RUN cd /usr/local/src && \
    wget http://nginx.org/download/nginx-1.18.0.tar.gz && \
    tar -zxvf nginx-1.18.0.tar.gz && \
    cd nginx-1.18.0 && \
    ./configure --with-compat --add-dynamic-module=../ModSecurity-nginx && \
    make modules && \
    mkdir -p /etc/nginx/modules && \
    cp objs/ngx_http_modsecurity_module.so /etc/nginx/modules/

# Configure NGINX to load ModSecurity module
RUN echo "load_module modules/ngx_http_modsecurity_module.so;" > /etc/nginx/nginx.conf

# Move and configure ModSecurity
RUN mv /usr/local/src/ModSecurity/modsecurity.conf-recommended /etc/nginx/modsecurity.conf && \
    mv /usr/local/src/ModSecurity/unicode.mapping /etc/nginx/ && \
    sed -i 's/SecRuleEngine DetectionOnly/SecRuleEngine On/' /etc/nginx/modsecurity.conf

# Download OWASP Core Rule Set and include it in ModSecurity configuration
RUN git clone https://github.com/coreruleset/coreruleset /etc/nginx/owasp-crs && \
    cp /etc/nginx/owasp-crs/crs-setup.conf.example /etc/nginx/owasp-crs/crs-setup.conf && \
    echo 'Include /etc/nginx/owasp-crs/crs-setup.conf' >> /etc/nginx/modsecurity.conf && \
    echo 'Include /etc/nginx/owasp-crs/rules/*.conf' >> /etc/nginx/modsecurity.conf

# Create MySQL databases for WordPress and Laravel
RUN service mysql start && \
    mysql -e "CREATE DATABASE wordpress_db;" && \
    mysql -e "CREATE USER 'wp_user'@'localhost' IDENTIFIED BY 'strong_password';" && \
    mysql -e "GRANT ALL PRIVILEGES ON wordpress_db.* TO 'wp_user'@'localhost';" && \
    mysql -e "FLUSH PRIVILEGES;" && \
    mysql -e "CREATE DATABASE laravel_db;" && \
    mysql -e "CREATE USER 'laravel_user'@'localhost' IDENTIFIED BY 'strong_password';" && \
    mysql -e "GRANT ALL PRIVILEGES ON laravel_db.* TO 'laravel_user'@'localhost';" && \
    mysql -e "FLUSH PRIVILEGES;" && \
    mysql -e "EXIT;"

# Download and setup WordPress
RUN cd /var/www && \
    wget https://wordpress.org/latest.tar.gz && \
    tar -xzvf latest.tar.gz && \
    mv wordpress waf.codepromax.com.de && \
    chown -R www-data:www-data /var/www/waf.codepromax.com.de && \
    chmod -R 755 /var/www/waf.codepromax.com.de

# Setup Laravel
RUN cd /var/www && \
    composer create-project --prefer-dist laravel/laravel waf2.codepromax.com.de && \
    chown -R www-data:www-data /var/www/waf2.codepromax.com.de && \
    chmod -R 755 /var/www/waf2.codepromax.com.de

# Configure NGINX for WordPress and Laravel
RUN echo 'server {\n\
    listen 80;\n\
    server_name waf.codepromax.com.de;\n\
    root /var/www/waf.codepromax.com.de;\n\
    index index.php index.html index.htm;\n\
    location / {\n\
        try_files $uri $uri/ /index.php?$args;\n\
    }\n\
    location ~ \.php$ {\n\
        include snippets/fastcgi-php.conf;\n\
        fastcgi_pass unix:/var/run/php/php8.1-fpm.sock;\n\
    }\n\
    location ~ /\.ht {\n\
        deny all;\n\
    }\n\
    modsecurity on;\n\
    modsecurity_rules_file /etc/nginx/modsecurity.conf;\n\
}' > /etc/nginx/sites-available/waf.codepromax.com.de

RUN echo 'server {\n\
    listen 80;\n\
    server_name waf2.codepromax.com.de;\n\
    root /var/www/waf2.codepromax.com.de/public;\n\
    index index.php index.html index.htm;\n\
    location / {\n\
        try_files $uri $uri/ /index.php?$query_string;\n\
    }\n\
    location ~ \.php$ {\n\
        include snippets/fastcgi-php.conf;\n\
        fastcgi_pass unix:/var/run/php/php8.1-fpm.sock;\n\
    }\n\
    location ~ /\.ht {\n\
        deny all;\n\
    }\n\
    modsecurity on;\n\
    modsecurity_rules_file /etc/nginx/modsecurity.conf;\n\
}' > /etc/nginx/sites-available/waf2.codepromax.com.de

# Enable the sites and restart NGINX
RUN ln -s /etc/nginx/sites-available/waf.codepromax.com.de /etc/nginx/sites-enabled/ && \
    ln -s /etc/nginx/sites-available/waf2.codepromax.com.de /etc/nginx/sites-enabled/ && \
    chown -R www-data:www-data /var/log/nginx && \
    chmod -R 755 /var/log/nginx && \
    nginx -t && \
    service nginx restart

# Expose port 80
EXPOSE 80

# Start NGINX and PHP-FPM
CMD ["nginx", "-g", "daemon off;"]

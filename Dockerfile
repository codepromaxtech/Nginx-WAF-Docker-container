# Use Ubuntu 22.04 as the base image
FROM ubuntu:22.04

# Set environment variables to non-interactive
ENV DEBIAN_FRONTEND=noninteractive

# Update the system and install necessary prerequisites
RUN apt-get update && apt-get upgrade -y && \
    apt-get install -y curl php-fpm php-mysql php-xml php-mbstring php-curl php-zip git gcc build-essential libtool libpcre3 libpcre3-dev zlib1g zlib1g-dev libssl-dev wget composer

# Download and compile NGINX 1.18.0
RUN wget http://nginx.org/download/nginx-1.18.0.tar.gz && \
    tar -zxvf nginx-1.18.0.tar.gz && \
    cd nginx-1.18.0 && \
    ./configure && \
    make && \
    make install && \
    cd .. && \
    rm -rf nginx-1.18.0.tar.gz
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
    mkdir -p /usr/share/nginx/modules && \
    cp objs/ngx_http_modsecurity_module.so /usr/share/nginx/modules/

# Configure NGINX to load ModSecurity module
RUN echo "load_module /usr/share/nginx/modules/ngx_http_modsecurity_module.so;" > /etc/nginx/nginx.conf

# Move and configure ModSecurity
RUN mv /usr/local/src/ModSecurity/modsecurity.conf-recommended /etc/nginx/modsecurity.conf && \
    mv /usr/local/src/ModSecurity/unicode.mapping /etc/nginx/ && \
    sed -i 's/SecRuleEngine DetectionOnly/SecRuleEngine On/' /etc/nginx/modsecurity.conf

# Download OWASP Core Rule Set and include it in ModSecurity configuration
RUN git clone https://github.com/coreruleset/coreruleset /etc/nginx/owasp-crs && \
    cp /etc/nginx/owasp-crs/crs-setup.conf.example /etc/nginx/owasp-crs/crs-setup.conf && \
    echo 'Include /etc/nginx/owasp-crs/crs-setup.conf' >> /etc/nginx/modsecurity.conf && \
    echo 'Include /etc/nginx/owasp-crs/rules/*.conf' >> /etc/nginx/modsecurity.conf

# Download and setup WordPress
RUN curl -o /tmp/wordpress.tar.gz https://wordpress.org/latest.tar.gz && \
    tar -xzvf /tmp/wordpress.tar.gz -C /var/www/html && \
    chown -R www-data:www-data /var/www/html/wordpress && \
    mkdir /var/www/cpmerp.codepromax.com.de && \
    mv /var/www/html/wordpress/* /var/www/cpmerp.codepromax.com.de && \
    chown -R www-data:www-data /var/www/cpmerp.codepromax.com.de && \
    chmod -R 755 /var/www/cpmerp.codepromax.com.de && \
    rm -rf /var/www/html /tmp/wordpress.tar.gz

# Configure NGINX for WordPress and Laravel
COPY cpmerp.codepromax.com.de /etc/nginx/sites-available/cpmerp.codepromax.com.de

RUN unlink /etc/nginx/sites-enabled/default && \
    ln -s /etc/nginx/sites-available/cpmerp.codepromax.com.de /etc/nginx/sites-enabled/

## Expose port 80 to the host
EXPOSE 80

# Create a script to start both Nginx and PHP-FPM
RUN echo '#!/bin/bash\nservice php8.1-fpm start\nnginx -g "daemon off;"' > /start.sh && \
    chmod +x /start.sh

# Set the entrypoint to the script
ENTRYPOINT ["/start.sh"]

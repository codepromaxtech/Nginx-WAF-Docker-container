# Use Ubuntu 22.04 as the base image
FROM ubuntu:22.04

# Set environment variables to avoid interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install prerequisites
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y wget build-essential libpcre3 libpcre3-dev zlib1g zlib1g-dev libssl-dev git gcc make automake libtool pkg-config autotools-dev nginx php8.1-fpm php8.1-mysql curl sudo

# Download and compile NGINX 1.18.0
RUN wget http://nginx.org/download/nginx-1.18.0.tar.gz && \
    tar -zxvf nginx-1.18.0.tar.gz && \
    cd nginx-1.18.0 && \
    ./configure && \
    make && \
    make install && \
    cd .. && \
    rm nginx-1.18.0.tar.gz

# Download and compile ModSecurity
RUN git clone --depth 1 https://github.com/SpiderLabs/ModSecurity /usr/local/src/ModSecurity && \
    cd /usr/local/src/ModSecurity && \
    git submodule init && \
    git submodule update && \
    ./build.sh && \
    ./configure && \
    make && \
    make install

# Download and compile ModSecurity NGINX connector
RUN git clone --depth 1 https://github.com/SpiderLabs/ModSecurity-nginx.git /usr/local/src/ModSecurity-nginx && \
    cd /usr/local/src/ModSecurity-nginx

# Download and compile NGINX 1.18.0 with ModSecurity
RUN wget http://nginx.org/download/nginx-1.18.0.tar.gz && \
    tar -zxvf nginx-1.18.0.tar.gz && \
    cd nginx-1.18.0 && \
    ./configure --with-compat --add-dynamic-module=/usr/local/src/ModSecurity-nginx && \
    make modules && \
    mkdir -p /etc/nginx/modules && \
    cp objs/ngx_http_modsecurity_module.so /etc/nginx/modules/ && \
    cd .. && \
    rm nginx-1.18.0.tar.gz

# Configure NGINX to load ModSecurity module
RUN mkdir -p /usr/local/nginx/conf && \
    echo "load_module modules/ngx_http_modsecurity_module.so;" > /usr/local/nginx/conf/nginx.conf

# Download WordPress
RUN curl -o /tmp/wordpress.tar.gz https://wordpress.org/latest.tar.gz && \
    tar -xzvf /tmp/wordpress.tar.gz -C /var/www/html && \
    chown -R www-data:www-data /var/www/html/wordpress && \
    mkdir /var/www/wordpress && \
    mv /var/www/html/wordpress/* /var/www/wordpress && \
    chown -R www-data:www-data /var/www/wordpress && \
    chmod -R 755 /var/www/wordpress && \
    rm -r /var/www/html && \
    rm /tmp/wordpress.tar.gz
    

# Copy NGINX configuration file and enable site
COPY cpmerp.codepromax.com.de /etc/nginx/sites-available/cpmerp.codepromax.com.de
RUN unlink /etc/nginx/sites-enabled/default && \
    ln -s /etc/nginx/sites-available/cpmerp.codepromax.com.de /etc/nginx/sites-enabled/

# Expose port 80 to the host
EXPOSE 80

# Create a script to start both Nginx and PHP-FPM
RUN echo '#!/bin/bash\nservice php8.1-fpm start\nnginx -g "daemon off;"' > /start.sh && \
    chmod +x /start.sh

# Set the entrypoint to the script
ENTRYPOINT ["/start.sh"]

# Use Ubuntu 22.04 as the base image
FROM ubuntu:22.04

# Set environment variables to avoid interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install prerequisites and download necessary files in one layer
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y wget build-essential libpcre3 libpcre3-dev zlib1g zlib1g-dev libssl-dev git gcc make automake libtool pkg-config autotools-dev nginx php8.1-fpm php8.1-mysql curl sudo && \
    wget http://nginx.org/download/nginx-1.18.0.tar.gz && \
    git clone --depth 1 https://github.com/SpiderLabs/ModSecurity-nginx.git /usr/local/src/ModSecurity-nginx && \
    git clone --depth 1 https://github.com/SpiderLabs/ModSecurity /usr/local/src/ModSecurity

# Compile and install ModSecurity
RUN cd /usr/local/src/ModSecurity && \
    git submodule init && \
    git submodule update && \
    ./build.sh && \
    ./configure && \
    make && \
    make install

# Compile and install NGINX with ModSecurity
RUN tar -zxvf nginx-1.18.0.tar.gz && \
    cd nginx-1.18.0 && \
    ./configure --with-compat --add-dynamic-module=/usr/local/src/ModSecurity-nginx && \
    make && \
    make install && \
    mkdir -p /etc/nginx/modules && \
    cp objs/ngx_http_modsecurity_module.so /etc/nginx/modules/ && \
    rm -rf nginx-1.18.0.tar.gz /usr/local/src/ModSecurity-nginx /nginx-1.18.0

# Configure NGINX to load ModSecurity module
RUN echo "load_module modules/ngx_http_modsecurity_module.so;" > /etc/nginx/nginx.conf && \
    cp /usr/local/modsecurity.conf-recommended /etc/nginx/modsecurity.conf && \
    cp /usr/local/unicode.mapping /etc/nginx/ && \
    sed -i 's/SecRuleEngine DetectionOnly/SecRuleEngine On/' /etc/nginx/modsecurity.conf

# Download OWASP Core Rule Set & Include the CRS configuration in ModSecurity
RUN git clone https://github.com/coreruleset/coreruleset /etc/nginx/owasp-crs && \
    cp /etc/nginx/owasp-crs/crs-setup.conf.example /etc/nginx/owasp-crs/crs-setup.conf && \
    echo 'Include /etc/nginx/owasp-crs/crs-setup.conf' | tee -a /etc/nginx/modsecurity.conf && \
    echo 'Include /etc/nginx/owasp-crs/rules/*.conf' | tee -a /etc/nginx/modsecurity.conf

# Download WordPress
RUN curl -o /tmp/wordpress.tar.gz https://wordpress.org/latest.tar.gz && \
    tar -xzvf /tmp/wordpress.tar.gz -C /var/www/html && \
    mkdir /var/www/wordpress && \
    mv /var/www/html/wordpress/* /var/www/wordpress && \
    chown -R www-data:www-data /var/www/wordpress && \
    chmod -R 755 /var/www/wordpress && \
    rm -rf /var/www/html /tmp/wordpress.tar.gz

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

# Use Ubuntu 22.04 as the base image
FROM ubuntu:22.04

# Set environment variables to avoid interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install prerequisites
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y nginx curl wget build-essential libpcre3 libpcre3-dev zlib1g zlib1g-dev libssl-dev \
    git gcc make automake libtool pkg-config autotools-dev \
    php8.1-fpm php8.1-mysql php8.1-xml php8.1-mbstring php8.1-curl php8.1-zip php8.1-gd php8.1-bcmath \
    php8.1-intl php8.1-soap php8.1-cli php8.1-json php8.1-readline php8.1-tokenizer \
    mariadb-client supervisor
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
RUN git clone --depth 1 https://github.com/SpiderLabs/ModSecurity-nginx.git /usr/local/src/ModSecurity-nginx

# Compile ModSecurity module and copy it to the NGINX modules directory
RUN wget http://nginx.org/download/nginx-1.18.0.tar.gz && \
    tar -zxvf nginx-1.18.0.tar.gz && \
    cd nginx-1.18.0 && \
    ./configure --with-compat --add-dynamic-module=/usr/local/src/ModSecurity-nginx && \
    make modules && \
    mkdir -p /etc/nginx/modules && \
    cp objs/ngx_http_modsecurity_module.so /etc/nginx/modules/ && \
    rm -rf nginx-1.18.0.tar.gz nginx-1.18.0

# Copy a complete and correct NGINX configuration file
COPY nginx.conf /etc/nginx/nginx.conf
# Configure NGINX to load ModSecurity module
RUN mv /usr/local/src/ModSecurity/modsecurity.conf-recommended /etc/nginx/modsecurity.conf && \
    mv /usr/local/src/ModSecurity/unicode.mapping /etc/nginx/ && \
    sed -i 's/SecRuleEngine DetectionOnly/SecRuleEngine On/' /etc/nginx/modsecurity.conf
# Download OWASP Core Rule Set & Include the CRS configuration in your ModSecurity configuration
RUN git clone https://github.com/coreruleset/coreruleset /etc/nginx/owasp-crs && \
    cp /etc/nginx/owasp-crs/crs-setup.conf.example /etc/nginx/owasp-crs/crs-setup.conf && \
    echo 'Include /etc/nginx/owasp-crs/crs-setup.conf' | tee -a /etc/nginx/modsecurity.conf && \
    echo 'Include /etc/nginx/owasp-crs/rules/*.conf' | tee -a /etc/nginx/modsecurity.conf

# Copy NGINX site configuration file and enable site
COPY wordpress /etc/nginx/sites-available/wordpress
RUN unlink /etc/nginx/sites-enabled/default && \
    ln -s /etc/nginx/sites-available/wordpress /etc/nginx/sites-enabled/

# Expose port 80 to the host
EXPOSE 80

# Create a script to start both Nginx and PHP-FPM
RUN echo '#!/bin/bash\nservice php8.1-fpm start\nnginx -g "daemon off;"' > /start.sh && \
    chmod +x /start.sh

# Set the entrypoint to the script
ENTRYPOINT ["/start.sh"]

# Use the official Nginx base image
FROM nginx:latest

# Install dependencies
RUN apt-get update && \
    apt-get install -y \
    git \
    gcc \
    libtool \
    libpcre3-dev \
    libxml2-dev \
    libyajl-dev \
    make \
    automake \
    autoconf \
    zlib1g-dev \
    libcurl4-openssl-dev \
    libgeoip-dev \
    wget \
    && apt-get clean

# Clone and build ModSecurity
RUN git clone --depth 1 -b v3/master https://github.com/SpiderLabs/ModSecurity /opt/ModSecurity \
    && cd /opt/ModSecurity \
    && git submodule init \
    && git submodule update \
    && ./build.sh \
    && ./configure \
    && make \
    && make install

# Clone and build ModSecurity-nginx connector
RUN git clone --depth 1 https://github.com/SpiderLabs/ModSecurity-nginx.git /opt/ModSecurity-nginx \
    && cd /opt/ModSecurity-nginx \
    && wget http://nginx.org/download/nginx-1.18.0.tar.gz \
    && tar -xvzf nginx-1.18.0.tar.gz \
    && cd nginx-1.18.0 \
    && ./configure --with-compat --add-dynamic-module=/opt/ModSecurity-nginx \
    && make modules \
    && cp objs/ngx_http_modsecurity_module.so /etc/nginx/modules

# Copy custom Nginx configuration
COPY nginx.conf /etc/nginx/nginx.conf

# Copy ModSecurity configuration
COPY modsecurity.conf /etc/modsecurity/modsecurity.conf

# Expose ports
EXPOSE 80
EXPOSE 443

# Start Nginx
CMD ["nginx", "-g", "daemon off;"]

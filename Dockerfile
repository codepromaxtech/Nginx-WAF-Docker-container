# Use the official Nginx image as a base
FROM nginx:latest

# Install dependencies and ModSecurity
RUN apt-get update && \
    apt-get install -y libnginx-mod-security \
    && apt-get clean

# Copy custom ModSecurity configuration
COPY modsecurity.conf /etc/nginx/modsecurity/modsecurity.conf

# Copy custom Nginx configuration
COPY nginx.conf /etc/nginx/nginx.conf

# Copy custom rules (optional)
# COPY rules/ /etc/nginx/modsecurity/rules/

# Expose ports
EXPOSE 80 443

# Start Nginx
CMD ["nginx", "-g", "daemon off;"]

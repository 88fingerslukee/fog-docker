---
layout: default
title: Reverse Proxy Setup
nav_order: 6
description: "Deploy FOG Docker behind Traefik, Nginx, Apache, or Caddy"
permalink: /reverse-proxy
---

# Reverse Proxy Setup

This guide covers setting up FOG Docker behind various reverse proxy solutions for SSL termination and load balancing.

## Overview

Using a reverse proxy with FOG Docker provides:
- **SSL/TLS termination** and certificate management
- **Load balancing** for multiple FOG instances
- **Domain-based routing** and virtual hosting
- **Security features** like rate limiting and DDoS protection
- **Centralized logging** and monitoring

## Supported Reverse Proxies

This guide covers:
- **Traefik** - Modern reverse proxy with automatic SSL
- **Nginx** - High-performance web server and reverse proxy
- **Apache** - Traditional web server with reverse proxy capabilities
- **Caddy** - Automatic HTTPS and modern web server

## FOG Docker Configuration

### Environment Variables

Configure FOG Docker for reverse proxy mode:

```bash
# Reverse proxy configuration
FOG_WEB_HOST=fog.example.com
FOG_STORAGE_HOST=fog.example.com
FOG_TFTP_HOST=fog.example.com
FOG_WOL_HOST=fog.example.com

# Protocol settings
FOG_HTTP_PROTOCOL=https
FOG_INTERNAL_HTTPS_ENABLED=false  # SSL handled by reverse proxy

# Network settings
FOG_WEB_ROOT=/fog
```

### Docker Compose Configuration

```yaml
services:
  fog-server:
    image: ghcr.io/88fingerslukee/fog-docker:latest
    environment:
      - FOG_WEB_HOST=fog.example.com
      - FOG_HTTP_PROTOCOL=https
      - FOG_INTERNAL_HTTPS_ENABLED=false
      - FOG_APACHE_EXPOSED_PORT=8080  # Map to different external port
    ports:
      - "8080:80"  # Internal HTTP only
    # ... other configuration
```

## Traefik Configuration

### Docker Compose with Traefik

```yaml
services:
  traefik:
    image: traefik:v3.0
    command:
      - --api.dashboard=true
      - --api.insecure=true
      - --providers.docker=true
      - --providers.docker.exposedbydefault=false
      - --entrypoints.web.address=:80
      - --entrypoints.websecure.address=:443
      - --certificatesresolvers.letsencrypt.acme.tlschallenge=true
      - --certificatesresolvers.letsencrypt.acme.email=${LETSENCRYPT_EMAIL}
      - --certificatesresolvers.letsencrypt.acme.storage=/letsencrypt/acme.json
    ports:
      - "80:80"
      - "443:443"
      - "8080:8080"  # Traefik dashboard
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./letsencrypt:/letsencrypt
    networks:
      - fog-network

  fog-server:
    image: ghcr.io/88fingerslukee/fog-docker:latest
    environment:
      - FOG_WEB_HOST=${FOG_WEB_HOST}
      - FOG_HTTP_PROTOCOL=${FOG_HTTP_PROTOCOL}
      - FOG_INTERNAL_HTTPS_ENABLED=${FOG_INTERNAL_HTTPS_ENABLED}
      - FOG_APACHE_EXPOSED_PORT=${FOG_APACHE_EXPOSED_PORT}
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.fog.rule=Host(`${FOG_WEB_HOST}`)"
      - "traefik.http.routers.fog.entrypoints=websecure"
      - "traefik.http.routers.fog.tls.certresolver=letsencrypt"
      - "traefik.http.services.fog.loadbalancer.server.port=80"
      - "traefik.docker.network=fog-network"
    networks:
      - fog-network

networks:
  fog-network:
    external: true
```

**Required .env variables:**
```bash
FOG_WEB_HOST=fog.example.com
FOG_HTTP_PROTOCOL=https
FOG_INTERNAL_HTTPS_ENABLED=false
FOG_APACHE_EXPOSED_PORT=80
LETSENCRYPT_EMAIL=your-email@example.com
```

### Traefik Labels for FOG

```yaml
labels:
  # Basic routing
  - "traefik.enable=true"
  - "traefik.http.routers.fog.rule=Host(`fog.example.com`)"
  - "traefik.http.routers.fog.entrypoints=websecure"
  - "traefik.http.routers.fog.tls.certresolver=letsencrypt"
  
  # Service configuration
  - "traefik.http.services.fog.loadbalancer.server.port=80"
  
  # Security headers
  - "traefik.http.middlewares.fog-headers.headers.customrequestheaders.X-Forwarded-Proto=https"
  - "traefik.http.middlewares.fog-headers.headers.customrequestheaders.X-Forwarded-For="
  - "traefik.http.middlewares.fog-headers.headers.customrequestheaders.X-Real-IP="
  - "traefik.http.routers.fog.middlewares=fog-headers"
  
  # Rate limiting
  - "traefik.http.middlewares.fog-ratelimit.ratelimit.burst=100"
  - "traefik.http.middlewares.fog-ratelimit.ratelimit.average=50"
  - "traefik.http.routers.fog.middlewares=fog-ratelimit"
```

### Traefik Static Configuration

For more advanced configuration, use a static config file:

```yaml
# traefik.yml
api:
  dashboard: true
  insecure: true

entryPoints:
  web:
    address: ":80"
    http:
      redirections:
        entrypoint:
          to: websecure
          scheme: https
  websecure:
    address: ":443"

providers:
  docker:
    endpoint: "unix:///var/run/docker.sock"
    exposedByDefault: false

certificatesResolvers:
  letsencrypt:
    acme:
      tlsChallenge: {}
      email: ${LETSENCRYPT_EMAIL}
      storage: /letsencrypt/acme.json

log:
  level: INFO

accessLog: {}
```

**Required .env variable:**
```bash
LETSENCRYPT_EMAIL=your-email@example.com
```

## Nginx Configuration

### Basic Nginx Configuration

```nginx
# /etc/nginx/sites-available/fog
server {
    listen 80;
    server_name fog.example.com;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name fog.example.com;
    
    # SSL Configuration
    ssl_certificate /etc/letsencrypt/live/fog.example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/fog.example.com/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    
    # Security Headers
    add_header Strict-Transport-Security "max-age=63072000" always;
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    
    # Proxy Configuration
    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $host;
        proxy_set_header X-Forwarded-Port $server_port;
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
        
        # Buffer settings
        proxy_buffering on;
        proxy_buffer_size 4k;
        proxy_buffers 8 4k;
    }
    
    # Special handling for large file uploads
    location /fog/management/index.php {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Increase timeouts for large uploads
        proxy_connect_timeout 300s;
        proxy_send_timeout 300s;
        proxy_read_timeout 300s;
        
        # Increase client body size for image uploads
        client_max_body_size 10G;
    }
}
```

### Nginx with Let's Encrypt

```bash
# Install certbot
sudo apt install certbot python3-certbot-nginx

# Obtain certificate
sudo certbot --nginx -d fog.example.com

# Auto-renewal
sudo crontab -e
# Add: 0 12 * * * /usr/bin/certbot renew --quiet
```

### Nginx Load Balancing

```nginx
upstream fog_backend {
    server 127.0.0.1:8080;
    server 127.0.0.1:8081;
    server 127.0.0.1:8082;
    
    # Load balancing method
    least_conn;
    
    # Health checks
    keepalive 32;
}

server {
    listen 443 ssl http2;
    server_name fog.example.com;
    
    # SSL configuration...
    
    location / {
        proxy_pass http://fog_backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

## Apache Configuration

### Basic Apache Configuration

```apache
# /etc/apache2/sites-available/fog.conf
<VirtualHost *:80>
    ServerName fog.example.com
    Redirect permanent / https://fog.example.com/
</VirtualHost>

<VirtualHost *:443>
    ServerName fog.example.com
    
    # SSL Configuration
    SSLEngine on
    SSLCertificateFile /etc/letsencrypt/live/fog.example.com/fullchain.pem
    SSLCertificateKeyFile /etc/letsencrypt/live/fog.example.com/privkey.pem
    SSLProtocol all -SSLv3 -TLSv1 -TLSv1.1
    SSLCipherSuite ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384
    
    # Security Headers
    Header always set Strict-Transport-Security "max-age=63072000"
    Header always set X-Frame-Options DENY
    Header always set X-Content-Type-Options nosniff
    Header always set X-XSS-Protection "1; mode=block"
    
    # Proxy Configuration
    ProxyPreserveHost On
    ProxyPass / http://127.0.0.1:8080/
    ProxyPassReverse / http://127.0.0.1:8080/
    
    # Proxy Headers
    ProxyAddHeaders On
    RequestHeader set X-Forwarded-Proto "https"
    RequestHeader set X-Forwarded-Port "443"
    
    # Timeouts
    ProxyTimeout 300
    
    # Large file uploads
    <Location "/fog/management/index.php">
        ProxyPass http://127.0.0.1:8080/
        ProxyPassReverse http://127.0.0.1:8080/
        ProxyTimeout 300
    </Location>
</VirtualHost>
```

### Apache with Let's Encrypt

```bash
# Install certbot
sudo apt install certbot python3-certbot-apache

# Obtain certificate
sudo certbot --apache -d fog.example.com

# Auto-renewal
sudo crontab -e
# Add: 0 12 * * * /usr/bin/certbot renew --quiet
```

### Apache Load Balancing

```apache
# Load balancer configuration
<Proxy balancer://fog-cluster>
    BalancerMember http://127.0.0.1:8080
    BalancerMember http://127.0.0.1:8081
    BalancerMember http://127.0.0.1:8082
    ProxySet lbmethod=byrequests
</Proxy>

<VirtualHost *:443>
    ServerName fog.example.com
    
    # SSL configuration...
    
    ProxyPreserveHost On
    ProxyPass / balancer://fog-cluster/
    ProxyPassReverse / balancer://fog-cluster/
</VirtualHost>
```

## Caddy Configuration

### Basic Caddyfile

```caddy
# Caddyfile
fog.example.com {
    # Automatic HTTPS with Let's Encrypt
    tls your-email@example.com
    
    # Security headers
    header {
        Strict-Transport-Security "max-age=63072000"
        X-Frame-Options DENY
        X-Content-Type-Options nosniff
        X-XSS-Protection "1; mode=block"
    }
    
    # Proxy to FOG Docker
    reverse_proxy 127.0.0.1:8080 {
        header_up Host {host}
        header_up X-Real-IP {remote}
        header_up X-Forwarded-For {remote}
        header_up X-Forwarded-Proto {scheme}
    }
    
    # Handle large file uploads
    @large_uploads path /fog/management/index.php
    reverse_proxy @large_uploads 127.0.0.1:8080 {
        header_up Host {host}
        header_up X-Real-IP {remote}
        header_up X-Forwarded-For {remote}
        header_up X-Forwarded-Proto {scheme}
        
        # Increase timeouts for large uploads
        timeout 300s
    }
}
```

### Caddy with Load Balancing

```caddy
fog.example.com {
    tls your-email@example.com
    
    # Load balancing
    reverse_proxy 127.0.0.1:8080 127.0.0.1:8081 127.0.0.1:8082 {
        header_up Host {host}
        header_up X-Real-IP {remote}
        header_up X-Forwarded-For {remote}
        header_up X-Forwarded-Proto {scheme}
        
        # Load balancing method
        lb_policy round_robin
    }
}
```

### Caddy with Custom SSL

```caddy
fog.example.com {
    tls /path/to/cert.pem /path/to/key.pem
    
    reverse_proxy 127.0.0.1:8080 {
        header_up Host {host}
        header_up X-Real-IP {remote}
        header_up X-Forwarded-For {remote}
        header_up X-Forwarded-Proto {scheme}
    }
}
```

## Docker Compose Examples

### Complete Traefik Setup

```yaml
version: '3.8'

services:
  traefik:
    image: traefik:v3.0
    command:
      - --api.dashboard=true
      - --api.insecure=true
      - --providers.docker=true
      - --providers.docker.exposedbydefault=false
      - --entrypoints.web.address=:80
      - --entrypoints.websecure.address=:443
      - --certificatesresolvers.letsencrypt.acme.tlschallenge=true
      - --certificatesresolvers.letsencrypt.acme.email=your-email@example.com
      - --certificatesresolvers.letsencrypt.acme.storage=/letsencrypt/acme.json
    ports:
      - "80:80"
      - "443:443"
      - "8080:8080"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./letsencrypt:/letsencrypt
    networks:
      - fog-network

  fog-server:
    image: ghcr.io/88fingerslukee/fog-docker:latest
    environment:
      - FOG_WEB_HOST=fog.example.com
      - FOG_HTTP_PROTOCOL=https
      - FOG_INTERNAL_HTTPS_ENABLED=false
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.fog.rule=Host(`fog.example.com`)"
      - "traefik.http.routers.fog.entrypoints=websecure"
      - "traefik.http.routers.fog.tls.certresolver=letsencrypt"
      - "traefik.http.services.fog.loadbalancer.server.port=80"
    networks:
      - fog-network

networks:
  fog-network:
    driver: bridge
```

### Nginx with FOG Docker

```yaml
services:
  nginx:
    image: nginx:alpine
    ports:
      - "${FOG_APACHE_EXPOSED_PORT:-80}:80"
      - "${FOG_APACHE_EXPOSED_SSL_PORT:-443}:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
      - ./ssl:/etc/nginx/ssl:ro
    depends_on:
      - fog-server
    networks:
      - fog-network

  fog-server:
    image: ghcr.io/88fingerslukee/fog-docker:latest
    environment:
      - FOG_WEB_HOST=${FOG_WEB_HOST}
      - FOG_HTTP_PROTOCOL=${FOG_HTTP_PROTOCOL}
      - FOG_INTERNAL_HTTPS_ENABLED=${FOG_INTERNAL_HTTPS_ENABLED}
      - FOG_APACHE_EXPOSED_PORT=${FOG_APACHE_EXPOSED_PORT}
    expose:
      - "80"
    networks:
      - fog-network

networks:
  fog-network:
    driver: bridge
```

**Required .env variables:**
```bash
FOG_WEB_HOST=fog.example.com
FOG_HTTP_PROTOCOL=https
FOG_INTERNAL_HTTPS_ENABLED=false
FOG_APACHE_EXPOSED_PORT=80
FOG_APACHE_EXPOSED_SSL_PORT=443
```

## Testing and Verification

### Test SSL Configuration

```bash
# Test SSL certificate
openssl s_client -connect fog.example.com:443 -servername fog.example.com

# Test HTTP to HTTPS redirect
curl -I http://fog.example.com

# Test HTTPS access
curl -I https://fog.example.com/fog/
```

### Test FOG Functionality

```bash
# Test web interface
curl -I https://fog.example.com/fog/

# Test HTTPBoot files
curl -I https://fog.example.com/fog/service/ipxe/ipxe.efi

# Test FOG client downloads
curl -I https://fog.example.com/fog/client/download.php
```

### Monitor Reverse Proxy

```bash
# Check reverse proxy logs
docker logs traefik
docker logs nginx
docker logs apache

# Check FOG server logs
docker logs fog-server

# Monitor performance
htop
docker stats
```

## Troubleshooting

### Common Issues

#### SSL Certificate Issues

**Symptoms**: SSL errors or certificate warnings
**Solutions**:
1. **Check certificate validity**:
   ```bash
   openssl x509 -in /path/to/cert.pem -text -noout
   ```

2. **Verify certificate chain**
3. **Check certificate renewal**
4. **Verify domain name matches certificate**

#### Proxy Headers Issues

**Symptoms**: FOG shows wrong protocol or IP addresses
**Solutions**:
1. **Check proxy headers** in reverse proxy configuration
2. **Verify X-Forwarded-Proto** is set to "https"
3. **Check X-Forwarded-For** headers
4. **Verify Host header** is passed correctly

#### Large File Upload Issues

**Symptoms**: Image uploads fail or timeout
**Solutions**:
1. **Increase timeout values** in reverse proxy
2. **Check client_max_body_size** (Nginx)
3. **Verify ProxyTimeout** settings (Apache)
4. **Check FOG upload limits**

### Debug Commands

```bash
# Check reverse proxy status
docker ps | grep -E "(traefik|nginx|apache)"

# Check FOG server status
docker ps | grep fog-server

# Test connectivity
curl -v https://fog.example.com/fog/

# Check SSL certificate
openssl s_client -connect fog.example.com:443

# Monitor logs
docker logs -f traefik
docker logs -f fog-server
```

## Security Considerations

### SSL/TLS Security

1. **Use strong SSL/TLS configurations**
2. **Enable HSTS headers**
3. **Use modern cipher suites**
4. **Regular certificate renewal**

### Access Control

1. **Implement rate limiting**
2. **Use IP whitelisting** if needed
3. **Enable access logging**
4. **Monitor for suspicious activity**

### Network Security

1. **Use private networks** for internal communication
2. **Implement firewall rules**
3. **Monitor network traffic**
4. **Use VPN** for remote access

## Performance Optimization

### Caching

```nginx
# Nginx caching for static content
location ~* \.(css|js|png|jpg|jpeg|gif|ico|svg)$ {
    expires 1y;
    add_header Cache-Control "public, immutable";
}
```

### Compression

```nginx
# Enable gzip compression
gzip on;
gzip_vary on;
gzip_min_length 1024;
gzip_types text/plain text/css application/json application/javascript text/xml application/xml;
```

### Load Balancing

1. **Use multiple FOG instances** for high availability
2. **Implement health checks**
3. **Use sticky sessions** if needed
4. **Monitor backend health**

## Next Steps

After setting up reverse proxy:

1. **[SSL/HTTPS Setup](ssl-https.md)** - Verify SSL configuration
2. **[Network Boot Setup](network-boot.md)** - Test HTTPBoot with HTTPS
3. **[Troubleshooting Guide](troubleshooting.md)** - Address any issues

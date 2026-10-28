---
layout: default
title: SSL/HTTPS Setup
nav_order: 5
description: "Configure SSL certificates and HTTPS for FOG Docker"
permalink: /ssl-https
---

# SSL/HTTPS Configuration

This guide covers certificate files and mounts. **Start with [TLS Modes](tls-modes.md)** — set `FOG_TLS_MODE` once (`standard`, `reverse-proxy`, `mounted-certs`, etc.) instead of juggling `FOG_HTTP_PROTOCOL` and `FOG_INTERNAL_HTTPS_ENABLED`.

## Overview

FOG client certificates are always generated automatically for client authentication, regardless of Apache SSL configuration.

## Configuration by mode

| Goal | `FOG_TLS_MODE` | Certificate |
|------|----------------|-------------|
| Default direct access | `standard` | Auto self-signed in container |
| Your certs on Apache | `mounted-certs` or `public-cert` | Mount into `/opt/fog/snapins/ssl/` |
| Traefik / external TLS | `reverse-proxy` | Certs on the proxy, not in container |
| No TLS | `http-only` | None |

### Mounted certificates

```bash
FOG_TLS_MODE=mounted-certs
FOG_APACHE_SSL_CERT_FILE=fullchain.pem
FOG_APACHE_SSL_KEY_FILE=privkey.pem
```

```bash
# docker-compose.yml volumes:
- /path/to/certs:/opt/fog/snapins/ssl:ro
```

### Self-signed (default)

```bash
FOG_TLS_MODE=standard
# FOG_APACHE_SSL_CN defaults to FOG_WEB_HOST if unset
FOG_CERT_SAN=shortname,alt1.domain.com,192.168.1.10
```

Browse `https://your-host/fog/management/` and accept the certificate warning. Netboot uses HTTP to `boot.php` (see [TLS Modes](tls-modes.md)).

Self-signed Apache certs include **`digitalSignature`** and **`keyEncipherment`** so current Chrome/Edge accept TLS 1.3 (avoids **`ERR_SSL_KEY_USAGE_INCOMPATIBLE`**). After upgrading fog-docker, recreate the container so managed **`server.crt`** is regenerated (fingerprint / generation version change).

### Reverse proxy

See [Reverse Proxy Setup](reverse-proxy.md). Use `FOG_TLS_MODE=reverse-proxy` — do not browse plain HTTP to the container for admin login.

## FOG Client Certificates

**Automatic Generation**: FOG client certificates are always generated automatically for client authentication, regardless of your Apache SSL configuration. These certificates are used for:

- **FOG Client Authentication**: Required for FOG client installation and communication
- **Secure Communication**: Ensures encrypted communication between FOG clients and server
- **Certificate Chain**: Proper CA certificate chain for client trust

**Certificate Locations**:
- **CA Certificate**: `/var/www/html/fog/management/other/ca.cert.der` and `ca.cert.pem`
- **Server Public Certificate**: `/var/www/html/fog/management/other/ssl/srvpublic.crt`
- **Private Keys**: `/opt/fog/snapins/ssl/` (internal use only)

**Subject alternative names**: **`FOG_WEB_HOST`** is always placed on **`srvpublic.crt`** (as DNS or IP SAN). Add more names with **`FOG_CERT_SAN`** (comma-separated hostnames and/or IPs) — used for **FOG Agent** enrollment, legacy FOG Client, and self-signed **Apache** HTTPS when the container generates certs.

**Changing names**: On each container start, fog-docker stores a fingerprint of **`FOG_WEB_HOST`**, **`FOG_APACHE_SSL_CN`**, and **`FOG_CERT_SAN`** under **`/opt/fog/config/fog-auto-cert.sha256`** (persist **`./config`** on the host). If those values change and you recreate/restart the container, **`srvpublic.crt`** is regenerated automatically. Self-signed Apache certs are regenerated only when fog-docker created them (not when you mount your own **`fullchain.pem`** / **`privkey.pem`**). The first boot after upgrade may only **record** a fingerprint if an old **`srvpublic.crt`** already exists — change a cert-related env var once to force regen with the new SAN logic.

**Deprecated**: **`FOG_APACHE_SSL_SAN`** is accepted as a fallback with a startup warning; use **`FOG_CERT_SAN`** instead.

## Reverse Proxy Setup

### Nginx Configuration Example

```nginx
server {
    listen 443 ssl http2;
    server_name fog.example.com;
    
    ssl_certificate /path/to/your/cert.pem;
    ssl_certificate_key /path/to/your/key.pem;
    
    location / {
        proxy_pass http://fog-server:80;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### Apache Configuration Example

```apache
<VirtualHost *:443>
    ServerName fog.example.com
    
    SSLEngine on
    SSLCertificateFile /path/to/your/cert.pem
    SSLCertificateKeyFile /path/to/your/key.pem
    
    ProxyPreserveHost On
    ProxyPass / http://fog-server:80/
    ProxyPassReverse / http://fog-server:80/
</VirtualHost>
```

## Let's Encrypt Integration

### Using Certbot with Nginx

```bash
# Install certbot
sudo apt install certbot python3-certbot-nginx

# Obtain certificate
sudo certbot --nginx -d fog.example.com

# Auto-renewal
sudo crontab -e
# Add: 0 12 * * * /usr/bin/certbot renew --quiet
```

### Using Certbot with Apache

```bash
# Install certbot
sudo apt install certbot python3-certbot-apache

# Obtain certificate
sudo certbot --apache -d fog.example.com

# Auto-renewal
sudo crontab -e
# Add: 0 12 * * * /usr/bin/certbot renew --quiet
```

## Docker Compose with SSL

### External Certificates

```yaml
services:
  fog-server:
    image: ghcr.io/88fingerslukee/fog-docker:latest
    environment:
      - FOG_TLS_MODE=${FOG_TLS_MODE:-mounted-certs}
      - FOG_APACHE_SSL_CERT_FILE=${FOG_APACHE_SSL_CERT_FILE}
      - FOG_APACHE_SSL_KEY_FILE=${FOG_APACHE_SSL_KEY_FILE}
    volumes:
      - /path/to/certs:/opt/fog/snapins/ssl:ro
```

**Required .env variables:**
```bash
FOG_TLS_MODE=mounted-certs
FOG_APACHE_SSL_CERT_FILE=fullchain.pem
FOG_APACHE_SSL_KEY_FILE=privkey.pem
```

### Self-signed Certificates

```yaml
services:
  fog-server:
    image: ghcr.io/88fingerslukee/fog-docker:latest
    environment:
      - FOG_TLS_MODE=${FOG_TLS_MODE:-standard}
      - FOG_APACHE_SSL_CN=${FOG_APACHE_SSL_CN}
      - FOG_CERT_SAN=${FOG_CERT_SAN}
```

**Required .env variables:**
```bash
FOG_TLS_MODE=standard
FOG_APACHE_SSL_CN=fog.example.com
FOG_CERT_SAN=shortname,alt1.example.com,192.168.1.10
```

## Testing SSL Configuration

### Test HTTPS Access

```bash
# Test web interface
curl -I https://fog.example.com/fog/

# Test HTTPBoot files
curl -I https://fog.example.com/fog/service/ipxe/ipxe.efi

# Test FOG client certificates
curl -I https://fog.example.com/fog/management/other/ca.cert.der
curl -I https://fog.example.com/fog/management/other/ssl/srvpublic.crt
```

### Test Certificate Chain

```bash
# Check certificate details
openssl s_client -connect fog.example.com:443 -servername fog.example.com

# Verify certificate chain
openssl verify -CAfile /path/to/ca.pem /path/to/cert.pem
```

## Troubleshooting

### Common SSL Issues

1. **Certificate not found**
   - Check file paths in `FOG_APACHE_SSL_CERT_FILE` and `FOG_APACHE_SSL_KEY_FILE`
   - Verify volume mounts are correct
   - Check file permissions

2. **SSL handshake failed**
   - Verify certificate and key match
   - Check certificate validity dates
   - Ensure proper certificate chain

3. **Mixed content warnings**
   - Use an HTTPS TLS mode and browse via `https://` — see [TLS Modes](tls-modes.md)
   - Check for hardcoded HTTP URLs in configuration

4. **FOG client certificate issues**
   - Verify CA certificate is accessible at `/fog/management/other/ca.cert.der`
   - Check server public certificate at `/fog/management/other/ssl/srvpublic.crt`
   - Ensure proper certificate chain

### Debug SSL Configuration

```bash
# Check Apache SSL configuration
docker exec fog-server apache2ctl -S

# Check SSL modules
docker exec fog-server apache2ctl -M | grep ssl

# Check certificate files
docker exec fog-server ls -la /opt/fog/snapins/ssl/

# Check FOG client certificates
docker exec fog-server ls -la /var/www/html/fog/management/other/
```

## Security Best Practices

1. **Use strong certificates**: 2048-bit RSA or 256-bit ECDSA
2. **Enable HSTS**: Add `Strict-Transport-Security` header
3. **Use secure ciphers**: Disable weak SSL/TLS ciphers
4. **Regular certificate renewal**: Set up automatic renewal
5. **Monitor certificate expiration**: Set up alerts for certificate expiry

## Next Steps

After SSL configuration:

1. **[Network Boot Setup](network-boot.md)** - Configure HTTPBoot with HTTPS
2. **[Troubleshooting Guide](troubleshooting.md)** - Common issues and solutions
3. **[Configuration Guide](configuration.md)** - Additional FOG configuration

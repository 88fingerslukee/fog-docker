# SSL/HTTPS Configuration

This guide covers configuring SSL/HTTPS for FOG Docker in various scenarios.

## Overview

FOG Docker supports multiple SSL configurations to accommodate different deployment scenarios. **Important**: FOG client certificates are always generated automatically for client authentication, regardless of your Apache SSL configuration.

## Configuration Options

### Option 1: External Certificates (Recommended)

```bash
FOG_INTERNAL_HTTPS_ENABLED=true
FOG_HTTP_PROTOCOL=https
FOG_APACHE_SSL_CERT_FILE=fullchain.pem
FOG_APACHE_SSL_KEY_FILE=privkey.pem
```

Mount your certificates:
```bash
# Add to docker-compose.yml volumes:
- /path/to/certs:/opt/fog/snapins/ssl:ro
```

### Option 2: Self-signed Certificates

```bash
FOG_INTERNAL_HTTPS_ENABLED=true
FOG_HTTP_PROTOCOL=https
FOG_APACHE_SSL_CN=192.168.1.100
FOG_APACHE_SSL_SAN=alt1.domain.com,alt2.domain.com
```

### Option 3: Reverse Proxy (No SSL in Container)

```bash
FOG_INTERNAL_HTTPS_ENABLED=false
FOG_HTTP_PROTOCOL=https
```

### Option 4: HTTP Only (Default)

```bash
FOG_INTERNAL_HTTPS_ENABLED=false
FOG_HTTP_PROTOCOL=http
```

## FOG Client Certificates

**Automatic Generation**: FOG client certificates are always generated automatically for client authentication, regardless of your Apache SSL configuration. These certificates are used for:

- **FOG Client Authentication**: Required for FOG client installation and communication
- **Secure Communication**: Ensures encrypted communication between FOG clients and server
- **Certificate Chain**: Proper CA certificate chain for client trust

**Certificate Locations**:
- **CA Certificate**: `/var/www/html/fog/management/other/ca.cert.der` and `ca.cert.pem`
- **Server Public Certificate**: `/var/www/html/fog/management/other/ssl/srvpublic.crt`
- **Private Keys**: `/opt/fog/snapins/ssl/` (internal use only)

**No Configuration Required**: These certificates are generated automatically during container startup and require no additional configuration.

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
      - FOG_INTERNAL_HTTPS_ENABLED=${FOG_INTERNAL_HTTPS_ENABLED}
      - FOG_HTTP_PROTOCOL=${FOG_HTTP_PROTOCOL}
      - FOG_APACHE_SSL_CERT_FILE=${FOG_APACHE_SSL_CERT_FILE}
      - FOG_APACHE_SSL_KEY_FILE=${FOG_APACHE_SSL_KEY_FILE}
    volumes:
      - /path/to/certs:/opt/fog/snapins/ssl:ro
```

**Required .env variables:**
```bash
FOG_INTERNAL_HTTPS_ENABLED=true
FOG_HTTP_PROTOCOL=https
FOG_APACHE_SSL_CERT_FILE=fullchain.pem
FOG_APACHE_SSL_KEY_FILE=privkey.pem
```

### Self-signed Certificates

```yaml
services:
  fog-server:
    image: ghcr.io/88fingerslukee/fog-docker:latest
    environment:
      - FOG_INTERNAL_HTTPS_ENABLED=${FOG_INTERNAL_HTTPS_ENABLED}
      - FOG_HTTP_PROTOCOL=${FOG_HTTP_PROTOCOL}
      - FOG_APACHE_SSL_CN=${FOG_APACHE_SSL_CN}
      - FOG_APACHE_SSL_SAN=${FOG_APACHE_SSL_SAN}
```

**Required .env variables:**
```bash
FOG_INTERNAL_HTTPS_ENABLED=true
FOG_HTTP_PROTOCOL=https
FOG_APACHE_SSL_CN=fog.example.com
FOG_APACHE_SSL_SAN=alt1.example.com,alt2.example.com
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
   - Set `FOG_HTTP_PROTOCOL=https`
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

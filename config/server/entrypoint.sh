#!/bin/bash
set -e

FOG_VERSION=${FOG_VERSION:-unknown}

echo "=========================================="
echo "FOG Project Server v$FOG_VERSION with Supervisor"
echo "=========================================="

# Environment variables
DB_HOST=${FOG_DB_HOST:-localhost}
DB_PORT=${FOG_DB_PORT:-3307}
DB_NAME=${FOG_DB_NAME:-fog}
DB_USER=${FOG_DB_USER:-fogmaster}
DB_PASS=${FOG_DB_PASS:-fogmaster123}
FOG_MULTICAST_INTERFACE=${FOG_MULTICAST_INTERFACE:-eth0}
FOG_WEB_ROOT=${FOG_WEB_ROOT:-/fog}
FOG_APACHE_PORT=${FOG_APACHE_PORT:-8080}
FOG_APACHE_SSL_PORT=${FOG_APACHE_SSL_PORT:-8443}

FOG_TFTP_HOST=${FOG_TFTP_HOST:-localhost}
FOG_NFS_HOST=${FOG_NFS_HOST:-localhost}
FOG_FTP_HOST=${FOG_FTP_HOST:-localhost}
FOG_USERNAME=${FOG_USERNAME:-fogproject}
FOG_PASSWORD=${FOG_PASSWORD:-fogftp123}
FOG_SSL_PATH=${FOG_SSL_PATH:-/opt/fog/snapins/ssl}
FOG_HTTPS_ENABLED=${FOG_HTTPS_ENABLED:-false}
FOG_TIMEZONE=${FOG_TIMEZONE:-UTC}

# Wait for database to be ready
echo "Waiting for database connection..."
until mysql -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USER" -p"$DB_PASS" -e "SELECT 1" >/dev/null 2>&1; do
    echo "Database not ready, waiting..."
    sleep 2
done
echo "✓ Database connection established"

# Check if we need to update FOG database schema
echo "Checking FOG database schema version..."
if mysql -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USER" -p"$DB_PASS" -D"$DB_NAME" -e "SHOW TABLES LIKE 'globalSettings'" >/dev/null 2>&1; then
    # Database exists, check current schema version
    CURRENT_SCHEMA=$(mysql -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USER" -p"$DB_PASS" -D"$DB_NAME" -s -N -e "SELECT settingValue FROM globalSettings WHERE settingKey = 'FOG_SCHEMA';" 2>/dev/null || echo "0")
    EXPECTED_SCHEMA="273"  # FOG 1.5.10.1673 schema version
    
    if [ "$CURRENT_SCHEMA" != "$EXPECTED_SCHEMA" ]; then
        echo "FOG schema version mismatch detected (DB: $CURRENT_SCHEMA, Expected: $EXPECTED_SCHEMA)"
        echo "Database schema will be updated on first web access"
    else
        echo "✓ FOG database schema is up to date (version: $EXPECTED_SCHEMA)"
        
        # Update FOG_VERSION in database if it's different
        CURRENT_VERSION=$(mysql -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USER" -p"$DB_PASS" -D"$DB_NAME" -s -N -e "SELECT settingValue FROM globalSettings WHERE settingKey = 'FOG_VERSION';" 2>/dev/null || echo "")
        if [ "$CURRENT_VERSION" != "$FOG_VERSION" ]; then
            echo "Updating FOG_VERSION in database from $CURRENT_VERSION to $FOG_VERSION"
            mysql -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USER" -p"$DB_PASS" -D"$DB_NAME" -e "UPDATE globalSettings SET settingValue = '$FOG_VERSION' WHERE settingKey = 'FOG_VERSION';" 2>/dev/null || echo "Failed to update FOG_VERSION"
        fi
    fi
else
    echo "FOG database not found, will be initialized on first web access"
fi

# Copy/update FOG web files
if [ -d "/opt/fogproject/packages/web" ]; then
    echo "Updating FOG web files..."
    cp -r /opt/fogproject/packages/web/* /var/www/html/fog/
    chown -R www-data:www-data /var/www/html/fog
    echo "✓ FOG web files updated"
    # Create symlink to match baremetal installer behavior
    if [ ! -L "/var/www/html/fog/fog" ]; then
        ln -s /var/www/html/fog /var/www/html/fog/fog
        echo "✓ Symlink /var/www/html/fog/fog -> /var/www/html/fog created"
    fi
fi

# Copy/update TFTP boot files
if [ -d "/opt/fogproject/packages/tftp" ]; then
    echo "Updating TFTP boot files..."
    cp -a /opt/fogproject/packages/tftp/. /tftpboot/
    chown -R www-data:www-data /tftpboot
    echo "✓ TFTP boot files updated"
fi

# Copy snapins if persistent volume is empty and source exists
if [ -d "/opt/fogproject/packages/snapins" ] && [ -z "$(ls -A /opt/fog/snapins 2>/dev/null)" ]; then
    echo "Populating FOG snapins..."
    cp -a /opt/fogproject/packages/snapins/. /opt/fog/snapins/
    chown -R www-data:www-data /opt/fog/snapins
    echo "✓ FOG snapins installed"
fi

# Ensure the config directory exists
mkdir -p /var/www/html/fog/lib/fog

# Process FOG configuration template
echo "Processing FOG configuration for FOG v$FOG_VERSION..."
sed -e "s|{{DB_HOST}}|$DB_HOST|g" \
    -e "s|{{DB_PORT}}|$DB_PORT|g" \
    -e "s|{{DB_NAME}}|$DB_NAME|g" \
    -e "s|{{DB_USER}}|$DB_USER|g" \
    -e "s|{{DB_PASS}}|$DB_PASS|g" \
    -e "s|{{FOG_TFTP_HOST}}|$FOG_TFTP_HOST|g" \
    -e "s|{{FOG_NFS_HOST}}|$FOG_NFS_HOST|g" \
    -e "s|{{FOG_FTP_HOST}}|$FOG_FTP_HOST|g" \
    -e "s|{{FOG_MULTICAST_INTERFACE}}|$FOG_MULTICAST_INTERFACE|g" \
    -e "s|{{FOG_WEB_ROOT}}|$FOG_WEB_ROOT|g" \
    -e "s|{{FOG_WEB_HOST}}|$FOG_WEB_HOST|g" \
    -e "s|{{FOG_USERNAME}}|$FOG_USERNAME|g" \
    -e "s|{{FOG_PASSWORD}}|$FOG_PASSWORD|g" \
    -e "s|{{FOG_SSL_PATH}}|$FOG_SSL_PATH|g" \
    -e "s|{{FOG_HTTPS_ENABLED}}|$FOG_HTTPS_ENABLED|g" \
    -e "s|{{FOG_TIMEZONE}}|$FOG_TIMEZONE|g" \
    -e "s|{{FOG_VERSION}}|$FOG_VERSION|g" \
    /fog-config.php > /var/www/html/fog/lib/fog/config.class.php

echo "✓ FOG configuration processed"

# Check if FOG database schema exists before updating settings
if mysql -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USER" -p"$DB_PASS" -D"$DB_NAME" -e "SELECT 1 FROM globalSettings LIMIT 1" >/dev/null 2>&1; then
    
    # Always update global settings in database with current environment values
    echo "DEBUG: Updating database with FOG_WEB_HOST=$FOG_WEB_HOST"
    mysql -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USER" -p"$DB_PASS" -D"$DB_NAME" << EOF
UPDATE globalSettings SET settingValue = '$FOG_WEB_HOST' WHERE settingKey = 'FOG_WEB_HOST';
UPDATE globalSettings SET settingValue = '$FOG_WEB_ROOT' WHERE settingKey = 'FOG_WEB_ROOT';
UPDATE globalSettings SET settingValue = '$FOG_TFTP_HOST' WHERE settingKey = 'FOG_TFTP_HOST';
UPDATE globalSettings SET settingValue = '$FOG_NFS_HOST' WHERE settingKey = 'FOG_NFS_HOST';
UPDATE globalSettings SET settingValue = '$FOG_MULTICAST_INTERFACE' WHERE settingKey = 'FOG_MULTICAST_INTERFACE';
UPDATE globalSettings SET settingValue = '$FOG_USERNAME' WHERE settingKey = 'FOG_TFTP_FTP_USERNAME';
UPDATE globalSettings SET settingValue = '$FOG_PASSWORD' WHERE settingKey = 'FOG_TFTP_FTP_PASSWORD';
UPDATE globalSettings SET settingValue = '$FOG_USERNAME' WHERE settingKey = 'FOG_NFS_FTP_USERNAME';
UPDATE globalSettings SET settingValue = '$FOG_PASSWORD' WHERE settingKey = 'FOG_NFS_FTP_PASSWORD';
UPDATE globalSettings SET settingValue = '$FOG_BOOTFILENAME' WHERE settingKey = 'FOG_DHCP_BOOTFILENAME';
UPDATE nfsGroupMembers SET ngmHostname = '$FOG_WEB_HOST', ngmWebroot = '$FOG_WEB_ROOT', ngmInterface = '$FOG_MULTICAST_INTERFACE' WHERE ngmID = 1;
EOF
    echo "✓ Updated FOG database settings with current environment values"
    echo "DEBUG: Verifying FOG_WEB_HOST in database:"
    mysql -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USER" -p"$DB_PASS" -D"$DB_NAME" -e "SELECT settingValue FROM globalSettings WHERE settingKey = 'FOG_WEB_HOST';"
    echo "✓ FOG_WEB_HOST: $FOG_WEB_HOST"
    echo "✓ FOG_WEB_ROOT: $FOG_WEB_ROOT"
    echo "✓ FOG_TFTP_HOST: $FOG_TFTP_HOST"
    echo "✓ Storage Node Hostname: $FOG_WEB_HOST"
    echo "✓ Storage Node Webroot: $FOG_WEB_ROOT"
    echo "✓ FOG_NFS_HOST: $FOG_NFS_HOST"
    echo "✓ FOG_MULTICAST_INTERFACE: $FOG_MULTICAST_INTERFACE"
    echo "✓ FOG_TFTP_FTP_USERNAME: $FOG_USERNAME"
    echo "✓ FOG_TFTP_FTP_PASSWORD: [HIDDEN]"
    echo "✓ FOG_NFS_FTP_USERNAME: $FOG_USERNAME"
    echo "✓ FOG_NFS_FTP_PASSWORD: [HIDDEN]"
    echo "✓ FOG_DHCP_BOOTFILENAME: $FOG_BOOTFILENAME"
    echo "✓ Storage node configured with hostname: $FOG_WEB_HOST"
else
    echo "⚠ FOG database schema not found. Database will be initialized when you access the web interface."
    echo "   Access: https://$FOG_WEB_HOST${FOG_WEB_ROOT}/management/"
fi

# Set up FOG web directory structure
mkdir -p /var/www/html/fog/management /var/www/html/fog/service /var/www/html/fog/commons
mkdir -p /opt/fog/log /opt/fog/snapins /opt/fog/service
mkdir -p /tftpboot/fog

# Ensure the log directory exists and is writable
mkdir -p /opt/fog/log
chown -R www-data:www-data /opt/fog/log
chmod -R 755 /opt/fog/log

# Set environment variable to skip interface validation in Docker
export FOG_SKIP_INTERFACE_CHECK=1


# Fix resolveHostName typo in PingHosts service (should be resolveHostname)
echo "Fixing resolveHostName typo in PingHosts service..."
sed -i 's/self::resolveHostName(/self::resolveHostname(/g' /var/www/html/fog/lib/service/pinghosts.class.php
echo "✓ resolveHostName typo fixed"

# Set correct permissions
chown -R www-data:www-data /var/www/html/fog
chown -R www-data:www-data /opt/fog/snapins
chown -R www-data:www-data /opt/fog/log
chmod -R 755 /var/www/html/fog
chmod -R 755 /opt/fog
chmod -R 777 /opt/fog/log

echo "✓ FOG directory structure created"

# Enable Apache modules and configure FOG
echo "Enabling module rewrite."
a2enmod rewrite
echo "To activate the new configuration, you need to run:"
echo "  service apache2 restart"
echo "Enabling module headers."
a2enmod headers
echo "To activate the new configuration, you need to run:"
echo "  service apache2 restart"
echo "Enabling PHP module."
a2enmod php
echo "To activate the new configuration, you need to run:"
echo "  service apache2 restart"

# Configure Apache for FOG
echo "Configuring Apache for FOG..."
sed -e "s|{{FOG_APACHE_PORT}}|$FOG_APACHE_PORT|g" /apache-fog.conf > /etc/apache2/sites-available/000-default.conf
# Process ports.conf template
sed -e "s|{{FOG_APACHE_PORT}}|$FOG_APACHE_PORT|g" \
    -e "s|{{FOG_APACHE_SSL_PORT}}|$FOG_APACHE_SSL_PORT|g" \
    /ports.conf > /etc/apache2/ports.conf
a2ensite 000-default
echo "✓ Apache configured for FOG on port $FOG_APACHE_PORT (SSL: $FOG_APACHE_SSL_PORT)"

# Create default.ipxe file for iPXE chainloading
echo "Creating default.ipxe for iPXE chainloading..."
cat > /tftpboot/default.ipxe << EOF
#!ipxe
set arch \${buildarch}
iseq \${arch} i386 && cpuid --ext 29 && set arch x86_64 ||
params
param mac0 \${net0/mac}
param arch \${arch}
param platform \${platform}
param product \${product}
param manufacturer \${product}
param ipxever \${version}
param filename \${filename}
param sysuuid \${uuid}
isset \${net1/mac} && param mac1 \${net1/mac} || goto bootme
isset \${net2/mac} && param mac2 \${net2/mac} || goto bootme
:bootme
chain https://$FOG_WEB_HOST${FOG_WEB_ROOT}service/ipxe/boot.php##params
EOF
chown www-data:www-data /tftpboot/default.ipxe
chmod 644 /tftpboot/default.ipxe
echo "✓ default.ipxe created for chainloading to $FOG_WEB_HOST"

echo ""
echo "=== FOG PROJECT SERVER v$FOG_VERSION READY ==="
echo ""
echo "FOG Management Portal:"
echo "  https://$FOG_WEB_HOST${FOG_WEB_ROOT}/management/"
echo ""
echo "Default login:"
echo "  Username: fog"
echo "  Password: password"
echo ""
echo "Multicast Interface: $FOG_MULTICAST_INTERFACE"
echo ""

echo "Starting supervisor to manage services..."

# Start supervisor (which will manage Apache and FOG services)
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf 
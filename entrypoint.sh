#!/bin/bash

if [ "$DEBUG" = "true" ] || [ "$DEBUG" = "True" ]; then
    set -x
    set -o functrace
fi
set -e
shopt -s extglob

# Environment variable defaults (following Zulip pattern)
# Database Configuration
DB_HOST="${FOG_DB_HOST:-localhost}"
DB_PORT="${FOG_DB_PORT:-3306}"
DB_NAME="${FOG_DB_NAME:-fog}"
DB_USER="${FOG_DB_USER:-fogmaster}"
DB_PASS="${FOG_DB_PASS:-fogmaster123}"

# Database Migration Configuration
FOG_DB_MIGRATION_ENABLED="${FOG_DB_MIGRATION_ENABLED:-false}"
FOG_DB_MIGRATION_FORCE="${FOG_DB_MIGRATION_FORCE:-false}"

# Network Configuration
# FOG_WEB_HOST is REQUIRED - fail hard if not set
# Can be either an IP address (e.g., 192.168.1.100) or FQDN (e.g., fog.example.com)
if [ -z "$FOG_WEB_HOST" ]; then
    echo "ERROR: FOG_WEB_HOST is required but not set!"
    echo "Please set FOG_WEB_HOST in your .env file or environment variables."
    echo "Examples:"
    echo "  FOG_WEB_HOST=192.168.1.100          (IP address)"
    echo "  FOG_WEB_HOST=fog.example.com        (FQDN)"
    exit 1
fi

FOG_WEB_ROOT="${FOG_WEB_ROOT:-/fog}"
FOG_TFTP_HOST="${FOG_TFTP_HOST:-${FOG_WEB_HOST}}"
FOG_STORAGE_HOST="${FOG_STORAGE_HOST:-${FOG_WEB_HOST}}"
FOG_WOL_HOST="${FOG_WOL_HOST:-${FOG_WEB_HOST}}"
FOG_MULTICAST_INTERFACE="${FOG_MULTICAST_INTERFACE:-eth0}"
FOG_NFS_MODE="${FOG_NFS_MODE:-kernel}"
case "$FOG_NFS_MODE" in
    kernel|unfs3) ;;
    *)
        echo "ERROR: FOG_NFS_MODE must be 'kernel' or 'unfs3' (got '${FOG_NFS_MODE}')."
        exit 1
        ;;
esac

# Apache Configuration
FOG_APACHE_PORT="${FOG_APACHE_PORT:-80}"
FOG_APACHE_SSL_PORT="${FOG_APACHE_SSL_PORT:-443}"
FOG_INTERNAL_HTTPS_ENABLED="${FOG_INTERNAL_HTTPS_ENABLED:-true}"
FOG_HTTP_PROTOCOL="${FOG_HTTP_PROTOCOL:-https}"

# FTP Configuration
FOG_USER="${FOG_USER:-fogproject}"
FOG_PASS="${FOG_PASS:-fogftp123}"
FOG_FTP_PASV_MIN_PORT="${FOG_FTP_PASV_MIN_PORT:-21100}"
FOG_FTP_PASV_MAX_PORT="${FOG_FTP_PASV_MAX_PORT:-21110}"

# SSL Configuration
FOG_APACHE_SSL_CERT_FILE="${FOG_APACHE_SSL_CERT_FILE:-server.crt}"
FOG_APACHE_SSL_KEY_FILE="${FOG_APACHE_SSL_KEY_FILE:-server.key}"
FOG_APACHE_SSL_CN="${FOG_APACHE_SSL_CN:-${FOG_WEB_HOST}}"
FOG_APACHE_SSL_SAN="${FOG_APACHE_SSL_SAN:-}"

# Secure Boot Configuration
FOG_SECURE_BOOT_ENABLED="${FOG_SECURE_BOOT_ENABLED:-false}"
FOG_SECURE_BOOT_KEYS_DIR="${FOG_SECURE_BOOT_KEYS_DIR:-/opt/fog/secure-boot/keys}"
FOG_SECURE_BOOT_CERT_DIR="${FOG_SECURE_BOOT_CERT_DIR:-/opt/fog/secure-boot/certs}"
FOG_SECURE_BOOT_SHIM_DIR="${FOG_SECURE_BOOT_SHIM_DIR:-/opt/fog/secure-boot/shim}"
FOG_SECURE_BOOT_MOK_IMG="${FOG_SECURE_BOOT_MOK_IMG:-/opt/fog/secure-boot/mok-certs.img}"

# DHCP Configuration
FOG_DHCP_ENABLED="${FOG_DHCP_ENABLED:-false}"
FOG_DHCP_SUBNET="${FOG_DHCP_SUBNET:-192.168.1.0}"
FOG_DHCP_NETMASK="${FOG_DHCP_NETMASK:-255.255.255.0}"
FOG_DHCP_ROUTER="${FOG_DHCP_ROUTER:-192.168.1.1}"
FOG_DHCP_DOMAIN_NAME="${FOG_DHCP_DOMAIN_NAME:-fog.local}"
FOG_DHCP_DEFAULT_LEASE_TIME="${FOG_DHCP_DEFAULT_LEASE_TIME:-600}"
FOG_DHCP_MAX_LEASE_TIME="${FOG_DHCP_MAX_LEASE_TIME:-7200}"
FOG_DHCP_START_RANGE="${FOG_DHCP_START_RANGE:-192.168.1.100}"
FOG_DHCP_END_RANGE="${FOG_DHCP_END_RANGE:-192.168.1.200}"
# DHCP bootfile defaults matching FOG's native configuration
# Legacy/BIOS (Arch:00000): undionly.kkpxe
FOG_DHCP_BOOTFILE_BIOS="${FOG_DHCP_BOOTFILE_BIOS:-undionly.kkpxe}"
# UEFI-32 (Arch:00002, 00006): i386-efi/snponly.efi
FOG_DHCP_BOOTFILE_UEFI32="${FOG_DHCP_BOOTFILE_UEFI32:-i386-efi/snponly.efi}"
# UEFI-64 (Arch:00007, 00008, 00009, plus SURFACE-PRO-4, Apple-Intel-Netboot): snponly.efi
FOG_DHCP_BOOTFILE_UEFI64="${FOG_DHCP_BOOTFILE_UEFI64:-snponly.efi}"
# UEFI-ARM64 (Arch:00011): arm64-efi/snponly.efi
FOG_DHCP_BOOTFILE_ARM64="${FOG_DHCP_BOOTFILE_ARM64:-arm64-efi/snponly.efi}"
# Legacy variable for backward compatibility (maps to UEFI64)
FOG_DHCP_BOOTFILE_UEFI="${FOG_DHCP_BOOTFILE_UEFI:-${FOG_DHCP_BOOTFILE_UEFI64}}"
FOG_DHCP_DNS="${FOG_DHCP_DNS:-8.8.8.8}"

# FOG Version
FOG_VERSION="${FOG_VERSION:-stable}"

# Debug Configuration
DEBUG="${DEBUG:-false}"
FORCE_FIRST_START_INIT="${FORCE_FIRST_START_INIT:-false}"

# Timezone Configuration
TZ="${TZ:-UTC}"

# Force First Start Init (for debugging)
FORCE_FIRST_START_INIT="${FORCE_FIRST_START_INIT:-false}"

# Configuration file paths (FOG_CONFIG_FILE / FOG_SYSTEM_FILE resolved by resolveFOGLayout)
FOG_CONFIG_FILE="/var/www/html/fog/lib/fog/config.class.php"
FOG_SYSTEM_FILE="/var/www/html/fog/lib/fog/system.class.php"
FOG_LAYOUT="1.5"
APACHE_CONFIG_FILE="/etc/apache2/sites-available/fog.conf"
TFTP_CONFIG_FILE="/etc/default/tftpd-hpa"
NFS_CONFIG_FILE="/etc/exports"
FTP_CONFIG_FILE="/etc/vsftpd.conf"
DHCP_CONFIG_FILE="/etc/dhcp/dhcpd.conf"

# FOG 1.5 keeps config/system under lib/fog/; 1.6+ uses commons/ + src/Base/System.php.
resolveFOGLayout() {
    if [ -f "/var/www/html/fog/src/Base/System.php" ]; then
        FOG_LAYOUT="1.6"
        FOG_CONFIG_FILE="/var/www/html/fog/commons/config.class.php"
        FOG_SYSTEM_FILE="/var/www/html/fog/src/Base/System.php"
    else
        FOG_LAYOUT="1.5"
        FOG_CONFIG_FILE="/var/www/html/fog/lib/fog/config.class.php"
        FOG_SYSTEM_FILE="/var/www/html/fog/lib/fog/system.class.php"
    fi
}

# BEGIN Configuration Functions
setConfigurationValue() {
    if [ -z "$1" ]; then
        echo "No KEY given for setConfigurationValue."
        return 1
    fi
    if [ -z "$3" ]; then
        echo "No FILE given for setConfigurationValue."
        return 1
    fi
    local KEY="$1"
    local VALUE="$2"
    local FILE="$3"
    local TYPE="$4"
    
    if [ -z "$TYPE" ]; then
        case "$VALUE" in
            [Tt][Rr][Uu][Ee]|[Ff][Aa][Ll][Ss][Ee]|[Nn]one)
                TYPE="bool"
                ;;
            [0-9]*)
                TYPE="integer"
                ;;
            [\[\(]*[\]\)])
                TYPE="array"
                ;;
            *)
                TYPE="string"
                ;;
        esac
    fi
    
    case "$TYPE" in
        emptyreturn)
            if [ -z "$VALUE" ]; then
                return 0
            fi
            ;;
        literal)
            VALUE="$KEY"
            ;;
        bool|boolean|int|integer|array)
            VALUE="$KEY = $VALUE"
            ;;
        string|*)
            VALUE="$KEY = '${VALUE//\'/\'}'"
            ;;
    esac
    echo "$VALUE" >> "$FILE"
    echo "Setting key \"$KEY\", type \"$TYPE\" in file \"$FILE\"."
}

prepareDirectories() {
    echo "Preparing directories and linking persistent data..."
    
    # Check for mount transitions and provide guidance
    checkMountTransitions
    
    # Set proper ownership
    chown -R www-data:www-data /var/www/html/fog
    
    # Set proper permissions for FOG services to write to log directory
    chown -R www-data:www-data /opt/fog/log/
    
    # Ensure /images directory exists
    mkdir -p /images
    
    # Ensure /images/dev directory exists (required for image capture)
    mkdir -p /images/dev
    
    # Create .mntcheck files if they don't exist (used by FOG to verify NFS mounts)
    if [ ! -f /images/.mntcheck ]; then
        touch /images/.mntcheck
        echo "Created /images/.mntcheck"
    fi
    
    if [ ! -f /images/dev/.mntcheck ]; then
        touch /images/dev/.mntcheck
        echo "Created /images/dev/.mntcheck"
    fi
    
    # Create postdownloadscripts directory and fog.postdownload file (matching FOG's configureStorage)
    mkdir -p /images/postdownloadscripts
    if [ ! -f /images/postdownloadscripts/fog.postdownload ]; then
        cat > /images/postdownloadscripts/fog.postdownload << 'EOF'
#!/bin/bash
## This file serves as a starting point to call your custom postimaging scripts.
## <SCRIPTNAME> should be changed to the script you're planning to use.
## Syntax of post download scripts are
#. ${postdownpath}<SCRIPTNAME>
EOF
        chmod +x /images/postdownloadscripts/fog.postdownload
        echo "Created /images/postdownloadscripts/fog.postdownload"
    fi
    
    # Create postinitscripts directory and fog.postinit file (matching FOG's configureStorage)
    mkdir -p /images/dev/postinitscripts
    if [ ! -f /images/dev/postinitscripts/fog.postinit ]; then
        cat > /images/dev/postinitscripts/fog.postinit << 'EOF'
#!/bin/bash
## This file serves as a starting point to call your custom pre-imaging/post init loading scripts.
## <SCRIPTNAME> should be changed to the script you're planning to use.
## Syntax of post init scripts are
#. ${postinitpath}<SCRIPTNAME>
EOF
        chmod +x /images/dev/postinitscripts/fog.postinit
        echo "Created /images/dev/postinitscripts/fog.postinit"
    fi
    
    # Set proper permissions for image and snapin directories (775 allows group write access)
    chmod -R 775 /images
    chown -R www-data:www-data /images
    chown -R www-data:www-data /opt/fog/snapins
    
    echo "Directory preparation completed."
}

checkMountTransitions() {
    echo "Checking for mount configuration changes..."
    
    # Check if critical directories are empty (indicating potential mount change)
    local empty_dirs=()
    
    if [ ! -d "/images" ] || [ -z "$(ls -A /images 2>/dev/null)" ]; then
        empty_dirs+=("images")
    fi
    
    if [ ! -d "/tftpboot" ] || [ -z "$(ls -A /tftpboot 2>/dev/null)" ]; then
        empty_dirs+=("tftpboot")
    elif [ -f "/tftpboot/default.ipxe" ] && [ ! -f "/tftpboot/undionly.kkpxe" ] && [ ! -f "/tftpboot/undionly.kpxe" ]; then
        echo "⚠️  WARNING: /tftpboot appears incomplete (default.ipxe only, missing iPXE boot binaries)."
        echo "   This often happens when a host bind mount hides image files and the copy step failed."
        echo "   Fix: ensure the host directory is writable, clear it, and restart the container."
        echo "   Or check /tftpboot/tftp/ for files that were not flattened (older images)."
    fi
    
    if [ ! -d "/opt/fog/snapins" ] || [ -z "$(ls -A /opt/fog/snapins 2>/dev/null)" ]; then
        empty_dirs+=("snapins")
    fi
    
    if [ ${#empty_dirs[@]} -gt 0 ]; then
        echo "⚠️  WARNING: The following directories appear to be empty:"
        for dir in "${empty_dirs[@]}"; do
            echo "   - /$dir"
        done
        echo ""
        echo "This may indicate:"
        echo "1. First-time startup (normal)"
        echo "2. Mount configuration change (volume ↔ persistent)"
        echo "3. Data loss or corruption"
        echo ""
        echo "If you switched from volume mounts to persistent mounts:"
        echo "- Ensure your host directories contain the expected data"
        echo "- Or copy data from Docker volumes before switching"
        echo ""
        echo "If you switched from persistent mounts to volume mounts:"
        echo "- You'll need to re-upload images and reconfigure FOG"
        echo "- This is expected behavior for a clean slate"
        echo ""
    else
        echo "✓ All critical directories contain data"
    fi
}

waitingForDatabase() {
    local TIMEOUT=60
    echo "Waiting for database server to allow connections..."
    while ! mysql -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USER" -p"$DB_PASS" --ssl=0 -e "SELECT 1" >/dev/null 2>&1; do
        if ! ((TIMEOUT--)); then
            echo "Could not connect to database server. Exiting."
            exit 1
        fi
        echo -n "."
        sleep 1
    done
    echo "Database connection established."
}

configureFOGConfig() {
    echo "Configuring FOG configuration file..."
    
    # Ensure FOG web files are available
    if [ ! -d "/var/www/html/fog" ] || [ ! -f "/var/www/html/fog/index.php" ]; then
        echo "FOG web files not found, copying from source..."
        if [ -d "/opt/fog/fogproject/packages/web" ]; then
            cp -r /opt/fog/fogproject/packages/web/* /var/www/html/fog/
            chown -R www-data:www-data /var/www/html/fog
        else
            echo "Error: FOG web source not found at /opt/fog/fogproject/packages/web"
            exit 1
        fi
    fi

    resolveFOGLayout
    echo "Detected FOG layout: ${FOG_LAYOUT} (config → ${FOG_CONFIG_FILE})"
    
    # Ensure the directory exists
    mkdir -p "$(dirname "$FOG_CONFIG_FILE")"
    
    # Start with template
    cp /opt/fog/templates/config.class.php.template "$FOG_CONFIG_FILE"
    
    # Validate FOG_STORAGE_HOST is set (should default to FOG_WEB_HOST if not explicitly set)
    if [ -z "$FOG_STORAGE_HOST" ]; then
        echo "ERROR: FOG_STORAGE_HOST is not set and FOG_WEB_HOST is also not set!"
        echo "This should not happen if FOG_WEB_HOST validation passed."
        exit 1
    fi
    
    # Clean any trailing braces that might have been introduced (defensive - shouldn't be needed)
    # This handles edge cases where Docker Compose might pass unresolved variable substitutions
    FOG_STORAGE_HOST_CLEAN=$(echo "$FOG_STORAGE_HOST" | sed 's/[}]*$//')
    
    # Validate the cleaned value doesn't look like an unresolved variable
    if [[ "$FOG_STORAGE_HOST_CLEAN" =~ ^\$\{.*\}$ ]] || [ "$FOG_STORAGE_HOST_CLEAN" = "\${FOG_WEB_HOST}" ]; then
        echo "ERROR: FOG_STORAGE_HOST appears to be an unresolved variable: $FOG_STORAGE_HOST"
        echo "FOG_WEB_HOST should be set (IP address or FQDN), which would make FOG_STORAGE_HOST default to it."
        exit 1
    fi
    
    # Per-install schema bootstrap token (FOG 1.5.10.18xx+). Prefer a stable
    # env value when set; otherwise generate one for this container lifetime.
    # Must match what we present to the schema endpoint for unattended upgrades.
    if [ -z "${FOG_SCHEMA_INSTALL_TOKEN:-}" ]; then
        FOG_SCHEMA_INSTALL_TOKEN="$(openssl rand -hex 32 2>/dev/null || tr -dc 'a-f0-9' < /dev/urandom | head -c 64)"
    fi
    if [ -z "$FOG_SCHEMA_INSTALL_TOKEN" ]; then
        echo "ERROR: Failed to generate FOG_SCHEMA_INSTALL_TOKEN"
        exit 1
    fi
    export FOG_SCHEMA_INSTALL_TOKEN

    if [ "$FOG_LAYOUT" = "1.6" ]; then
        FOG_MEMTEST_KERNEL="mt86plus_x86_64"
        FOG_UDPSENDER_PATH="/usr/local/sbin/udp-sender"
    else
        FOG_MEMTEST_KERNEL="memtest.bin"
        FOG_UDPSENDER_PATH="/usr/local/bin/udp-sender"
    fi

    # Replace placeholders with environment variables
    sed -i "s|{{FOG_DB_HOST}}|$FOG_DB_HOST|g" "$FOG_CONFIG_FILE"
    sed -i "s|{{FOG_DB_PORT}}|$FOG_DB_PORT|g" "$FOG_CONFIG_FILE"
    sed -i "s|{{FOG_DB_NAME}}|$FOG_DB_NAME|g" "$FOG_CONFIG_FILE"
    sed -i "s|{{FOG_DB_USER}}|$FOG_DB_USER|g" "$FOG_CONFIG_FILE"
    sed -i "s|{{FOG_DB_PASS}}|$FOG_DB_PASS|g" "$FOG_CONFIG_FILE"
    sed -i "s|{{FOG_SCHEMA_INSTALL_TOKEN}}|$FOG_SCHEMA_INSTALL_TOKEN|g" "$FOG_CONFIG_FILE"
    sed -i "s|{{FOG_TFTP_HOST}}|$FOG_TFTP_HOST|g" "$FOG_CONFIG_FILE"
    sed -i "s|{{FOG_STORAGE_HOST}}|$FOG_STORAGE_HOST_CLEAN|g" "$FOG_CONFIG_FILE"
    sed -i "s|{{FOG_WOL_HOST}}|$FOG_WOL_HOST|g" "$FOG_CONFIG_FILE"
    sed -i "s|{{FOG_MULTICAST_INTERFACE}}|$FOG_MULTICAST_INTERFACE|g" "$FOG_CONFIG_FILE"
    sed -i "s|{{FOG_WEB_HOST}}|$FOG_WEB_HOST|g" "$FOG_CONFIG_FILE"
    sed -i "s|{{FOG_WEB_ROOT}}|$FOG_WEB_ROOT|g" "$FOG_CONFIG_FILE"
    sed -i "s|{{FOG_USER}}|$FOG_USER|g" "$FOG_CONFIG_FILE"
    sed -i "s|{{FOG_PASS}}|$FOG_PASS|g" "$FOG_CONFIG_FILE"
    sed -i "s|{{FOG_MEMTEST_KERNEL}}|$FOG_MEMTEST_KERNEL|g" "$FOG_CONFIG_FILE"
    sed -i "s|{{FOG_UDPSENDER_PATH}}|$FOG_UDPSENDER_PATH|g" "$FOG_CONFIG_FILE"
    
    # Match upstream installer permissions (holds DB/FTP passwords + schema token).
    chown www-data:www-data "$FOG_CONFIG_FILE"
    chmod 0640 "$FOG_CONFIG_FILE"

    # FOG 1.6 loads FOG_BASE_DIR from commons/fogpaths.php before the autoloader.
    if [ "$FOG_LAYOUT" = "1.6" ]; then
        echo "Writing FOG 1.6 fogpaths.php..."
        cat > /var/www/html/fog/commons/fogpaths.php << 'EOF'
<?php
/**
 * Filesystem paths chosen at install time.
 * Generated by fog-docker entrypoint — do not edit.
 */
define('FOG_BASE_DIR', '/opt/fog');
EOF
        chown www-data:www-data /var/www/html/fog/commons/fogpaths.php
        chmod 0644 /var/www/html/fog/commons/fogpaths.php
    fi
    
    # Create FOG service config file (required by FOG services)
    echo "Creating FOG service configuration..."
    mkdir -p /opt/fog/service/etc
    echo "<?php define('WEBROOT','/var/www/html/fog/');" > /opt/fog/service/etc/config.php
    chown -R www-data:www-data /opt/fog/service/etc
    
    echo "FOG configuration completed."
}

configureApache() {
    echo "Configuring Apache..."
    
    # Generate ports.conf from template (idempotent)
    /opt/fog/scripts/process-template.sh /opt/fog/templates/ports.conf.template /etc/apache2/ports.conf
    
    # Generate site config from template
    /opt/fog/scripts/process-template.sh /opt/fog/templates/apache-fog.conf.template "$APACHE_CONFIG_FILE"
    
    # Enable the site
    a2ensite fog
    
    echo "Apache configuration completed."
}


ensureWebCACertificate() {
    echo "Ensuring CA certificate is available for FOG client download..."
    
    # Set variables like FOG source code does
    local sslpath="/opt/fog/snapins/ssl/"
    local webdirdest="/var/www/html/fog"
    local apacheuser="www-data"
    
    mkdir -p "$webdirdest/management/other"
    
    # Check if CA certificate already exists in web directory
    if [ ! -f "$webdirdest/management/other/ca.cert.der" ]; then
        echo "CA certificate not found in web directory, creating from CA..."
        
        # Ensure CA exists (from Dockerfile or create new)
        if [ ! -f "$sslpath/CA/.fogCA.pem" ]; then
            echo "CA not found, creating new CA..."
            mkdir -p "$sslpath/CA"
            openssl genrsa -out "$sslpath/CA/.fogCA.key" 4096
            openssl req -x509 -new -sha512 -nodes -key "$sslpath/CA/.fogCA.key" \
                -days 3650 -out "$sslpath/CA/.fogCA.pem" \
                -subj "/C=US/ST=State/L=City/O=FOG Project/CN=FOG Server CA"
        fi
        
        # Create web-accessible CA files exactly like FOG source (lines 1977-1979)
        cp "$sslpath/CA/.fogCA.pem" "$webdirdest/management/other/ca.cert.pem"
        openssl x509 -outform der -in "$webdirdest/management/other/ca.cert.pem" \
            -out "$webdirdest/management/other/ca.cert.der"
        
        # Set ownership on the specific files that were just created
        chown "$apacheuser:$apacheuser" "$webdirdest/management/other/ca.cert.pem"
        chown "$apacheuser:$apacheuser" "$webdirdest/management/other/ca.cert.der"
        echo "CA certificate created in web directory using FOG source process."
    else
        echo "CA certificate already exists in web directory."
    fi
}

ensureServerPublicCertificate() {
    echo "Ensuring server public certificate is available for FOG client authentication..."
    
    # Set variables like FOG source code does
    local sslpath="/opt/fog/snapins/ssl/"
    local webdirdest="/var/www/html/fog"
    local hostname="${FOG_WEB_HOST:-localhost}"
    local apacheuser="www-data"
    
    # Check if server public certificate already exists
    if [ ! -f "$webdirdest/management/other/ssl/srvpublic.crt" ]; then
        echo "Server public certificate not found, creating using FOG source process..."
        
        # Ensure CA exists (from Dockerfile or create new)
        if [ ! -f "$sslpath/CA/.fogCA.pem" ] || [ ! -f "$sslpath/CA/.fogCA.key" ]; then
            echo "CA not found, creating new CA..."
            mkdir -p "$sslpath/CA"
            openssl genrsa -out "$sslpath/CA/.fogCA.key" 4096
            openssl req -x509 -new -sha512 -nodes -key "$sslpath/CA/.fogCA.key" \
                -days 3650 -out "$sslpath/CA/.fogCA.pem" \
                -subj "/C=US/ST=State/L=City/O=FOG Project/CN=FOG Server CA"
        fi
        
        # Create SSL Private Key exactly like FOG source (lines 1934-1963)
        local sslprivkey="$sslpath/.srvprivate.key"
        mkdir -p "$sslpath"
        openssl genrsa -out "$sslprivkey" 4096
        
        # Create certificate signing request
        cat > "$sslpath/req.cnf" << EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = yes
[req_distinguished_name]
CN = $hostname
[v3_req]
subjectAltName = @alt_names
[alt_names]
DNS.1 = $hostname
EOF
        
        openssl req -new -sha512 -key "$sslprivkey" -out "$sslpath/fog.csr" -config "$sslpath/req.cnf" << EOF
$hostname
EOF
        
        # Create symlink like FOG does (only if target doesn't exist)
        if [ ! -e "$sslpath/.srvprivate.key" ]; then
            ln -sf "$sslprivkey" "$sslpath/.srvprivate.key"
        fi
        
        # Create SSL Certificate exactly like FOG source (lines 1966-1975)
        mkdir -p "$webdirdest/management/other/ssl"
        cat > "$sslpath/ca.cnf" << EOF
[v3_ca]
subjectAltName = @alt_names
[alt_names]
DNS.1 = $hostname
EOF
        
        openssl x509 -req -in "$sslpath/fog.csr" -CA "$sslpath/CA/.fogCA.pem" \
            -CAkey "$sslpath/CA/.fogCA.key" -CAcreateserial \
            -out "$webdirdest/management/other/ssl/srvpublic.crt" \
            -days 3650 -extensions v3_ca -extfile "$sslpath/ca.cnf"
        
        # Set proper ownership
        chown -R "$apacheuser:$apacheuser" "$webdirdest/management/other"
        chown -R "$apacheuser:$apacheuser" "$sslpath"
        
        echo "Server public certificate created using FOG source process."
    else
        echo "Server public certificate already exists."
    fi
}

configureSSL() {
    if [ "$FOG_INTERNAL_HTTPS_ENABLED" = "true" ]; then
        echo "Configuring Apache SSL certificates..."
        
        # Check if external Apache certificates exist
        if [ -f "/opt/fog/snapins/ssl/$FOG_APACHE_SSL_CERT_FILE" ] && [ -f "/opt/fog/snapins/ssl/$FOG_APACHE_SSL_KEY_FILE" ]; then
            echo "Using external Apache SSL certificates."
        else
            echo "Generating self-signed Apache SSL certificate..."
            mkdir -p "/opt/fog/snapins/ssl"
            
            if [ -n "$FOG_APACHE_SSL_SAN" ]; then
                # Create OpenSSL config file for SAN support
                cat > "/opt/fog/snapins/ssl/apache-ssl.conf" << EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
C = US
ST = State
L = City
O = Organization
CN = $FOG_APACHE_SSL_CN

[v3_req]
keyUsage = keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
EOF
                
                # Add SAN entries
                IFS=',' read -ra SAN_ARRAY <<< "$FOG_APACHE_SSL_SAN"
                for i in "${!SAN_ARRAY[@]}"; do
                    echo "DNS.$((i+1)) = ${SAN_ARRAY[$i]}" >> "/opt/fog/snapins/ssl/apache-ssl.conf"
                done
                
                # Generate certificate with SAN
                openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
                    -keyout "/opt/fog/snapins/ssl/$FOG_APACHE_SSL_KEY_FILE" \
                    -out "/opt/fog/snapins/ssl/$FOG_APACHE_SSL_CERT_FILE" \
                    -config "/opt/fog/snapins/ssl/apache-ssl.conf" \
                    -extensions v3_req
            else
                # Generate simple certificate
                openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
                    -keyout "/opt/fog/snapins/ssl/$FOG_APACHE_SSL_KEY_FILE" \
                    -out "/opt/fog/snapins/ssl/$FOG_APACHE_SSL_CERT_FILE" \
                    -subj "/C=US/ST=State/L=City/O=Organization/CN=$FOG_APACHE_SSL_CN"
            fi
            
            chown -R www-data:www-data "/opt/fog/snapins/ssl"
            echo "Self-signed Apache certificate generated."
        fi
    else
        echo "Apache HTTPS disabled, skipping Apache SSL configuration."
    fi
}

configureTFTP() {
    echo "Configuring TFTP server..."
    
    # Generate tftpd-hpa config from template
    /opt/fog/scripts/process-template.sh /opt/fog/templates/tftpd-hpa.conf.template "$TFTP_CONFIG_FILE"
    
    # Create default.ipxe file from template
    /opt/fog/scripts/process-template.sh /opt/fog/templates/default.ipxe.template "/tftpboot/default.ipxe"
    
    echo "TFTP configuration completed."
}

configureNFS() {
    echo "Configuring NFS exports (${FOG_NFS_MODE})..."
    
    # Ensure the directory exists
    mkdir -p "$(dirname "$NFS_CONFIG_FILE")"
    
    if [ "$FOG_NFS_MODE" = "unfs3" ]; then
        # UNFS3 rejects wildcard hostnames such as "*".
        /opt/fog/scripts/process-template.sh /opt/fog/templates/exports-unfs3.template "$NFS_CONFIG_FILE"
        echo "Userland NFS selected; skipping kernel nfsd mounts."
        echo "NFS configuration completed."
        return 0
    fi

    # Generate exports from template
    /opt/fog/scripts/process-template.sh /opt/fog/templates/exports.template "$NFS_CONFIG_FILE"
    
    # Mount NFS filesystems
    echo "Mounting NFS filesystems..."
    
    # Mount rpc_pipefs
    echo "Mounting rpc_pipefs filesystem..."
    mount -t rpc_pipefs /var/lib/nfs/rpc_pipefs /var/lib/nfs/rpc_pipefs || echo "Warning: Could not mount rpc_pipefs filesystem"
    
    # Mount nfsd
    echo "Mounting nfsd filesystem..."
    mount -t nfsd /proc/fs/nfsd /proc/fs/nfsd || echo "Warning: Could not mount nfsd filesystem"
    
    echo "NFS configuration completed."
}

configureFTP() {
    echo "Configuring FTP server..."
    
    # Generate vsftpd config from template
    /opt/fog/scripts/process-template.sh /opt/fog/templates/vsftpd.conf.template "$FTP_CONFIG_FILE"
    
    # Create FTP user if it doesn't exist
    if ! id "$FOG_USER" &>/dev/null; then
        echo "Creating FTP user: $FOG_USER"
        useradd -r -s /bin/bash -d "/home/$FOG_USER" -m -g www-data "$FOG_USER"
    fi
    
    # Set FTP user password
    echo "$FOG_USER:$FOG_PASS" | chpasswd
    
    # Add FTP user to www-data group for access to /images
    usermod -a -G www-data "$FOG_USER"
    echo "Added '$FOG_USER' to www-data group for /images access"
    
    # Set proper ownership for FTP user's home directory
    chown -R "$FOG_USER:www-data" "/home/$FOG_USER"
    
    echo "FTP configuration completed."
}

configureDHCP() {
    if [ "$FOG_DHCP_ENABLED" = "true" ]; then
        echo "Configuring DHCP server..."
        
        # Ensure DHCP leases directory and file exist
        mkdir -p /var/lib/dhcp
        touch /var/lib/dhcp/dhcpd.leases
        chown dhcp:dhcp /var/lib/dhcp/dhcpd.leases 2>/dev/null || chown root:root /var/lib/dhcp/dhcpd.leases
        
        # Generate dhcpd.conf from template
        /opt/fog/scripts/process-template.sh /opt/fog/templates/dhcpd.conf.template "$DHCP_CONFIG_FILE"
        
        echo "DHCP configuration completed."
    else
        echo "DHCP disabled, skipping configuration."
    fi
}

configureiPXE() {
    echo "Configuring iPXE and TFTP boot files..."
    
    verifyTFTBootFiles() {
        local missing=()
        local required_files=(
            "undionly.kkpxe"
            "undionly.kpxe"
            "ipxe.efi"
            "snponly.efi"
        )

        for boot_file in "${required_files[@]}"; do
            if [ ! -f "/tftpboot/${boot_file}" ]; then
                missing+=("$boot_file")
            fi
        done

        if [ ${#missing[@]} -gt 0 ]; then
            echo "ERROR: TFTP boot directory is missing required files:"
            for boot_file in "${missing[@]}"; do
                echo "   - ${boot_file}"
            done
            echo ""
            echo "If /tftpboot is bind-mounted from the host, ensure the directory is writable"
            echo "by the container, then restart. You can also empty the host tftpboot directory"
            echo "and restart to repopulate from the image."
            return 1
        fi

        echo "✓ TFTP boot files verified."
        return 0
    }

    flattenLegacyTftpSubdir() {
        if [ ! -d "/tftpboot/tftp" ]; then
            return 0
        fi

        echo "Flattening legacy /tftpboot/tftp subdirectory..."
        cp -a /tftpboot/tftp/. /tftpboot/ 2>/dev/null || mv /tftpboot/tftp/* /tftpboot/ 2>/dev/null || true
        rm -rf /tftpboot/tftp 2>/dev/null || true
    }

    # Function to copy TFTP files
    copyTFTPFiles() {
        local tftp_src=""

        echo "Copying TFTP boot files to /tftpboot..."
        mkdir -p /tftpboot

        if [ -d "/opt/fog/fogproject/packages/tftp" ] && [ -n "$(ls -A /opt/fog/fogproject/packages/tftp 2>/dev/null)" ]; then
            tftp_src="/opt/fog/fogproject/packages/tftp"
        elif [ -d "/opt/fog/bundled-tftpboot" ] && [ -n "$(ls -A /opt/fog/bundled-tftpboot 2>/dev/null)" ]; then
            echo "Using bundled TFTP boot files from image..."
            tftp_src="/opt/fog/bundled-tftpboot"
        fi

        if [ -z "$tftp_src" ]; then
            echo "ERROR: No TFTP boot file source found in the image."
            return 1
        fi

        # Copy contents directly (matches Dockerfile build step; avoids nested /tftpboot/tftp/)
        if ! cp -a "${tftp_src}/." /tftpboot/; then
            echo "ERROR: Failed to copy TFTP boot files from ${tftp_src} to /tftpboot."
            echo "       Check host mount permissions if /tftpboot is bind-mounted."
            return 1
        fi

        flattenLegacyTftpSubdir

        if ! verifyTFTBootFiles; then
            return 1
        fi

        echo "TFTP boot files copied from ${tftp_src}."

        # Ensure /tftpboot/dev directory exists (required for FOG)
        mkdir -p /tftpboot/dev

        # Create check files in /tftpboot and /tftpboot/dev if they don't exist
        if [ ! -f "/tftpboot/.fogcheck" ]; then
            touch /tftpboot/.fogcheck
        fi
        if [ ! -f "/tftpboot/dev/.fogcheck" ]; then
            touch /tftpboot/dev/.fogcheck
        fi

        chown -R www-data:www-data /tftpboot 2>/dev/null || \
            echo "Warning: Could not change ownership of /tftpboot (common with NFS/host bind mounts)."
        echo "TFTP boot files copied successfully."
    }
    
    if [ "$FOG_INTERNAL_HTTPS_ENABLED" = "true" ]; then
        echo "Recompiling iPXE with self-signed certificate trust..."
        
        # Check if we have the build script
        if [ -f "/opt/fog/utils/FOGiPXE/buildipxe.sh" ]; then
            cd /opt/fog/utils/FOGiPXE
            
            # Make sure the script is executable
            chmod +x buildipxe.sh
            
            # Run the build script with the FOG CA certificate
            ./buildipxe.sh "/opt/fog/snapins/ssl/CA/.fogCA.pem"
            
            if [ $? -eq 0 ]; then
                echo "✓ iPXE recompilation completed successfully."
                copyTFTPFiles || exit 1
            else
                echo "Warning: iPXE recompilation failed, using pre-built binaries."
                echo "This may cause SSL certificate trust issues with self-signed certificates."
                copyTFTPFiles || exit 1
            fi
        else
            echo "Warning: iPXE build script not found, using pre-built binaries."
            echo "This may cause SSL certificate trust issues with self-signed certificates."
            copyTFTPFiles || exit 1
        fi
    else
        echo "iPXE recompilation not needed (HTTP or external certificates)."
        # Always copy TFTP files to handle volume mount overwrites
        copyTFTPFiles || exit 1
    fi
    
    echo "iPXE and TFTP configuration completed."
}

configureSecureBoot() {
    if [ "$FOG_SECURE_BOOT_ENABLED" = "true" ]; then
        echo "Configuring Secure Boot..."
        
        # Make scripts executable
        chmod +x /opt/fog/scripts/*.sh
        
        # Check if Secure Boot setup is possible
        if ! checkSecureBootRequirements; then
            echo "⚠️  WARNING: Secure Boot requirements not met, continuing without Secure Boot"
            echo "   Clients will need to disable Secure Boot or use legacy boot mode"
            return 0
        fi
        
        # Generate keys if they don't exist
        if [ ! -f "/opt/fog/secure-boot/keys/fog.key" ]; then
            echo "Generating Secure Boot keys..."
            if ! /opt/fog/scripts/generate-keys.sh; then
                echo "⚠️  WARNING: Secure Boot key generation failed, continuing without Secure Boot"
                echo "   This may be due to insufficient entropy or disk space"
                echo "   Clients will need to disable Secure Boot or use legacy boot mode"
                return 0
            fi
        else
            echo "✓ Secure Boot keys already exist"
        fi
        
        # Run Secure Boot setup
        echo "Running Secure Boot setup..."
        if ! /opt/fog/scripts/setup-secure-boot.sh; then
            echo "⚠️  WARNING: Secure Boot setup failed, continuing without Secure Boot"
            echo "   This may be due to missing dependencies or permission issues"
            echo "   Clients will need to disable Secure Boot or use legacy boot mode"
            return 0
        fi
        
        echo "✓ Secure Boot configuration completed successfully"
    else
        echo "Secure Boot disabled, skipping configuration."
    fi
}

checkSecureBootRequirements() {
    echo "Checking Secure Boot requirements..."
    
    # Check required tools
    local required_tools=("openssl" "sbsign" "mkfs.fat" "dd")
    local missing_tools=()
    
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            missing_tools+=("$tool")
        fi
    done
    
    if [ ${#missing_tools[@]} -gt 0 ]; then
        echo "   ❌ Missing required tools: ${missing_tools[*]}"
        return 1
    fi
    
    # Check shim binaries
    if [ ! -f "/opt/fog/secure-boot/shim/shimx64.efi" ] || [ ! -f "/opt/fog/secure-boot/shim/mmx64.efi" ]; then
        echo "   ❌ Shim binaries not found"
        return 1
    fi
    
    # Check entropy availability
    if [ ! -r /dev/random ]; then
        echo "   ❌ /dev/random not accessible"
        return 1
    fi
    
    # Check disk space (need at least 50MB)
    local available_space=$(df /opt | awk 'NR==2 {print int($4/1024)}')
    if [ $available_space -lt 50 ]; then
        echo "   ❌ Insufficient disk space (${available_space}MB available, need 50MB)"
        return 1
    fi
    
    echo "   ✓ All Secure Boot requirements met"
    return 0
}

enableFOGServices() {
    echo "Enabling FOG services after database initialization..."
    local supervisor_config="/etc/supervisor/conf.d/supervisord.conf"
    
    # Enable FOG services (but not DHCP if it's disabled)
    sed -i '/\[program:fog-/s/autostart=false/autostart=true/' "$supervisor_config"
    
    # Reload supervisor to apply changes (autostart may already spawn workers)
    supervisorctl reread
    supervisorctl update
    
    # Start all FOG services (ignore "already started" from update+autostart).
    # 1.6-only workers are listed too; supervisorctl fails harmlessly if absent.
    for svc in \
        fog-image-replicator \
        fog-image-size \
        fog-multicast-manager \
        fog-ping-hosts \
        fog-snapin-hash \
        fog-snapin-replicator \
        fog-task-scheduler \
        fog-agent-release-sync \
        fog-file-deleter \
        fog-plugin-runner \
        fog-retention-runner
    do
        supervisorctl start "$svc" || true
    done
    
    echo "FOG services enabled and started."
}

configureSupervisor() {
    echo "Configuring supervisor services..."
    
    # Process the supervisor template to the config directory
    local supervisor_config="/etc/supervisor/conf.d/supervisord.conf"
    /opt/fog/scripts/process-template.sh /opt/fog/templates/supervisord.conf.template "$supervisor_config"
    
    if [ "$FOG_NFS_MODE" = "unfs3" ]; then
        echo "Enabling userland NFS and disabling kernel NFS..."
        sed -i '/\[program:nfs-kernel-server\]/,/^$/d' "$supervisor_config"
        sed -i '/\[program:rpc-statd\]/,/^$/d' "$supervisor_config"
    else
        echo "Enabling kernel NFS..."
        sed -i '/\[program:unfsd\]/,/^$/d' "$supervisor_config"
    fi

    # Drop FOG 1.6-only workers when their packages are not in this image (1.5 builds).
    local optional_svc
    for optional_svc in \
        "fog-agent-release-sync:FOGAgentReleaseSync" \
        "fog-file-deleter:FOGFileDeleter" \
        "fog-plugin-runner:FOGPluginRunner" \
        "fog-retention-runner:FOGRetentionRunner"
    do
        local prog_name="${optional_svc%%:*}"
        local svc_dir="${optional_svc##*:}"
        if [ ! -d "/opt/fog/service/${svc_dir}" ]; then
            sed -i "/\[program:${prog_name}\]/,/^$/d" "$supervisor_config"
        fi
    done

    # If DHCP is disabled, remove the DHCP service from supervisord config
    if [ "$FOG_DHCP_ENABLED" != "true" ]; then
        echo "Disabling DHCP service in supervisor configuration..."
        sed -i '/\[program:isc-dhcp-server\]/,/^$/d' "$supervisor_config"
    else
        echo "DHCP service enabled in supervisor configuration."
        # Enable autostart for DHCP if it was disabled
        sed -i 's/autostart=false/autostart=true/' "$supervisor_config"
    fi
    
    echo "Supervisor configuration completed."
}

staticConfiguration() {
    echo "=== Begin Static Configuration Phase ==="
    prepareDirectories
    configureFOGConfig
    configureApache
    configureSSL
    ensureWebCACertificate
    ensureServerPublicCertificate
    configureiPXE
    configureTFTP
    configureNFS
    configureFTP
    configureDHCP
    configureSecureBoot
    configureSupervisor
    echo "=== End Static Configuration Phase ==="
}

importDatabaseDump() {
    echo "=== Checking for FOG database migration ==="
    
    # Check if migration is enabled
    if [ "${FOG_DB_MIGRATION_ENABLED:-false}" != "true" ]; then
        echo "Database migration is disabled. Skipping import."
        return 0
    fi
    
    # Check for the specific migration dump file
    local dump_file="/opt/migration/FOG_MIGRATION_DUMP.sql"
    
    if [ ! -f "$dump_file" ]; then
        echo "No FOG migration dump found at $dump_file. Skipping import."
        return 0
    fi
    
    echo "Found FOG migration dump: $dump_file"
    
    # Check if FOG database already exists
    if mysql -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USER" -p"$DB_PASS" --ssl=0 -e "USE $DB_NAME;" 2>/dev/null; then
        if [ "${FOG_DB_MIGRATION_FORCE:-false}" = "true" ]; then
            echo "WARNING: FOG database '$DB_NAME' already exists, but FOG_DB_MIGRATION_FORCE=true"
            echo "Proceeding with migration (this will overwrite existing data)..."
        else
            echo "WARNING: FOG database '$DB_NAME' already exists!"
            echo "Migration would overwrite existing data. Skipping import for safety."
            echo "To force migration, set FOG_DB_MIGRATION_FORCE=true"
            return 1
        fi
    fi
    
    echo "Importing database dump for FOG migration..."
    
    # Import the dump
    if mysql -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USER" -p"$DB_PASS" --ssl=0 < "$dump_file" 2>/dev/null; then
        echo "FOG database migration completed successfully."
        echo "Removing migration dump file to prevent re-import on next restart."
        rm -f "$dump_file"
        return 0
    else
        echo "Failed to import FOG migration dump. Check the file format and database connection."
        echo "Migration dump file left in place for manual inspection: $dump_file"
        return 1
    fi
}

bootstrappingEnvironment() {
    echo "=== Begin Bootstrap Phase ==="
    waitingForDatabase
    importDatabaseDump
    echo "=== End Bootstrap Phase ==="
}

# Expected FOG schema version baked into this image (1.5 system.class.php or 1.6 System.php).
getExpectedFOGSchema() {
    resolveFOGLayout
    if [ ! -f "$FOG_SYSTEM_FILE" ]; then
        echo ""
        return 1
    fi
    sed -n "s/.*define('FOG_SCHEMA', *\([0-9][0-9]*\).*/\1/p" "$FOG_SYSTEM_FILE" | head -1
}

# Current schemaVersion in the database (0 if missing / unreachable).
getCurrentDBSchema() {
    local version
    version="$(mysql -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USER" -p"$DB_PASS" --ssl=0 -Nse \
        "SELECT vValue FROM \`${DB_NAME}\`.schemaVersion LIMIT 1;" 2>/dev/null | tr -d '[:space:]' || true)"
    if [[ "$version" =~ ^[0-9]+$ ]]; then
        echo "$version"
    else
        echo "0"
    fi
}

# Install/upgrade FOG DB schema unattended using FOG_SCHEMA_INSTALL_TOKEN.
# Hard-fails (return 1) if the DB cannot be brought to FOG_SCHEMA.
ensureFOGDatabaseSchema() {
    echo "Checking/updating FOG database schema..."

    if [ -z "${FOG_SCHEMA_INSTALL_TOKEN:-}" ]; then
        echo "ERROR: FOG_SCHEMA_INSTALL_TOKEN is not set (configureFOGConfig must run first)."
        return 1
    fi

    local expected
    expected="$(getExpectedFOGSchema || true)"
    if ! [[ "$expected" =~ ^[0-9]+$ ]]; then
        echo "ERROR: Could not read FOG_SCHEMA from ${FOG_SYSTEM_FILE}"
        return 1
    fi

    local current
    current="$(getCurrentDBSchema)"
    echo "  → Image expects schema version: $expected"
    echo "  → Database schema version:     $current"

    if [ "$current" -ge "$expected" ]; then
        echo "✓ Database schema is up to date ($current >= $expected)."
        return 0
    fi

    echo "Database schema needs install/update ($current → $expected)."
    echo "Running unattended schema deploy with install token..."

    local init_url="http://localhost:${FOG_APACHE_PORT}${FOG_WEB_ROOT}/management/index.php?node=schema"
    local response_file="/tmp/schema_response.html"
    local http_code curl_exit

    # Match upstream FOG installer: token header + POST to schema endpoint.
    # Do not follow redirects (-L): a 302 to login usually means auth failed.
    set +e
    http_code="$(curl -sS -o "$response_file" -w "%{http_code}" \
        -H "X-Fog-Install-Token: ${FOG_SCHEMA_INSTALL_TOKEN}" \
        --data-urlencode "fogtoken=${FOG_SCHEMA_INSTALL_TOKEN}" \
        --data-urlencode "fogverified=1" \
        --data-urlencode "confirm=1" \
        --data-urlencode "schemaupdate=1" \
        "$init_url" 2>/tmp/schema_curl.err)"
    curl_exit=$?
    set -e

    local init_result
    init_result="$(cat "$response_file" 2>/dev/null || true)"

    echo "Schema endpoint HTTP response code: ${http_code:-unknown} (curl exit ${curl_exit})"

    if [ "$curl_exit" -ne 0 ] || [ -z "$http_code" ] || [ "$http_code" = "000" ]; then
        echo "ERROR: Failed to reach schema endpoint at $init_url"
        if [ -s /tmp/schema_curl.err ]; then
            echo "  curl error: $(head -c 500 /tmp/schema_curl.err)"
        fi
        rm -f "$response_file" /tmp/schema_curl.err
        return 1
    fi

    # FOG 1.5 HTML: "Install / Update Successful"
    # FOG 1.6 JSON: {"msg":"Schema updated successfully!","title":"Schema Update Success"}
    schema_response_ok() {
        echo "$1" | grep -qiE \
            'Install / Update Successful|Schema updated successfully|Schema Update Success|Update not required|already up to date'
    }

    case "$http_code" in
        200)
            if schema_response_ok "$init_result"; then
                echo "✓ Schema endpoint reported success."
            else
                echo "ERROR: Schema endpoint returned HTTP 200 but not a success payload."
                echo "$init_result" | sed 's/<[^>]*>//g' | tr -s '[:space:]' ' ' | head -c 800
                echo
                rm -f "$response_file" /tmp/schema_curl.err
                return 1
            fi
            ;;
        401|403)
            echo "ERROR: Schema endpoint rejected install token (HTTP $http_code)."
            echo "  FOG now requires FOG_SCHEMA_INSTALL_TOKEN (or an admin session)."
            echo "$init_result" | sed 's/<[^>]*>//g' | tr -s '[:space:]' ' ' | head -c 400
            echo
            rm -f "$response_file" /tmp/schema_curl.err
            return 1
            ;;
        404)
            # indexPost throws "Update not required!" as Exception → HTTP 404
            if schema_response_ok "$init_result"; then
                echo "✓ Schema endpoint reported update not required."
            else
                echo "ERROR: Schema update failed (HTTP 404)."
                echo "$init_result" | sed 's/<[^>]*>//g' | tr -s '[:space:]' ' ' | head -c 800
                echo
                rm -f "$response_file" /tmp/schema_curl.err
                return 1
            fi
            ;;
        *)
            echo "ERROR: Unexpected schema endpoint response (HTTP $http_code)."
            echo "$init_result" | sed 's/<[^>]*>//g' | tr -s '[:space:]' ' ' | head -c 800
            echo
            rm -f "$response_file" /tmp/schema_curl.err
            return 1
            ;;
    esac

    rm -f "$response_file" /tmp/schema_curl.err

    current="$(getCurrentDBSchema)"
    echo "  → Database schema version after update: $current"

    if [ "$current" -lt "$expected" ]; then
        echo "ERROR: Schema still outdated after update ($current < $expected)."
        echo "Refusing to start FOG workers with a mismatched schema (CLI services exit 0 via schema redirect)."
        return 1
    fi

    echo "✓ Database schema check/update completed successfully ($current)."

    # Fresh installs should have the default admin; warn only (upgrade DBs may use another name).
    local user_exists
    user_exists="$(mysql -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USER" -p"$DB_PASS" --ssl=0 -Nse \
        "SELECT COUNT(*) FROM \`${DB_NAME}\`.users WHERE uName='fog';" 2>/dev/null | tr -d '[:space:]' || true)"
    if [ "$user_exists" = "1" ]; then
        echo "✓ Admin user 'fog' exists in database"
        echo "  → Default credentials: fog / password (change after first login)"
    else
        echo "⚠ Admin user 'fog' not found (may be normal on upgraded databases)"
    fi

    return 0
}

# BEGIN app functions
appRun() {
    staticConfiguration
    bootstrappingEnvironment
    echo "=== Begin Run Phase ==="
    echo "Starting FOG using supervisor with \"/etc/supervisor/conf.d/supervisord.conf\" config..."
    echo ""
    
    # Set timezone for all processes
    export TZ="${TZ:-UTC}"
    
    # Start supervisor in the background
    supervisord -c "/etc/supervisor/conf.d/supervisord.conf" &
    SUPERVISOR_PID=$!
    
    # Wait a moment for supervisor to start
    sleep 5
    
    # Wait for Apache to be ready
    echo "Waiting for Apache to be ready..."
    local apache_ready=0
    local i
    for i in {1..30}; do
        if curl -s -f "http://localhost:${FOG_APACHE_PORT}${FOG_WEB_ROOT}/management/" >/dev/null 2>&1; then
            echo "Apache is ready."
            apache_ready=1
            break
        fi
        echo "Waiting for Apache... (attempt $i/30)"
        sleep 2
    done

    if [ "$apache_ready" -ne 1 ]; then
        echo "ERROR: Apache did not become ready; cannot run schema migration."
        kill "$SUPERVISOR_PID" 2>/dev/null || true
        wait "$SUPERVISOR_PID" 2>/dev/null || true
        exit 1
    fi

    if ! ensureFOGDatabaseSchema; then
        echo "FATAL: FOG database schema install/update failed."
        echo "Container will exit so the failure is visible and not masked by a half-started stack."
        kill "$SUPERVISOR_PID" 2>/dev/null || true
        wait "$SUPERVISOR_PID" 2>/dev/null || true
        exit 1
    fi
    
    # Enable FOG services only after schema is confirmed current
    echo "Enabling FOG services after database initialization..."
    enableFOGServices
    
    # Wait for supervisor to finish
    wait $SUPERVISOR_PID
}

appInit() {
    echo "=== Running initial setup ==="
    staticConfiguration
    bootstrappingEnvironment
}

appHelp() {
    echo "Available commands:"
    echo "> app:help     - Show this help menu and exit"
    echo "> app:init     - Run initial setup of FOG server"
    echo "> app:run      - Run the FOG server"
    echo "> [COMMAND]    - Run given command with arguments in shell"
}

# END app functions

case "$1" in
    app:run)
        appRun
    ;;
    app:init)
        appInit
    ;;
    app:help)
        appHelp
    ;;
    *)
        exec "$@" || appHelp
    ;;
esac

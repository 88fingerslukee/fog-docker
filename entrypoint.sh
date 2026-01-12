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

# Apache Configuration
FOG_APACHE_PORT="${FOG_APACHE_PORT:-80}"
FOG_APACHE_SSL_PORT="${FOG_APACHE_SSL_PORT:-443}"
FOG_INTERNAL_HTTPS_ENABLED="${FOG_INTERNAL_HTTPS_ENABLED:-false}"
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

# Configuration file paths
FOG_CONFIG_FILE="/var/www/html/fog/lib/fog/config.class.php"
APACHE_CONFIG_FILE="/etc/apache2/sites-available/fog.conf"
TFTP_CONFIG_FILE="/etc/default/tftpd-hpa"
NFS_CONFIG_FILE="/etc/exports"
FTP_CONFIG_FILE="/etc/vsftpd.conf"
DHCP_CONFIG_FILE="/etc/dhcp/dhcpd.conf"

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
    
    # Replace placeholders with environment variables
    sed -i "s|{{FOG_DB_HOST}}|$FOG_DB_HOST|g" "$FOG_CONFIG_FILE"
    sed -i "s|{{FOG_DB_PORT}}|$FOG_DB_PORT|g" "$FOG_CONFIG_FILE"
    sed -i "s|{{FOG_DB_NAME}}|$FOG_DB_NAME|g" "$FOG_CONFIG_FILE"
    sed -i "s|{{FOG_DB_USER}}|$FOG_DB_USER|g" "$FOG_CONFIG_FILE"
    sed -i "s|{{FOG_DB_PASS}}|$FOG_DB_PASS|g" "$FOG_CONFIG_FILE"
    sed -i "s|{{FOG_TFTP_HOST}}|$FOG_TFTP_HOST|g" "$FOG_CONFIG_FILE"
    sed -i "s|{{FOG_STORAGE_HOST}}|$FOG_STORAGE_HOST_CLEAN|g" "$FOG_CONFIG_FILE"
    sed -i "s|{{FOG_WOL_HOST}}|$FOG_WOL_HOST|g" "$FOG_CONFIG_FILE"
    sed -i "s|{{FOG_MULTICAST_INTERFACE}}|$FOG_MULTICAST_INTERFACE|g" "$FOG_CONFIG_FILE"
    sed -i "s|{{FOG_WEB_HOST}}|$FOG_WEB_HOST|g" "$FOG_CONFIG_FILE"
    sed -i "s|{{FOG_WEB_ROOT}}|$FOG_WEB_ROOT|g" "$FOG_CONFIG_FILE"
    sed -i "s|{{FOG_USER}}|$FOG_USER|g" "$FOG_CONFIG_FILE"
    sed -i "s|{{FOG_PASS}}|$FOG_PASS|g" "$FOG_CONFIG_FILE"
    
    chown www-data:www-data "$FOG_CONFIG_FILE"
    
    # Create FOG service config file (required by FOG services)
    echo "Creating FOG service configuration..."
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
    echo "Configuring NFS exports..."
    
    # Ensure the directory exists
    mkdir -p "$(dirname "$NFS_CONFIG_FILE")"
    
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
    
    # Function to copy TFTP files
    copyTFTPFiles() {
        echo "Copying TFTP boot files to /tftpboot..."
        # Copy from the FOG source directory (where files are during build)
        if [ -d "/opt/fog/fogproject/packages/tftp" ]; then
            cp -r /opt/fog/fogproject/packages/tftp/ /tftpboot/ 2>/dev/null || true

            # Fix: If /tftpboot/tftp subdirectory exists, move its contents to /tftpboot
            if [ -d "/tftpboot/tftp" ]; then
                echo "Moving files from /tftpboot/tftp to /tftpboot..."
                mv /tftpboot/tftp/* /tftpboot/ 2>/dev/null || true
                rmdir /tftpboot/tftp 2>/dev/null || true
            fi

            echo "TFTP boot files copied from FOG source."
        else
            echo "Warning: FOG TFTP source directory not found at /opt/fog/fogproject/packages/tftp"
        fi
        
        # Ensure /tftpboot/dev directory exists (required for FOG)
        mkdir -p /tftpboot/dev
        chown -R www-data:www-data /tftpboot/dev
        
        # Create check files in /tftpboot and /tftpboot/dev if they don't exist
        if [ ! -f "/tftpboot/.fogcheck" ]; then
            touch /tftpboot/.fogcheck
            chown www-data:www-data /tftpboot/.fogcheck
        fi
        if [ ! -f "/tftpboot/dev/.fogcheck" ]; then
            touch /tftpboot/dev/.fogcheck
            chown www-data:www-data /tftpboot/dev/.fogcheck
        fi
        
        chown -R www-data:www-data /tftpboot
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
                copyTFTPFiles
            else
                echo "Warning: iPXE recompilation failed, using pre-built binaries."
                echo "This may cause SSL certificate trust issues with self-signed certificates."
                copyTFTPFiles
            fi
        else
            echo "Warning: iPXE build script not found, using pre-built binaries."
            echo "This may cause SSL certificate trust issues with self-signed certificates."
            copyTFTPFiles
        fi
    else
        echo "iPXE recompilation not needed (HTTP or external certificates)."
        # Always copy TFTP files to handle volume mount overwrites
        copyTFTPFiles
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
    
    # Reload supervisor to apply changes
    supervisorctl reread
    supervisorctl update
    
    # Start all FOG services
    supervisorctl start fog-image-replicator
    supervisorctl start fog-image-size
    supervisorctl start fog-multicast-manager
    supervisorctl start fog-ping-hosts
    supervisorctl start fog-snapin-hash
    supervisorctl start fog-snapin-replicator
    supervisorctl start fog-task-scheduler
    
    echo "FOG services enabled and started."
}

configureSupervisor() {
    echo "Configuring supervisor services..."
    
    # Process the supervisor template to the config directory
    local supervisor_config="/etc/supervisor/conf.d/supervisord.conf"
    /opt/fog/scripts/process-template.sh /opt/fog/templates/supervisord.conf.template "$supervisor_config"
    
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
    for i in {1..30}; do
        if curl -s -f "http://localhost:${FOG_APACHE_PORT}${FOG_WEB_ROOT}/management/" >/dev/null 2>&1; then
            echo "Apache is ready."
            break
        fi
        echo "Waiting for Apache... (attempt $i/30)"
        sleep 2
    done
    
    # Check and update FOG database schema (handles both new installs and upgrades)
    echo "Checking/updating FOG database schema..."
    local init_url="http://localhost:${FOG_APACHE_PORT}${FOG_WEB_ROOT}/management/index.php?node=schema"
    
    # Capture both HTTP response code and body
    local http_code=$(curl -s -o /tmp/schema_response.html -w "%{http_code}" --data "confirm&fogverified" "$init_url" 2>&1)
    local init_result=$(cat /tmp/schema_response.html 2>/dev/null || echo "")
    local curl_exit=$?
    
    echo "Schema endpoint HTTP response code: $http_code"
    
    if [ $curl_exit -eq 0 ] && [ "$http_code" = "200" ]; then
        # Check if the response indicates success
        if echo "$init_result" | grep -qi "Install / Update Successful\|successful"; then
            echo "✓ Database schema check/update completed successfully."
            
            # Extract and display key information from the response
            if echo "$init_result" | grep -qi "Install"; then
                echo "  → This appears to be a new installation"
            elif echo "$init_result" | grep -qi "Update"; then
                echo "  → Database schema was updated"
            fi
            
            # Verify admin user was created
            echo "Verifying admin user creation..."
            local user_exists=$(mysql -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USER" -p"$DB_PASS" --ssl=0 -e "SELECT COUNT(*) FROM ${DB_NAME}.users WHERE uName='fog';" 2>/dev/null | tail -1 | tr -d '[:space:]')
            
            if [ "$user_exists" = "1" ]; then
                echo "✓ Admin user 'fog' exists in database"
                echo "  → Default credentials: fog / password"
                echo "  → IMPORTANT: Change this password immediately after first login!"
            else
                echo "⚠ WARNING: Admin user 'fog' not found in database"
                echo "  → You may need to complete installation through the web interface"
                echo "  → Visit: ${FOG_HTTP_PROTOCOL}://${FOG_WEB_HOST}:${FOG_APACHE_PORT}${FOG_WEB_ROOT}/management"
            fi
        else
            echo "⚠ Schema endpoint returned 200 but response indicates an issue:"
            echo "$init_result" | grep -o '<p>[^<]*</p>' | sed 's/<[^>]*>//g' | head -5
        fi
    else
        echo "✗ Database schema check/update failed"
        echo "  HTTP Code: $http_code"
        echo "  Error: $init_result"
        echo ""
        echo "FOG will need to be initialized through the web interface."
        echo "Please visit: ${FOG_HTTP_PROTOCOL}://${FOG_WEB_HOST}:${FOG_APACHE_PORT}${FOG_WEB_ROOT}/management"
        echo "to complete the initial setup."
    fi
    
    # Clean up temp file
    rm -f /tmp/schema_response.html 2>/dev/null
    
    # Enable FOG services now that supervisor is running and database is initialized
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

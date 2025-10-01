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
FOG_WEB_HOST="${FOG_WEB_HOST:-localhost}"
FOG_WEB_ROOT="${FOG_WEB_ROOT:-/fog}"
FOG_TFTP_HOST="${FOG_TFTP_HOST:-localhost}"
FOG_STORAGE_HOST="${FOG_STORAGE_HOST:-localhost}"
FOG_WOL_HOST="${FOG_WOL_HOST:-localhost}"
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
FOG_SSL_PATH="${FOG_SSL_PATH:-/opt/fog/snapins/ssl}"
FOG_SSL_CERT_FILE="${FOG_SSL_CERT_FILE:-server.crt}"
FOG_SSL_KEY_FILE="${FOG_SSL_KEY_FILE:-server.key}"
FOG_SSL_GENERATE_SELF_SIGNED="${FOG_SSL_GENERATE_SELF_SIGNED:-true}"
FOG_SSL_CN="${FOG_SSL_CN:-${FOG_WEB_HOST}}"
FOG_SSL_SAN="${FOG_SSL_SAN:-}"

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
FOG_DHCP_BOOTFILE_BIOS="${FOG_DHCP_BOOTFILE_BIOS:-undionly.kpxe}"
FOG_DHCP_BOOTFILE_UEFI32="${FOG_DHCP_BOOTFILE_UEFI32:-ipxe32.efi}"
FOG_DHCP_BOOTFILE_UEFI64="${FOG_DHCP_BOOTFILE_UEFI64:-ipxe.efi}"
FOG_DHCP_BOOTFILE_ARM32="${FOG_DHCP_BOOTFILE_ARM32:-arm32.efi}"
FOG_DHCP_BOOTFILE_ARM64="${FOG_DHCP_BOOTFILE_ARM64:-arm64.efi}"
FOG_DHCP_HTTPBOOT_ENABLED="${FOG_DHCP_HTTPBOOT_ENABLED:-false}"
FOG_DHCP_DNS="${FOG_DHCP_DNS:-8.8.8.8}"

# FOG Version
FOG_VERSION="${FOG_VERSION:-stable}"

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
    
    # Set proper permissions for image and snapin directories
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
    
    # Replace placeholders with environment variables
    sed -i "s|{{FOG_DB_HOST}}|$FOG_DB_HOST|g" "$FOG_CONFIG_FILE"
    sed -i "s|{{FOG_DB_PORT}}|$FOG_DB_PORT|g" "$FOG_CONFIG_FILE"
    sed -i "s|{{FOG_DB_NAME}}|$FOG_DB_NAME|g" "$FOG_CONFIG_FILE"
    sed -i "s|{{FOG_DB_USER}}|$FOG_DB_USER|g" "$FOG_CONFIG_FILE"
    sed -i "s|{{FOG_DB_PASS}}|$FOG_DB_PASS|g" "$FOG_CONFIG_FILE"
    sed -i "s|{{FOG_TFTP_HOST}}|$FOG_TFTP_HOST|g" "$FOG_CONFIG_FILE"
    sed -i "s|{{FOG_STORAGE_HOST}}|$FOG_STORAGE_HOST|g" "$FOG_CONFIG_FILE"
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

createFOGCA() {
    if [ "$FOG_SSL_GENERATE_SELF_SIGNED" = "true" ]; then
        echo "Setting up FOG CA for iPXE trust..."
        mkdir -p "$FOG_SSL_PATH/CA"
        
        # Check if CA already exists from Dockerfile build
        if [ -f "/opt/fog/snapins/ssl/CA/.fogCA.key" ] && [ -f "/opt/fog/snapins/ssl/CA/.fogCA.pem" ]; then
            echo "Using pre-built CA certificate from Dockerfile..."
            cp /opt/fog/snapins/ssl/CA/.fogCA.key "$FOG_SSL_PATH/CA/.fogCA.key"
            cp /opt/fog/snapins/ssl/CA/.fogCA.pem "$FOG_SSL_PATH/CA/.fogCA.pem"
        else
            echo "Creating new FOG CA for iPXE trust..."
            # Create CA key and certificate (matching FOG source exactly)
            openssl genrsa -out "$FOG_SSL_PATH/CA/.fogCA.key" 4096
            openssl req -x509 -new -sha512 -nodes -key "$FOG_SSL_PATH/CA/.fogCA.key" \
                -days 3650 -out "$FOG_SSL_PATH/CA/.fogCA.pem" \
                -subj "/C=US/ST=State/L=City/O=FOG Project/CN=FOG Server CA"
        fi
        
        chown -R www-data:www-data "$FOG_SSL_PATH/CA"
        echo "FOG CA ready for iPXE trust."
    fi
}

ensureWebCACertificate() {
    echo "Ensuring CA certificate is available for FOG client download..."
    mkdir -p /var/www/html/fog/management/other
    
    # Check if CA certificate already exists in web directory
    if [ ! -f "/var/www/html/fog/management/other/ca.cert.der" ]; then
        echo "CA certificate not found in web directory, creating from pre-built CA..."
        
        # Use the pre-built CA from Dockerfile
        if [ -f "/opt/fog/snapins/ssl/CA/.fogCA.pem" ]; then
            cp /opt/fog/snapins/ssl/CA/.fogCA.pem /var/www/html/fog/management/other/ca.cert.pem
            openssl x509 -outform der -in /var/www/html/fog/management/other/ca.cert.pem \
                -out /var/www/html/fog/management/other/ca.cert.der
            chown www-data:www-data /var/www/html/fog/management/other/ca.cert.*
            echo "CA certificate created in web directory from pre-built CA."
        else
            echo "Warning: No pre-built CA found, FOG client may fail to download CA certificate."
        fi
    else
        echo "CA certificate already exists in web directory."
    fi
}

configureSSL() {
    if [ "$FOG_INTERNAL_HTTPS_ENABLED" = "true" ]; then
        echo "Configuring SSL certificates..."
        
        # Check if external certificates exist
        if [ -f "$FOG_SSL_PATH/$FOG_SSL_CERT_FILE" ] && [ -f "$FOG_SSL_PATH/$FOG_SSL_KEY_FILE" ]; then
            echo "Using external SSL certificates."
            FOG_SSL_GENERATE_SELF_SIGNED="false"
        elif [ "$FOG_SSL_GENERATE_SELF_SIGNED" = "true" ] && [ ! -f "$FOG_SSL_PATH/$FOG_SSL_CERT_FILE" ]; then
            echo "Generating self-signed SSL certificate..."
            mkdir -p "$FOG_SSL_PATH"
            
            # Create FOG CA first
            createFOGCA
            
            if [ -n "$FOG_SSL_SAN" ]; then
                # Create OpenSSL config file for SAN support
                cat > "$FOG_SSL_PATH/ssl.conf" << EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
C = US
ST = State
L = City
O = Organization
CN = $FOG_SSL_CN

[v3_req]
keyUsage = keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
EOF
                
                # Add SAN entries
                IFS=',' read -ra SAN_ARRAY <<< "$FOG_SSL_SAN"
                for i in "${!SAN_ARRAY[@]}"; do
                    echo "DNS.$((i+1)) = ${SAN_ARRAY[$i]}" >> "$FOG_SSL_PATH/ssl.conf"
                done
                
                # Generate certificate with SAN
                openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
                    -keyout "$FOG_SSL_PATH/$FOG_SSL_KEY_FILE" \
                    -out "$FOG_SSL_PATH/$FOG_SSL_CERT_FILE" \
                    -config "$FOG_SSL_PATH/ssl.conf" \
                    -extensions v3_req
            else
                # Generate simple certificate
                openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
                    -keyout "$FOG_SSL_PATH/$FOG_SSL_KEY_FILE" \
                    -out "$FOG_SSL_PATH/$FOG_SSL_CERT_FILE" \
                    -subj "/C=US/ST=State/L=City/O=Organization/CN=$FOG_SSL_CN"
            fi
            
            chown -R www-data:www-data "$FOG_SSL_PATH"
            echo "Self-signed certificate generated."
        elif [ "$FOG_SSL_GENERATE_SELF_SIGNED" = "false" ]; then
            echo "Error: HTTPS enabled but no certificates found and generation disabled."
            echo "Please provide external certificates or set FOG_SSL_GENERATE_SELF_SIGNED=true"
            exit 1
        else
            echo "SSL certificates already exist."
        fi
    else
        echo "HTTPS disabled, skipping SSL configuration."
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

            echo "TFTP boot files copied from FOG source."
        else
            echo "Warning: FOG TFTP source directory not found at /opt/fog/fogproject/packages/tftp"
        fi
        chown -R www-data:www-data /tftpboot
        echo "TFTP boot files copied successfully."
    }
    
    if [ "$FOG_INTERNAL_HTTPS_ENABLED" = "true" ] && [ "$FOG_SSL_GENERATE_SELF_SIGNED" = "true" ]; then
        echo "Recompiling iPXE with self-signed certificate trust..."
        
        # Check if we have the build script
        if [ -f "/opt/fog/utils/FOGiPXE/buildipxe.sh" ]; then
            cd /opt/fog/utils/FOGiPXE
            
            # Make sure the script is executable
            chmod +x buildipxe.sh
            
            # Run the build script with the FOG CA certificate
            ./buildipxe.sh "$FOG_SSL_PATH/CA/.fogCA.pem"
            
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
    local init_result=$(curl -s -f --data "confirm&fogverified" "$init_url" 2>&1)
    
    if [ $? -eq 0 ]; then
        echo "Database schema check/update completed successfully."
    else
        echo "Database schema check/update failed: $init_result"
        echo "FOG will be initialized through the web interface."
        echo "Please visit ${FOG_HTTP_PROTOCOL}://${FOG_WEB_HOST}:${FOG_APACHE_PORT}${FOG_WEB_ROOT}/management to complete the initial setup."
    fi
    
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

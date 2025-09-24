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

# Network Configuration
FOG_WEB_HOST="${FOG_WEB_HOST:-localhost}"
FOG_WEB_ROOT="${FOG_WEB_ROOT:-/fog}"
FOG_TFTP_HOST="${FOG_TFTP_HOST:-localhost}"
FOG_NFS_HOST="${FOG_NFS_HOST:-localhost}"
FOG_WOL_HOST="${FOG_WOL_HOST:-localhost}"
FOG_MULTICAST_INTERFACE="${FOG_MULTICAST_INTERFACE:-eth0}"

# Apache Configuration
FOG_APACHE_PORT="${FOG_APACHE_PORT:-80}"
FOG_APACHE_SSL_PORT="${FOG_APACHE_SSL_PORT:-443}"
FOG_HTTPS_ENABLED="${FOG_HTTPS_ENABLED:-true}"
FOG_HTTP_PROTOCOL="${FOG_HTTP_PROTOCOL:-https}"

# FTP Configuration
FOG_FTP_USER="${FOG_FTP_USER:-fogproject}"
FOG_FTP_PASS="${FOG_FTP_PASS:-fogftp123}"

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
FOG_DHCP_START_RANGE="${FOG_DHCP_START_RANGE:-192.168.1.100}"
FOG_DHCP_END_RANGE="${FOG_DHCP_END_RANGE:-192.168.1.200}"
FOG_DHCP_BOOTFILE="${FOG_DHCP_BOOTFILE:-undionly.kpxe}"
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
      
    # SSL certificates (mounted to /opt/fog/snapins/ssl)
    mkdir -p /opt/fog/snapins/ssl
    
    # Secure Boot files
    mkdir -p /opt/fog/secure-boot
    
    # Set proper ownership
    chown -R www-data:www-data /var/www/html/fog
    
    echo "Directory preparation completed."
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
    sed -i "s|{{DB_HOST}}|$DB_HOST|g" "$FOG_CONFIG_FILE"
    sed -i "s|{{DB_PORT}}|$DB_PORT|g" "$FOG_CONFIG_FILE"
    sed -i "s|{{DB_NAME}}|$DB_NAME|g" "$FOG_CONFIG_FILE"
    sed -i "s|{{DB_USER}}|$DB_USER|g" "$FOG_CONFIG_FILE"
    sed -i "s|{{DB_PASS}}|$DB_PASS|g" "$FOG_CONFIG_FILE"
    sed -i "s|{{FOG_TFTP_HOST}}|$FOG_TFTP_HOST|g" "$FOG_CONFIG_FILE"
    sed -i "s|{{FOG_NFS_HOST}}|$FOG_NFS_HOST|g" "$FOG_CONFIG_FILE"
    sed -i "s|{{FOG_WOL_HOST}}|$FOG_WOL_HOST|g" "$FOG_CONFIG_FILE"
    sed -i "s|{{FOG_MULTICAST_INTERFACE}}|$FOG_MULTICAST_INTERFACE|g" "$FOG_CONFIG_FILE"
    sed -i "s|{{FOG_WEB_HOST}}|$FOG_WEB_HOST|g" "$FOG_CONFIG_FILE"
    sed -i "s|{{FOG_WEB_ROOT}}|$FOG_WEB_ROOT|g" "$FOG_CONFIG_FILE"
    sed -i "s|{{FOG_FTP_USER}}|$FOG_FTP_USER|g" "$FOG_CONFIG_FILE"
    sed -i "s|{{FOG_FTP_PASS}}|$FOG_FTP_PASS|g" "$FOG_CONFIG_FILE"
    
    chown www-data:www-data "$FOG_CONFIG_FILE"
    
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

createFOGCA() {
    if [ "$FOG_SSL_GENERATE_SELF_SIGNED" = "true" ]; then
        echo "Creating FOG CA for iPXE trust..."
        mkdir -p "$FOG_SSL_PATH/CA"
        
        # Create CA key and certificate
        openssl genrsa -out "$FOG_SSL_PATH/CA/.fogCA.key" 4096
        openssl req -x509 -new -sha512 -nodes -key "$FOG_SSL_PATH/CA/.fogCA.key" \
            -days 3650 -out "$FOG_SSL_PATH/CA/.fogCA.pem" \
            -subj "/C=US/ST=State/L=City/O=FOG Project/CN=FOG CA"
        
        chown -R www-data:www-data "$FOG_SSL_PATH/CA"
        echo "FOG CA created for iPXE trust."
    fi
}

configureSSL() {
    if [ "$FOG_HTTPS_ENABLED" = "true" ]; then
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
    
    echo "NFS configuration completed."
}

configureFTP() {
    echo "Configuring FTP server..."
    
    # Generate vsftpd config from template
    /opt/fog/scripts/process-template.sh /opt/fog/templates/vsftpd.conf.template "$FTP_CONFIG_FILE"
    
    # Create FTP user if it doesn't exist
    if ! id "$FOG_FTP_USER" &>/dev/null; then
        echo "Creating FTP user: $FOG_FTP_USER"
        useradd -r -s /bin/bash -d /opt/fog/snapins -m "$FOG_FTP_USER"
    fi
    
    # Set FTP user password
    echo "$FOG_FTP_USER:$FOG_FTP_PASS" | chpasswd
    
    # Set proper ownership for FTP user's home directory
    chown -R "$FOG_FTP_USER:$FOG_FTP_USER" /opt/fog/snapins
    
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
    if [ "$FOG_HTTPS_ENABLED" = "true" ] && [ "$FOG_SSL_GENERATE_SELF_SIGNED" = "true" ]; then
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
                
                # Copy the newly built iPXE files to TFTP directory
                echo "Copying newly built iPXE files to TFTP directory..."
                cp /opt/fog/packages/tftp/*.pxe /tftpboot/ 2>/dev/null || true
                cp /opt/fog/packages/tftp/*.efi /tftpboot/ 2>/dev/null || true
                cp /opt/fog/packages/tftp/*.lkrn /tftpboot/ 2>/dev/null || true
                cp /opt/fog/packages/tftp/*.iso /tftpboot/ 2>/dev/null || true
                cp /opt/fog/packages/tftp/*.usb /tftpboot/ 2>/dev/null || true
                chown -R www-data:www-data /tftpboot
            else
                echo "Warning: iPXE recompilation failed, using pre-built binaries."
                echo "This may cause SSL certificate trust issues with self-signed certificates."
            fi
        else
            echo "Warning: iPXE build script not found, using pre-built binaries."
            echo "This may cause SSL certificate trust issues with self-signed certificates."
        fi
    else
        echo "iPXE recompilation not needed (HTTP or external certificates)."
        # Ensure pre-built iPXE files are available in TFTP directory
        if [ ! -f "/tftpboot/ipxe.pxe" ]; then
            echo "Copying pre-built iPXE files to TFTP directory..."
            cp /opt/fog/packages/tftp/*.pxe /tftpboot/ 2>/dev/null || true
            cp /opt/fog/packages/tftp/*.efi /tftpboot/ 2>/dev/null || true
            cp /opt/fog/packages/tftp/*.lkrn /tftpboot/ 2>/dev/null || true
            cp /opt/fog/packages/tftp/*.iso /tftpboot/ 2>/dev/null || true
            cp /opt/fog/packages/tftp/*.usb /tftpboot/ 2>/dev/null || true
            chown -R www-data:www-data /tftpboot
        fi
    fi
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

fogFirstStartInit() {
    echo "Executing FOG first start initialization..."
    if [ -e "/opt/fog/config/.fog-initiated" ] && [ "$FORCE_FIRST_START_INIT" != "True" ] && [ "$FORCE_FIRST_START_INIT" != "true" ]; then
        echo "First Start Init not needed. Continuing."
        return 0
    fi
    
    echo "FOG will be initialized through the web interface."
    echo "Please visit http://localhost/fog to complete the initial setup."
    
    touch "/opt/fog/config/.fog-initiated"
    echo "FOG first start initialization completed."
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

initialConfiguration() {
    echo "=== Begin Initial Configuration Phase ==="
    prepareDirectories
    configureFOGConfig
    configureApache
    configureSSL
    configureiPXE
    configureTFTP
    configureNFS
    configureFTP
    configureDHCP
    configureSecureBoot
    configureSupervisor
    echo "=== End Initial Configuration Phase ==="
}

bootstrappingEnvironment() {
    echo "=== Begin Bootstrap Phase ==="
    waitingForDatabase
    fogFirstStartInit
    echo "=== End Bootstrap Phase ==="
}

# BEGIN app functions
appRun() {
    initialConfiguration
    bootstrappingEnvironment
    echo "=== Begin Run Phase ==="
    echo "Starting FOG using supervisor with \"/etc/supervisor/conf.d/supervisord.conf\" config..."
    echo ""
    
    # Clean up any stale PID files before starting services
    echo "Cleaning up stale PID files..."
    rm -f /var/run/apache2/apache2.pid
    
    # Set timezone for all processes
    export TZ="${TZ:-UTC}"
    
    # Start supervisor (which will manage all FOG services)
    exec supervisord -n -c "/etc/supervisor/conf.d/supervisord.conf"
}

appInit() {
    echo "=== Running initial setup ==="
    initialConfiguration
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

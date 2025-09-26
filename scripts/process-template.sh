#!/bin/bash

# FOG Docker Template Processing Script
# 
# This script processes configuration templates for FOG Docker containers,
# handling special characters, conditional blocks, and placeholder replacement.
# It ensures consistent configuration generation across all FOG services.
#
# Features:
# - Handles conditional blocks ({{#VAR}}...{{/VAR}})
# - Escapes special characters for safe sed replacement
# - Validates all placeholders are processed
# - Supports comprehensive variable replacement
#
# Usage: process-template.sh <template_file> <output_file>
#
# Author: FOG Docker Project
# License: GPL v3
# Based on: FOG Project (https://github.com/FOGProject/fogproject)

set -e

# Function to escape special characters for sed
escape_sed() {
    printf '%s\n' "$1" | sed 's/[[\.*^$()+?{|]/\\&/g'
}

# Function to process a template file
process_template() {
    local template_file="$1"
    local output_file="$2"
    local temp_file="/tmp/template_processing_$$"
    
    echo "Processing template: $template_file -> $output_file"
    
    # Start with the template
    cp "$template_file" "$temp_file"
    
    # Handle conditional sections first
    if [[ "$FOG_INTERNAL_HTTPS_ENABLED" = "true" ]]; then
        echo "  - Enabling HTTPS configuration"
        # Remove conditional markers and keep the content
        sed -i 's/{{#FOG_INTERNAL_HTTPS_ENABLED}}//g' "$temp_file"
        sed -i 's/{{\/FOG_INTERNAL_HTTPS_ENABLED}}//g' "$temp_file"
    else
        echo "  - Disabling HTTPS configuration"
        # Remove the entire conditional block
        sed -i '/{{#FOG_INTERNAL_HTTPS_ENABLED}}/,/{{\/FOG_INTERNAL_HTTPS_ENABLED}}/d' "$temp_file"
    fi
    
    # Process all remaining placeholders
    local placeholders=(
        "FOG_DB_HOST"
        "FOG_DB_PORT" 
        "FOG_DB_NAME"
        "FOG_DB_USER"
        "FOG_DB_PASS"
        "TZ"
        "FOG_TFTP_HOST"
        "FOG_STORAGE_HOST"
        "FOG_WOL_HOST"
        "FOG_MULTICAST_INTERFACE"
        "FOG_WEB_HOST"
        "FOG_WEB_ROOT"
        "FOG_APACHE_PORT"
        "FOG_APACHE_SSL_PORT"
        "FOG_INTERNAL_HTTPS_ENABLED"
        "FOG_HTTP_PROTOCOL"
        "FOG_SSL_PATH"
        "FOG_SSL_CERT_FILE"
        "FOG_SSL_KEY_FILE"
        "FOG_USER"
        "FOG_PASS"
        "FOG_DHCP_SUBNET"
        "FOG_DHCP_NETMASK"
        "FOG_DHCP_ROUTER"
        "FOG_DHCP_DOMAIN_NAME"
        "FOG_DHCP_DEFAULT_LEASE_TIME"
        "FOG_DHCP_MAX_LEASE_TIME"
        "FOG_DHCP_START_RANGE"
        "FOG_DHCP_END_RANGE"
        "FOG_DHCP_BOOTFILE_BIOS"
        "FOG_DHCP_BOOTFILE_UEFI32"
        "FOG_DHCP_BOOTFILE_UEFI64"
        "FOG_DHCP_BOOTFILE_ARM32"
        "FOG_DHCP_BOOTFILE_ARM64"
        "FOG_DHCP_HTTPBOOT_ENABLED"
        "FOG_DHCP_DNS"
    )
    
    for placeholder in "${placeholders[@]}"; do
        local var_name="$placeholder"  # Use the placeholder name directly
        if [[ "$placeholder" =~ ^(DB_|FOG_) ]]; then
            var_name="$placeholder"
        elif [[ "$placeholder" =~ ^(TZ)$ ]]; then
            var_name="$placeholder"
        fi
        
        local value="${!var_name}"
        if [[ -n "$value" ]]; then
            local escaped_value=$(escape_sed "$value")
            sed -i "s#{{$placeholder}}#$escaped_value#g" "$temp_file"
            echo "  - Replaced {{$placeholder}} with: $value"
        else
            echo "  - WARNING: Variable $var_name is empty or undefined"
        fi
    done
    
    # Validate that no placeholders remain
    if grep -q "{{" "$temp_file"; then
        echo "  - ERROR: Unprocessed placeholders found:"
        grep -n "{{" "$temp_file" | head -5
        echo "  - Template processing failed!"
        rm -f "$temp_file"
        return 1
    fi
    
    # Move to final location
    mv "$temp_file" "$output_file"
    echo "  - Template processing completed successfully"
    return 0
}

# Function to create FTP user safely
create_ftp_user() {
    local username="$1"
    local password="$2"
    local home_dir="$3"
    
    echo "Creating FTP user: $username"
    
    # Create user if it doesn't exist
    if ! id "$username" &>/dev/null; then
        useradd -r -s /bin/bash -d "$home_dir" -m "$username"
        echo "  - User created"
    else
        echo "  - User already exists"
    fi
    
    # Set password
    echo "$username:$password" | chpasswd
    echo "  - Password set"
    
    # Set ownership
    chown -R "$username:$username" "$home_dir"
    echo "  - Ownership set for $home_dir"
}

# Main processing function
main() {
    local template_file="$1"
    local output_file="$2"
    
    if [[ -z "$template_file" || -z "$output_file" ]]; then
        echo "Usage: $0 <template_file> <output_file>"
        exit 1
    fi
    
    if [[ ! -f "$template_file" ]]; then
        echo "ERROR: Template file not found: $template_file"
        exit 1
    fi
    
    process_template "$template_file" "$output_file"
}

# If script is called directly, run main function
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

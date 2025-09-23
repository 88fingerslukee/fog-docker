#!/bin/bash

# FOG Docker Secure Boot Key Generation Script
#
# This script generates the necessary keys and certificates for FOG Secure Boot
# functionality. It creates a Machine Owner Key (MOK) and associated certificates
# for signing iPXE binaries and bootloaders.
#
# Features:
# - Generates MOK private key and certificate
# - Creates ESP (EFI System Partition) certificate
# - Validates key generation with comprehensive error handling
# - Supports custom key directories via environment variables
#
# Environment Variables:
# - FOG_SECURE_BOOT_KEYS_DIR: Directory for private keys (default: /opt/fog/secure-boot/keys)
# - FOG_SECURE_BOOT_CERT_DIR: Directory for certificates (default: /opt/fog/secure-boot/certs)
#
# Usage: generate-keys.sh
#
# Author: FOG Docker Project
# License: GPL v3
# Based on: FOG Project (https://github.com/FOGProject/fogproject)

set -e

# Use environment variables or defaults
KEYS_DIR="${FOG_SECURE_BOOT_KEYS_DIR:-/opt/fog/secure-boot/keys}"
CERT_DIR="${FOG_SECURE_BOOT_CERT_DIR:-/opt/fog/secure-boot/certs}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check dependencies
check_dependencies() {
    log_info "Checking Secure Boot dependencies..."
    
    local deps=("openssl" "sbsign")
    local missing_deps=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing_deps+=("$dep")
        fi
    done
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        log_error "Missing required dependencies: ${missing_deps[*]}"
        log_error "Please install: apt-get install sbsigntool efitools"
        exit 1
    fi
    
    log_info "✓ All dependencies available"
}

# Check entropy availability
check_entropy() {
    log_info "Checking entropy availability..."
    
    if [ ! -r /dev/random ]; then
        log_error "/dev/random is not readable"
        exit 1
    fi
    
    # Test entropy generation speed
    local start_time=$(date +%s)
    timeout 10s dd if=/dev/random bs=1 count=1 >/dev/null 2>&1
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    if [ $duration -gt 5 ]; then
        log_warn "Entropy generation is slow (${duration}s). This may cause delays."
        log_warn "Consider using haveged or rng-tools for better entropy."
    else
        log_info "✓ Entropy generation is adequate"
    fi
}

# Check disk space
check_disk_space() {
    log_info "Checking available disk space..."
    
    local required_space=50  # MB
    local available_space=$(df /opt | awk 'NR==2 {print int($4/1024)}')
    
    if [ $available_space -lt $required_space ]; then
        log_error "Insufficient disk space. Required: ${required_space}MB, Available: ${available_space}MB"
        exit 1
    fi
    
    log_info "✓ Sufficient disk space available (${available_space}MB)"
}

# Create directories with proper permissions
create_directories() {
    log_info "Creating Secure Boot directories..."
    
    mkdir -p "$KEYS_DIR" "$CERT_DIR"
    chmod 700 "$KEYS_DIR"  # Private keys need restricted access
    chmod 755 "$CERT_DIR"  # Certificates can be readable
    
    log_info "✓ Directories created with proper permissions"
}

# Generate private key with validation
generate_private_key() {
    log_info "Generating private key..."
    
    local key_file="$KEYS_DIR/fog.key"
    local start_time=$(date +%s)
    
    if ! openssl genrsa -out "$key_file" 2048 2>/dev/null; then
        log_error "Failed to generate private key"
        log_error "This may be due to insufficient entropy or disk space"
        exit 1
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Validate the generated key
    if ! openssl rsa -in "$key_file" -check -noout 2>/dev/null; then
        log_error "Generated private key is invalid"
        rm -f "$key_file"
        exit 1
    fi
    
    chmod 600 "$key_file"
    log_info "✓ Private key generated successfully (${duration}s)"
}

# Generate certificate with validation
generate_certificate() {
    log_info "Generating certificate..."
    
    local key_file="$KEYS_DIR/fog.key"
    local cert_file="$CERT_DIR/fog.crt"
    
    if ! openssl req -new -x509 -key "$key_file" -out "$cert_file" -days 3650 \
        -subj "/C=US/ST=State/L=City/O=FOG Project/CN=FOG Secure Boot" 2>/dev/null; then
        log_error "Failed to generate certificate"
        exit 1
    fi
    
    # Validate the generated certificate
    if ! openssl x509 -in "$cert_file" -text -noout >/dev/null 2>&1; then
        log_error "Generated certificate is invalid"
        rm -f "$cert_file"
        exit 1
    fi
    
    chmod 644 "$cert_file"
    log_info "✓ Certificate generated successfully"
}

# Generate DER format certificate
generate_der_certificate() {
    log_info "Generating DER format certificate..."
    
    local cert_file="$CERT_DIR/fog.crt"
    local der_file="$CERT_DIR/fog.der"
    
    if ! openssl x509 -in "$cert_file" -outform DER -out "$der_file" 2>/dev/null; then
        log_error "Failed to generate DER certificate"
        exit 1
    fi
    
    chmod 644 "$der_file"
    log_info "✓ DER certificate generated successfully"
}

# Generate ESP certificate
generate_esp_certificate() {
    log_info "Generating ESP certificate..."
    
    local cert_file="$CERT_DIR/fog.crt"
    local esp_file="$CERT_DIR/fog.esp"
    
    if ! openssl x509 -in "$cert_file" -outform DER -out "$esp_file" 2>/dev/null; then
        log_error "Failed to generate ESP certificate"
        exit 1
    fi
    
    chmod 644 "$esp_file"
    log_info "✓ ESP certificate generated successfully"
}

# Sign ESP certificate
sign_esp_certificate() {
    log_info "Signing ESP certificate..."
    
    local key_file="$KEYS_DIR/fog.key"
    local cert_file="$CERT_DIR/fog.crt"
    local esp_file="$CERT_DIR/fog.esp"
    local signed_file="$CERT_DIR/fog.esp.signed"
    
    if ! sbsign --key "$key_file" --cert "$cert_file" --output "$signed_file" "$esp_file" 2>/dev/null; then
        log_error "Failed to sign ESP certificate"
        log_error "This may indicate a problem with the key or certificate"
        exit 1
    fi
    
    chmod 644 "$signed_file"
    log_info "✓ ESP certificate signed successfully"
}

# Generate MOK certificate
generate_mok_certificate() {
    log_info "Generating MOK certificate..."
    
    local key_file="$KEYS_DIR/fog.key"
    local mok_file="$CERT_DIR/fog.mok.crt"
    
    if ! openssl req -new -x509 -key "$key_file" -out "$mok_file" -days 3650 \
        -subj "/C=US/ST=State/L=City/O=FOG Project/CN=FOG MOK" 2>/dev/null; then
        log_error "Failed to generate MOK certificate"
        exit 1
    fi
    
    # Validate the generated MOK certificate
    if ! openssl x509 -in "$mok_file" -text -noout >/dev/null 2>&1; then
        log_error "Generated MOK certificate is invalid"
        rm -f "$mok_file"
        exit 1
    fi
    
    chmod 644 "$mok_file"
    log_info "✓ MOK certificate generated successfully"
}

# Validate all generated files
validate_generated_files() {
    log_info "Validating generated Secure Boot files..."
    
    local files=(
        "$KEYS_DIR/fog.key"
        "$CERT_DIR/fog.crt"
        "$CERT_DIR/fog.der"
        "$CERT_DIR/fog.esp"
        "$CERT_DIR/fog.esp.signed"
        "$CERT_DIR/fog.mok.crt"
    )
    
    local missing_files=()
    
    for file in "${files[@]}"; do
        if [ ! -f "$file" ]; then
            missing_files+=("$file")
        fi
    done
    
    if [ ${#missing_files[@]} -gt 0 ]; then
        log_error "Missing generated files: ${missing_files[*]}"
        exit 1
    fi
    
    log_info "✓ All Secure Boot files generated and validated"
}

# Main function
main() {
    log_info "Starting Secure Boot key generation..."
    
    check_dependencies
    check_entropy
    check_disk_space
    create_directories
    generate_private_key
    generate_certificate
    generate_der_certificate
    generate_esp_certificate
    sign_esp_certificate
    generate_mok_certificate
    validate_generated_files
    
    log_info "Secure Boot key generation completed successfully!"
    echo ""
    echo "Generated files:"
    echo "  Private Key: $KEYS_DIR/fog.key"
    echo "  Certificate: $CERT_DIR/fog.crt"
    echo "  DER Certificate: $CERT_DIR/fog.der"
    echo "  ESP Certificate: $CERT_DIR/fog.esp"
    echo "  Signed ESP: $CERT_DIR/fog.esp.signed"
    echo "  MOK Certificate: $CERT_DIR/fog.mok.crt"
}

# Run main function
main "$@"

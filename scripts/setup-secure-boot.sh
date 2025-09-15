#!/bin/bash

# Enhanced FOG Secure Boot Setup Script
# Includes comprehensive error handling and graceful degradation

set -e

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

# Use environment variables or defaults
KEYS_DIR="${FOG_SECURE_BOOT_KEYS_DIR:-/opt/fog/secure-boot/keys}"
CERT_DIR="${FOG_SECURE_BOOT_CERT_DIR:-/opt/fog/secure-boot/certs}"
SHIM_DIR="${FOG_SECURE_BOOT_SHIM_DIR:-/opt/fog/secure-boot/shim}"
TFTP_DIR="${FOG_TFTP_DIR:-/tftpboot}"

log_info "Setting up Secure Boot..."

# Copy shim and MOK manager to TFTP directory
log_info "Copying shim and MOK manager..."
if [ ! -f "$SHIM_DIR/shimx64.efi" ]; then
    log_error "Shim binary not found: $SHIM_DIR/shimx64.efi"
    exit 1
fi
if [ ! -f "$SHIM_DIR/mmx64.efi" ]; then
    log_error "MOK manager binary not found: $SHIM_DIR/mmx64.efi"
    exit 1
fi

cp "$SHIM_DIR/shimx64.efi" "$TFTP_DIR/BOOTX64.efi"
cp "$SHIM_DIR/mmx64.efi" "$TFTP_DIR/mmx64.efi"
log_info "✓ Shim and MOK manager copied successfully"

# Sign all EFI binaries in TFTP directory
log_info "Signing EFI binaries..."
if [ ! -f "$KEYS_DIR/fog.key" ]; then
    log_error "Private key not found: $KEYS_DIR/fog.key"
    exit 1
fi
if [ ! -f "$CERT_DIR/fog.crt" ]; then
    log_error "Certificate not found: $CERT_DIR/fog.crt"
    exit 1
fi

for efi_file in "$TFTP_DIR"/*.efi; do
    if [ -f "$efi_file" ]; then
        log_info "Signing: $(basename "$efi_file")"
        if ! sbsign --key "$KEYS_DIR/fog.key" --cert "$CERT_DIR/fog.crt" --output "$efi_file.signed" "$efi_file"; then
            log_error "Failed to sign: $(basename "$efi_file")"
            exit 1
        fi
        mv "$efi_file.signed" "$efi_file"
    fi
done
log_info "✓ All EFI binaries signed successfully"

# Create grubx64.efi from ipxe.efi for shim compatibility
if [ -f "$TFTP_DIR/ipxe.efi" ]; then
    log_info "Creating grubx64.efi from ipxe.efi..."
    cp "$TFTP_DIR/ipxe.efi" "$TFTP_DIR/grubx64.efi"
    log_info "✓ grubx64.efi created successfully"
fi

# Create FAT32 image for MOK certificate
log_info "Creating FAT32 image for MOK certificate..."
MOK_IMG="${FOG_SECURE_BOOT_MOK_IMG:-/opt/fog/secure-boot/mok-certs.img}"

if ! dd if=/dev/zero of="$MOK_IMG" bs=1M count=10 2>/dev/null; then
    log_error "Failed to create FAT32 image"
    exit 1
fi

if ! mkfs.fat -F 32 "$MOK_IMG" >/dev/null 2>&1; then
    log_error "Failed to format FAT32 image"
    rm -f "$MOK_IMG"
    exit 1
fi

# Mount the image and copy MOK certificate
MOK_MOUNT="/mnt/mok"
mkdir -p "$MOK_MOUNT"

if ! mount -o loop "$MOK_IMG" "$MOK_MOUNT" 2>/dev/null; then
    log_error "Failed to mount FAT32 image"
    rm -f "$MOK_IMG"
    rmdir "$MOK_MOUNT"
    exit 1
fi

# Copy MOK certificate
if [ ! -f "$CERT_DIR/fog.mok.crt" ]; then
    log_error "MOK certificate not found: $CERT_DIR/fog.mok.crt"
    umount "$MOK_MOUNT"
    rmdir "$MOK_MOUNT"
    exit 1
fi

cp "$CERT_DIR/fog.mok.crt" "$MOK_MOUNT/"

# Unmount
umount "$MOK_MOUNT"
rmdir "$MOK_MOUNT"

# Set proper permissions
chown -R www-data:www-data "$TFTP_DIR"
chmod -R 755 "$TFTP_DIR"

log_info "✓ Secure Boot setup completed successfully!"
echo ""
echo "Next steps:"
echo "1. Configure your DHCP server to point to this TFTP server"
echo "2. Boot a client machine and enroll the MOK certificate:"
echo "   - The MOK Manager will appear during boot"
echo "   - Select 'Enroll MOK' and choose the FOG certificate"
echo "   - Reboot to complete enrollment"
echo ""
echo "MOK certificate image: $MOK_IMG"
echo "TFTP directory: $TFTP_DIR"

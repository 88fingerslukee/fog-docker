#!/bin/bash
# FOG Secure Boot Setup Script
# Sets up shim, MOK manager, and signs iPXE binaries

set -e

# Configuration
TFTP_DIR="/tftpboot"
KEYS_DIR="/opt/fog/secure-boot/keys"
CERT_DIR="/opt/fog/secure-boot/certs"
SHIM_SOURCE_DIR="/opt/fog/secure-boot/shim"

echo "=========================================="
echo "FOG Secure Boot Setup"
echo "=========================================="

# Check if keys exist
if [ ! -f "$KEYS_DIR/fog.key" ] || [ ! -f "$CERT_DIR/fog.crt" ]; then
    echo "Error: Secure Boot keys not found!"
    echo "Please run generate-keys.sh first or ensure keys are in place."
    exit 1
fi

# Copy shim and MOK manager from container
echo "Copying shim and MOK manager..."

# Copy shim (rename to BOOTX64.efi for UEFI compatibility)
if [ -f "$SHIM_SOURCE_DIR/shimx64.efi" ]; then
    cp "$SHIM_SOURCE_DIR/shimx64.efi" "$TFTP_DIR/BOOTX64.efi"
    echo "✓ Shim copied as BOOTX64.efi"
else
    echo "Error: Shim binary not found at $SHIM_SOURCE_DIR/shimx64.efi"
    echo "Please ensure the container was built with Debian shim-signed package"
    exit 1
fi

# Copy MOK manager
if [ -f "$SHIM_SOURCE_DIR/mmx64.efi" ]; then
    cp "$SHIM_SOURCE_DIR/mmx64.efi" "$TFTP_DIR/mmx64.efi"
    echo "✓ MOK Manager copied"
else
    echo "Error: MOK Manager binary not found at $SHIM_SOURCE_DIR/mmx64.efi"
    echo "Please ensure the container was built with Debian shim-signed package"
    exit 1
fi

# Sign iPXE binaries
echo "Signing iPXE binaries..."

# Find and sign all iPXE binaries
for binary in "$TFTP_DIR"/*.efi; do
    if [ -f "$binary" ]; then
        echo "Signing $(basename "$binary")..."
        sbsign --key "$KEYS_DIR/fog.key" --cert "$CERT_DIR/fog.crt" --output "$binary.signed" "$binary"
        mv "$binary.signed" "$binary"
        echo "✓ $(basename "$binary") signed"
    fi
done

# Create grubx64.efi from iPXE (for shim compatibility)
if [ -f "$TFTP_DIR/ipxe.efi" ]; then
    cp "$TFTP_DIR/ipxe.efi" "$TFTP_DIR/grubx64.efi"
    echo "✓ Created grubx64.efi from ipxe.efi"
fi

# Create FAT32 image for MOK certificates
echo "Creating FAT32 image for MOK certificates..."
FAT32_IMAGE="/opt/fog/secure-boot/mok-certs.img"
FAT32_MOUNT="/opt/fog/secure-boot/mok-certs"

# Create FAT32 image file (10MB should be plenty for certificates)
if [ ! -f "$FAT32_IMAGE" ]; then
    dd if=/dev/zero of="$FAT32_IMAGE" bs=1M count=10 2>/dev/null
    mkfs.fat -F 32 "$FAT32_IMAGE" >/dev/null 2>&1
    echo "✓ Created FAT32 image file"
fi

# Mount the FAT32 image
mkdir -p "$FAT32_MOUNT"
if ! mountpoint -q "$FAT32_MOUNT"; then
    mount -o loop "$FAT32_IMAGE" "$FAT32_MOUNT"
    echo "✓ Mounted FAT32 image"
fi

# Copy MOK certificate to FAT32 image
if [ -f "$CERT_DIR/ENROL_THIS_KEY_IN_MOK_MANAGER.cer" ]; then
    cp "$CERT_DIR/ENROL_THIS_KEY_IN_MOK_MANAGER.cer" "$FAT32_MOUNT/"
    echo "✓ MOK certificate copied to FAT32 image"
fi

# Set proper permissions
chown -R www-data:www-data "$TFTP_DIR"
chmod 644 "$TFTP_DIR"/*.efi

echo ""
echo "✓ Secure Boot setup completed!"
echo ""
echo "Next steps:"
echo "  1. Ensure your DHCP server points to BOOTX64.efi"
echo "  2. Copy the FAT32 image to a USB drive:"
echo "     docker cp fog-server:/opt/fog/secure-boot/mok-certs.img /path/to/usb/"
echo "  3. Boot a machine with Secure Boot enabled"
echo "  4. Use MOK Manager to enroll the key from the USB drive"
echo "  5. Reboot and the machine should boot into FOG"
echo ""
echo "Alternative: Mount the FAT32 image directly:"
echo "  docker cp fog-server:/opt/fog/secure-boot/mok-certs.img /path/to/mount/"
echo "  sudo mount -o loop /path/to/mount/mok-certs.img /mnt/fat32"
echo ""

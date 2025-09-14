#!/bin/bash
# FOG Secure Boot Key Generation Script
# Based on the tutorial by KMEH on the FOG Project forums

set -e

# Configuration
KEYS_DIR="/opt/fog/secure-boot/keys"
CERT_DIR="/opt/fog/secure-boot/certs"

# Create directories if they don't exist
mkdir -p "$KEYS_DIR" "$CERT_DIR"

echo "=========================================="
echo "FOG Secure Boot Key Generation"
echo "=========================================="

# Generate private key
echo "Generating private key..."
openssl req -new -x509 -newkey rsa:2048 -subj "/CN=FOG Secure Boot Key/" -keyout "$KEYS_DIR/fog.key" -out "$CERT_DIR/fog.crt" -days 3650 -nodes -sha256

# Generate DER format certificate (required for MOK)
echo "Converting certificate to DER format..."
openssl x509 -in "$CERT_DIR/fog.crt" -outform DER -out "$CERT_DIR/fog.der"

# Generate ESP format certificate (for UEFI)
echo "Converting certificate to ESP format..."
cert-to-efi-sig-list -g "$(uuidgen)" "$CERT_DIR/fog.crt" "$CERT_DIR/fog.esl"

# Sign the ESP certificate
echo "Signing ESP certificate..."
sign-efi-sig-list -k "$KEYS_DIR/fog.key" -c "$CERT_DIR/fog.crt" PK "$CERT_DIR/fog.esl" "$CERT_DIR/fog.pk.auth"

# Create MOK certificate with proper filename for Dell compatibility
echo "Creating MOK certificate..."
cp "$CERT_DIR/fog.der" "$CERT_DIR/ENROL_THIS_KEY_IN_MOK_MANAGER.cer"

# Set proper permissions
chmod 644 "$CERT_DIR"/*.cer "$CERT_DIR"/*.der "$CERT_DIR"/*.esl "$CERT_DIR"/*.auth
chmod 600 "$KEYS_DIR"/*.key

echo ""
echo "✓ Secure Boot keys generated successfully!"
echo ""
echo "Files created:"
echo "  Private Key: $KEYS_DIR/fog.key"
echo "  Certificate: $CERT_DIR/fog.crt"
echo "  DER Certificate: $CERT_DIR/fog.der"
echo "  ESP Certificate: $CERT_DIR/fog.esl"
echo "  Signed ESP: $CERT_DIR/fog.pk.auth"
echo "  MOK Certificate: $CERT_DIR/ENROL_THIS_KEY_IN_MOK_MANAGER.cer"
echo ""
echo "To enroll the key:"
echo "  1. Copy ENROL_THIS_KEY_IN_MOK_MANAGER.cer to a FAT32 USB drive"
echo "  2. Boot a machine with Secure Boot enabled"
echo "  3. Use MOK Manager to enroll the key"
echo "  4. Reboot and the machine should boot into FOG"
echo ""

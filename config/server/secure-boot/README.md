# FOG Secure Boot Setup

This directory contains scripts and tools for implementing Secure Boot support in FOG using shim and MOK (Machine Owner Key) management.

## Overview

Secure Boot support allows FOG to work with UEFI Secure Boot enabled systems by using Microsoft-signed shim binaries and custom key enrollment through MOK Manager.

## Current Implementation Status

This implementation provides:
- ✅ **Automatic iPXE compilation** with `SHIM_CMD` support at build time
- ✅ **Debian shim integration** with Microsoft-signed binaries
- ✅ **Automatic key generation** and binary signing
- ✅ **Complete automation** via environment variables
- ✅ **Docker container integration** with proper file management

**Note**: This is an experimental feature that requires testing across various UEFI implementations.

## Files

- `generate-keys.sh` - Generates Secure Boot keys and certificates
- `setup-secure-boot.sh` - Sets up shim, MOK manager, and signs iPXE binaries
- `README.md` - This documentation file

## Prerequisites

**Note**: iPXE is automatically compiled with `SHIM_CMD` support, and shim/MOK Manager binaries are automatically included from Debian packages during container build.

## Setup Process

### Automatic Setup (Recommended)

The easiest way to set up Secure Boot is to use the automatic configuration:

1. **Enable Secure Boot** in your `.env` file:
   ```bash
   FOG_SECURE_BOOT_ENABLED=true
   ```

2. **Deploy the container**:
   ```bash
   docker compose up -d
   ```

The container will automatically:
- Generate Secure Boot keys and certificates
- Set up shim and MOK manager from Debian packages
- Sign iPXE binaries with custom keys
- Create `BOOTX64.efi` for DHCP configuration

### Manual Setup

If you prefer manual control or need to troubleshoot:

#### 1. Generate Keys

Run the key generation script:

```bash
/opt/fog/secure-boot/scripts/generate-keys.sh
```

This creates:
- Private key (`fog.key`)
- Certificate (`fog.crt`)
- DER format certificate (`fog.der`)
- ESP format certificate (`fog.esl`)
- Signed ESP certificate (`fog.pk.auth`)
- MOK certificate (`ENROL_THIS_KEY_IN_MOK_MANAGER.cer`)

#### 2. Setup Secure Boot

Run the setup script:

```bash
/opt/fog/secure-boot/scripts/setup-secure-boot.sh
```

This:
- Copies shim and MOK manager to TFTP directory
- Signs all iPXE binaries
- Creates grubx64.efi for shim compatibility
- Creates a FAT32 image file with the MOK certificate
- Sets proper permissions

### 3. Configure DHCP

Point your DHCP server to the shim binary (which is automatically created as `BOOTX64.efi`):

```
filename "BOOTX64.efi";
```

**Note**: The container automatically creates `BOOTX64.efi` from the Debian shim binary during Secure Boot setup.

### 4. Verify Setup

You can verify the Secure Boot setup is working:

```bash
# Check if Secure Boot files are present
docker exec fog-server ls -la /tftpboot/ | grep -E "(BOOTX64|mmx64|ipxe)"

# Check if keys were generated
docker exec fog-server ls -la /opt/fog/secure-boot/keys/

# Check if certificates were created
docker exec fog-server ls -la /opt/fog/secure-boot/certs/
```

### 5. Enroll Keys

1. Copy the FAT32 image (containing the MOK certificate) to a USB drive:
   ```bash
   docker cp fog-server:/opt/fog/secure-boot/mok-certs.img /path/to/usb/
   ```
2. Boot a machine with Secure Boot enabled
3. Use MOK Manager to enroll the key
4. Reboot - the machine should now boot into FOG

## Environment Variables

The following environment variable controls Secure Boot behavior:

- `FOG_SECURE_BOOT_ENABLED` - Enable/disable Secure Boot setup and automatically run complete setup (default: false)

## Troubleshooting

### Dell Machines

Some Dell machines have UEFI bugs that require specific workarounds:

1. **Boot Entry Name Issue**: Create files matching the network card boot entry names
2. **Key Enrollment Issue**: Use specific certificate filenames like `ENROL_THIS_KEY_IN_MOK_MANAGER.cer`

### Common Issues

- **Shim not loading**: Ensure DHCP points to `BOOTX64.efi` and Secure Boot is enabled in UEFI
- **MOK Manager not appearing**: Check that `mmx64.efi` is present in TFTP directory
- **Key enrollment fails**: Verify certificate is on FAT32 USB drive and UEFI Secure Boot is enabled
- **iPXE not loading**: Ensure iPXE binary is signed and Secure Boot keys are properly enrolled
- **Container startup issues**: Check that `FOG_SECURE_BOOT_ENABLED=true` is set in `.env` file
- **Setup script fails**: Ensure the container was built with Debian shim-signed package

## References

- [FOG Project Forum - Secure Boot Tutorial](https://forums.fogproject.org/)
- [rhboot/shim GitHub](https://github.com/rhboot/shim)
- [iPXE shim command documentation](https://ipxe.org/cmd/shim)

## Security Notes

- Keep private keys secure and never distribute them
- The MOK certificate can be safely distributed for key enrollment
- Consider key rotation for production environments
- Monitor for UEFI firmware updates that might affect compatibility

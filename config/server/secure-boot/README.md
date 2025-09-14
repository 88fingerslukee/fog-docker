# FOG Secure Boot Setup

This directory contains scripts and tools for implementing Secure Boot support in FOG using shim and MOK (Machine Owner Key) management.

## Overview

Secure Boot support allows FOG to work with UEFI Secure Boot enabled systems by using Microsoft-signed shim binaries and custom key enrollment through MOK Manager.

## Files

- `generate-keys.sh` - Generates Secure Boot keys and certificates
- `setup-secure-boot.sh` - Sets up shim, MOK manager, and signs iPXE binaries
- `README.md` - This documentation file

## Prerequisites

**Note**: iPXE is automatically compiled with `SHIM_CMD` support, and shim/MOK Manager binaries are automatically included from Debian packages during container build.

## Setup Process

### 1. Generate Keys

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

### 2. Setup Secure Boot

Run the setup script:

```bash
/opt/fog/secure-boot/scripts/setup-secure-boot.sh
```

This:
- Copies shim and MOK manager to TFTP directory
- Signs all iPXE binaries
- Creates grubx64.efi for shim compatibility
- Sets proper permissions

### 3. Configure DHCP

Point your DHCP server to the shim binary:

```
filename "BOOTX64.efi";
```

### 4. Enroll Keys

1. Copy `ENROL_THIS_KEY_IN_MOK_MANAGER.cer` to a FAT32 USB drive
2. Boot a machine with Secure Boot enabled
3. Use MOK Manager to enroll the key
4. Reboot - the machine should now boot into FOG

## Environment Variables

The following environment variables control Secure Boot behavior:

- `FOG_SECURE_BOOT_ENABLED` - Enable/disable Secure Boot setup (default: false)
- `FOG_SECURE_BOOT_AUTO_SETUP` - Automatically run setup on container start (default: false)

## Troubleshooting

### Dell Machines

Some Dell machines have UEFI bugs that require specific workarounds:

1. **Boot Entry Name Issue**: Create files matching the network card boot entry names
2. **Key Enrollment Issue**: Use specific certificate filenames like `ENROL_THIS_KEY_IN_MOK_MANAGER.cer`

### Common Issues

- **Shim not loading**: Ensure DHCP points to BOOTX64.efi
- **MOK Manager not appearing**: Check that mmx64.efi is present
- **Key enrollment fails**: Verify certificate is on FAT32 USB drive
- **iPXE not loading**: Ensure iPXE binary is signed and has shim command support

## References

- [FOG Project Forum - Secure Boot Tutorial](https://forums.fogproject.org/)
- [rhboot/shim GitHub](https://github.com/rhboot/shim)
- [iPXE shim command documentation](https://ipxe.org/cmd/shim)

## Security Notes

- Keep private keys secure and never distribute them
- The MOK certificate can be safely distributed for key enrollment
- Consider key rotation for production environments
- Monitor for UEFI firmware updates that might affect compatibility

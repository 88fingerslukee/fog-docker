# Network Boot Guide

This guide covers setting up PXE boot and HTTPBoot for FOG clients.

## Overview

FOG supports two network boot methods:
- **PXE Boot** (TFTP) - Traditional network booting via TFTP
- **HTTPBoot** (HTTP/HTTPS) - Modern network booting via HTTP (UEFI only)

## PXE Boot Setup

### For External DHCP Servers

Configure your existing DHCP server with these options:

**Option 66 (Next Server)**: `your-fog-server-ip`
**Option 67 (Boot File)**:
- **BIOS clients**: `undionly.kpxe`
- **UEFI clients**: `ipxe.efi`

### For FOG's Built-in DHCP

Enable FOG's DHCP server in your `.env` file:

```bash
FOG_DHCP_ENABLED=true
FOG_DHCP_SUBNET=192.168.1.0
FOG_DHCP_NETMASK=255.255.255.0
FOG_DHCP_ROUTER=192.168.1.1
FOG_DHCP_START_RANGE=192.168.1.100
FOG_DHCP_END_RANGE=192.168.1.200
FOG_DHCP_DNS=8.8.8.8
FOG_DHCP_BOOTFILE_BIOS=undionly.kpxe
FOG_DHCP_BOOTFILE_UEFI=ipxe.efi
```

## HTTPBoot Setup

HTTPBoot is automatically available for UEFI clients. No additional configuration needed!

### How HTTPBoot Works

1. **Client requests iPXE binary** via HTTP/HTTPS
2. **iPXE binary loads** and detects architecture
3. **Architecture detection** happens automatically
4. **FOG boot menu** is served based on client architecture

### HTTPBoot URLs

HTTPBoot URLs are automatically constructed as:
```
{{FOG_HTTP_PROTOCOL}}://{{FOG_WEB_HOST}}{{FOG_WEB_ROOT}}/service/ipxe/{{FOG_DHCP_BOOTFILE_UEFI}}
```

**Examples:**
- HTTP: `http://192.168.1.100/fog/service/ipxe/ipxe.efi`
- HTTPS: `https://fog.example.com/fog/service/ipxe/ipxe.efi`

### Architecture Support

**UEFI Systems (HTTPBoot supported):**
- x86_64 UEFI clients
- ARM64 UEFI clients
- Various network adapters (Intel, Realtek, etc.)

**Legacy BIOS Systems:**
- Must use traditional PXE boot via TFTP
- HTTPBoot not supported

## Boot File Architecture Detection

FOG uses intelligent architecture detection:

### The Boot Process

1. **Initial Boot**: Client downloads iPXE binary
2. **Architecture Detection**: iPXE detects client architecture (`${buildarch}`)
3. **Default Boot Script**: iPXE loads `default.ipxe` with architecture info
4. **FOG Boot Menu**: `boot.php` serves appropriate menu based on architecture

### Example Flow

```
Client → HTTPBoot URL → iPXE Binary → default.ipxe → boot.php → FOG Boot Menu
```

## Available Boot Files

### HTTPBoot Files (UEFI systems only)
- `ipxe.efi` - Standard UEFI clients (x86_64, ARM64, etc.)
- `intel.efi` - Intel network adapter clients
- `realtek.efi` - Realtek network adapter clients
- `snp.efi` - Secure Network PXE clients
- `snponly.efi` - Secure Network PXE only clients
- `arm64-efi/ipxe.efi` - ARM64 UEFI clients
- `arm64-efi/intel.efi` - Intel network adapter (ARM64)
- `arm64-efi/realtek.efi` - Realtek network adapter (ARM64)

### TFTP Files (BIOS systems)
- `undionly.kpxe` - Legacy BIOS clients
- `ipxe.kpxe` - Alternative BIOS clients

## Testing Network Boot

### Test HTTPBoot URLs

```bash
# Test x86_64 UEFI iPXE file
curl -I https://fog.progressive-sealing.com/fog/service/ipxe/ipxe.efi

# Test ARM64 UEFI iPXE file
curl -I https://fog.progressive-sealing.com/fog/service/ipxe/arm64-efi/ipxe.efi

# Test Intel network adapter iPXE files
curl -I https://fog.progressive-sealing.com/fog/service/ipxe/intel.efi
curl -I https://fog.progressive-sealing.com/fog/service/ipxe/arm64-efi/intel.efi
```

### Test TFTP Access

```bash
# Test TFTP connectivity
tftp your-fog-server
tftp> get undionly.kpxe
tftp> quit
```

## Troubleshooting

### PXE Boot Issues

1. **Verify TFTP server is accessible** from client machines
2. **Check port 69/UDP** is open and accessible
3. **Verify DHCP configuration** points to correct TFTP server
4. **Check DHCP option 66** (next-server) points to `FOG_TFTP_HOST`
5. **Verify DHCP option 67** (filename) is set to correct boot file

### HTTPBoot Issues

1. **Verify iPXE files are accessible** via HTTP/HTTPS
2. **Check protocol matches** your `FOG_HTTP_PROTOCOL` setting
3. **Test URLs directly** in a browser
4. **Verify reverse proxy** configuration (if using)

### Common Issues

- **"Failed to download nbp file"** - Check HTTPBoot URL accessibility
- **"Chainloading permission denied"** - Verify iPXE file permissions
- **Architecture detection fails** - Check `default.ipxe` file content

## Advanced Configuration

### Custom Boot Files

You can customize boot files by:
1. **Modifying `.env`** boot file variables
2. **Replacing iPXE binaries** in `/tftpboot/` directory
3. **Customizing `default.ipxe`** script

### Network Adapter Specific Boot

For specific network adapters:
- **Intel**: Use `intel.efi` or `arm64-efi/intel.efi`
- **Realtek**: Use `realtek.efi` or `arm64-efi/realtek.efi`
- **Generic**: Use `ipxe.efi` or `arm64-efi/ipxe.efi`

## Next Steps

After setting up network boot:

1. **[Configuration Guide](configuration.md)** - Configure FOG settings
2. **[SSL/HTTPS Setup](ssl-https.md)** - Set up HTTPS (optional)
3. **[Troubleshooting Guide](troubleshooting.md)** - Common issues and solutions

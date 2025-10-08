# DHCP Integration

This guide covers integrating FOG Docker with existing DHCP servers for PXE boot configuration.

## Overview

FOG Docker can work with any DHCP server by configuring the appropriate PXE boot options. This guide covers integration with:

- **ISC DHCP Server** (Linux/Unix)
- **Windows DHCP Server**
- **pfSense DHCP**
- **MikroTik RouterOS**
- **Ubiquiti UniFi**

## DHCP Configuration Requirements

### Required DHCP Options

For PXE boot to work, your DHCP server must provide:

- **Option 66 (Next Server)**: IP address of your FOG server (use `FOG_TFTP_HOST` value)
- **Option 67 (Boot File)**: Name of the boot file for the client architecture (use `FOG_DHCP_BOOTFILE_BIOS` or `FOG_DHCP_BOOTFILE_UEFI`)

### Boot File Names

| Client Type | Boot File | Environment Variable | Description |
|-------------|-----------|---------------------|-------------|
| Legacy BIOS | `undionly.kpxe` | `FOG_DHCP_BOOTFILE_BIOS` | Traditional BIOS PXE boot |
| UEFI x86_64 | `ipxe.efi` | `FOG_DHCP_BOOTFILE_UEFI` | UEFI 64-bit clients |
| UEFI ARM64 | `arm64-efi/ipxe.efi` | `FOG_DHCP_BOOTFILE_UEFI` | ARM64 UEFI clients |

## ISC DHCP Server (Linux/Unix)

### Basic Configuration

Edit `/etc/dhcp/dhcpd.conf`:

```dhcp
# Global settings
option domain-name "your-domain.com";
option domain-name-servers 8.8.8.8, 8.8.4.4;
default-lease-time 600;
max-lease-time 7200;

# Subnet configuration
subnet 192.168.1.0 netmask 255.255.255.0 {
    range 192.168.1.100 192.168.1.200;
    option routers 192.168.1.1;
    option broadcast-address 192.168.1.255;
    
    # FOG PXE Boot Configuration
    next-server 192.168.1.100;  # Your FOG server IP
    
    # BIOS clients
    if substring(option vendor-class-identifier, 0, 9) = "PXEClient" {
        if substring(option vendor-class-identifier, 15, 5) = "00000" {
            filename "undionly.kpxe";
        }
    }
    
    # UEFI clients
    if substring(option vendor-class-identifier, 0, 9) = "PXEClient" {
        if substring(option vendor-class-identifier, 15, 5) = "00007" {
            filename "ipxe.efi";
        }
    }
}
```

### Advanced Configuration with Architecture Detection

```dhcp
# Global settings
option domain-name "your-domain.com";
option domain-name-servers 8.8.8.8, 8.8.4.4;
default-lease-time 600;
max-lease-time 7200;

# Subnet configuration
subnet 192.168.1.0 netmask 255.255.255.0 {
    range 192.168.1.100 192.168.1.200;
    option routers 192.168.1.1;
    option broadcast-address 192.168.1.255;
    
    # FOG PXE Boot Configuration
    next-server 192.168.1.100;  # Your FOG server IP
    
    # Architecture detection and boot file selection
    if substring(option vendor-class-identifier, 0, 9) = "PXEClient" {
        # BIOS clients
        if substring(option vendor-class-identifier, 15, 5) = "00000" {
            filename "undionly.kpxe";
        }
        # UEFI x86_64 clients
        elsif substring(option vendor-class-identifier, 15, 5) = "00007" {
            filename "ipxe.efi";
        }
        # UEFI ARM64 clients
        elsif substring(option vendor-class-identifier, 15, 5) = "00008" {
            filename "arm64-efi/ipxe.efi";
        }
        # Default fallback
        else {
            filename "undionly.kpxe";
        }
    }
}
```

### Restart DHCP Service

```bash
# Restart DHCP server
sudo systemctl restart isc-dhcp-server

# Check status
sudo systemctl status isc-dhcp-server

# Check configuration
sudo dhcpd -t
```

## Windows DHCP Server

### Using DHCP Management Console

1. **Open DHCP Management Console**
2. **Right-click on your server** → Properties
3. **Go to Advanced tab**
4. **Click "Vendor Classes"** → Add
5. **Create vendor classes** for different architectures

### Using PowerShell

```powershell
# Set DHCP server options
Set-DhcpServerv4OptionValue -ComputerName "your-dhcp-server" -OptionId 66 -Value "192.168.1.100"
Set-DhcpServerv4OptionValue -ComputerName "your-dhcp-server" -OptionId 67 -Value "undionly.kpxe"

# For UEFI clients, create a policy
Add-DhcpServerv4Policy -Name "UEFI-Clients" -Condition OR -MacAddress "00-15-5D-*"
Set-DhcpServerv4Policy -Name "UEFI-Clients" -OptionId 67 -Value "ipxe.efi"
```

### Using netsh (Command Line)

```cmd
# Set global options
netsh dhcp server scope 192.168.1.0 set optionvalue 66 IPADDRESS 192.168.1.100
netsh dhcp server scope 192.168.1.0 set optionvalue 67 STRING "undionly.kpxe"

# For UEFI clients, create a reservation or policy
netsh dhcp server scope 192.168.1.0 add reservedip 192.168.1.150 00-15-5D-01-02-03 "UEFI-Client"
netsh dhcp server reservedip 192.168.1.150 set optionvalue 67 STRING "ipxe.efi"
```

## pfSense DHCP

### Web Interface Configuration

1. **Go to Services → DHCP Server**
2. **Edit your DHCP scope**
3. **Scroll down to "Additional BOOTP/DHCP Options"**
4. **Add the following options**:

| Number | Type | Value | Description |
|--------|------|-------|-------------|
| 66 | Text | `192.168.1.100` | Next Server (FOG server IP) |
| 67 | Text | `undionly.kpxe` | Boot File Name |

### Advanced Configuration

For different architectures, create multiple DHCP scopes or use custom options:

```bash
# In pfSense shell or config
# Option 66: Next Server
option 66 "192.168.1.100";

# Option 67: Boot File (BIOS)
option 67 "undionly.kpxe";

# For UEFI clients, you may need to create separate scopes
# or use MAC address reservations
```

## MikroTik RouterOS

### Using WinBox/WebFig

1. **Go to IP → DHCP Server**
2. **Edit your DHCP network**
3. **Go to "Options" tab**
4. **Add the following options**:

| Name | Code | Value |
|------|------|-------|
| next-server | 66 | `192.168.1.100` |
| boot-file-name | 67 | `undionly.kpxe` |

### Using Command Line

```bash
# Set DHCP options
/ip dhcp-server option add name="next-server" code=66 value=0xC0A80164
/ip dhcp-server option add name="boot-file-name" code=67 value="undionly.kpxe"

# Apply to DHCP network
/ip dhcp-server network set [find address="192.168.1.0/24"] next-server=192.168.1.100 boot-file-name=undionly.kpxe
```

## Ubiquiti UniFi

### Using UniFi Controller

1. **Go to Settings → Networks**
2. **Edit your network**
3. **Go to "Advanced" section**
4. **Enable "DHCP Options"**
5. **Add the following options**:

| Number | Type | Value |
|--------|------|-------|
| 66 | String | `192.168.1.100` |
| 67 | String | `undionly.kpxe` |

### Using JSON Configuration

```json
{
  "dhcpOptions": [
    {
      "number": 66,
      "type": "string",
      "value": "192.168.1.100"
    },
    {
      "number": 67,
      "type": "string", 
      "value": "undionly.kpxe"
    }
  ]
}
```

## HTTPBoot Configuration

For UEFI clients that support HTTPBoot, you can configure HTTP URLs instead of TFTP files:

### ISC DHCP Server

```dhcp
# HTTPBoot configuration for UEFI clients
if substring(option vendor-class-identifier, 0, 9) = "PXEClient" {
    if substring(option vendor-class-identifier, 15, 5) = "00007" {
        # HTTPBoot URL for UEFI clients
        option vendor-class-identifier "HTTPClient:Arch:00007:UNDI:003016";
        filename "http://192.168.1.100/fog/service/ipxe/ipxe.efi";
    }
}
```

### Windows DHCP Server

```powershell
# Set HTTPBoot option for UEFI clients
Set-DhcpServerv4OptionValue -ComputerName "your-dhcp-server" -OptionId 67 -Value "http://192.168.1.100/fog/service/ipxe/ipxe.efi"
```

## Testing DHCP Configuration

### Test DHCP Options

```bash
# Test DHCP options from client
dhclient -v eth0

# Check received options
cat /var/lib/dhcp/dhclient.leases

# Test PXE boot
# Boot a client machine and check if it receives correct options
```

### Verify PXE Boot

1. **Boot a client machine** via PXE
2. **Check if it receives** the correct next-server and boot file
3. **Verify the client** can download the boot file from FOG server
4. **Check FOG logs** for client connections

## Troubleshooting

### Common Issues

#### Client Not Getting PXE Options

**Symptoms**: Client boots but doesn't get PXE options
**Solutions**:
1. **Check DHCP server configuration**
2. **Verify DHCP server is running**
3. **Check network connectivity**
4. **Verify client is in correct subnet**

#### Wrong Boot File for Architecture

**Symptoms**: Client gets wrong boot file for its architecture
**Solutions**:
1. **Check vendor class identifier** detection
2. **Verify architecture-specific options**
3. **Test with different client types**

#### TFTP Timeout Errors

**Symptoms**: Client can't download boot file
**Solutions**:
1. **Check TFTP server is running** on FOG server
2. **Verify firewall rules** allow TFTP (port 69/UDP)
3. **Check file permissions** on boot files
4. **Test TFTP connectivity** manually

### Debug Commands

```bash
# Check DHCP server status
systemctl status isc-dhcp-server

# Check DHCP leases
cat /var/lib/dhcp/dhcpd.leases

# Test DHCP options
dhclient -v eth0

# Check TFTP server
systemctl status tftpd-hpa

# Test TFTP connectivity
tftp 192.168.1.100
tftp> get undionly.kpxe
tftp> quit
```

## Best Practices

### Security

1. **Use DHCP reservations** for known clients
2. **Implement DHCP snooping** on switches
3. **Monitor DHCP traffic** for anomalies
4. **Use secure boot** when possible

### Performance

1. **Optimize DHCP lease times** for your environment
2. **Use DHCP pools** efficiently
3. **Monitor DHCP server performance**
4. **Implement DHCP failover** for redundancy

### Maintenance

1. **Regular backup** of DHCP configuration
2. **Monitor DHCP logs** for issues
3. **Update boot files** when FOG is updated
4. **Test PXE boot** after any changes

## Next Steps

After configuring DHCP integration:

1. **[Network Boot Setup](network-boot.md)** - Verify PXE and HTTPBoot configuration
2. **[Configuration Guide](configuration.md)** - Optimize FOG configuration
3. **[Troubleshooting Guide](troubleshooting.md)** - Address any issues

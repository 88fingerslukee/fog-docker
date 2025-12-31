---
layout: default
title: Environment Variables
nav_order: 10
description: "Complete reference for all FOG Docker environment variables"
permalink: /environment-variables
---

# Environment Variables Reference

Complete reference for all FOG Docker environment variables.

## Core Configuration

### Required Variables

| Variable | Description | Example | Required |
|----------|-------------|---------|----------|
| `FOG_WEB_HOST` | Server IP/FQDN for web access | `192.168.1.100` | Yes |
| `FOG_DB_ROOT_PASSWORD` | MySQL root password | `your-secure-password` | Yes |

### Optional Core Variables

| Variable | Description | Example | Default |
|----------|-------------|---------|---------|
| `FOG_VERSION` | FOG version to install (dev only) | `stable`, `dev-branch` | `stable` |
| `FOG_GIT_URL` | Custom FOG repository URL (dev only) | `https://github.com/FOGProject/fogproject.git` | `https://github.com/FOGProject/fogproject.git` |

## Web Configuration

| Variable | Description | Example | Default |
|----------|-------------|---------|---------|
| `FOG_WEB_ROOT` | Web root path for FOG | `/fog` | `/fog` |
| `FOG_APACHE_PORT` | Internal Apache HTTP port | `80` | `80` |
| `FOG_APACHE_SSL_PORT` | Internal Apache HTTPS port | `443` | `443` |
| `FOG_APACHE_EXPOSED_PORT` | External HTTP port mapping | `80` | `80` |
| `FOG_APACHE_EXPOSED_SSL_PORT` | External HTTPS port mapping | `443` | `443` |

## Network Configuration

| Variable | Description | Example | Default |
|----------|-------------|---------|---------|
| `FOG_STORAGE_HOST` | Server IP/FQDN for storage access | `192.168.1.100` | `FOG_WEB_HOST` |
| `FOG_TFTP_HOST` | Server IP/FQDN for TFTP access | `192.168.1.100` | `FOG_WEB_HOST` |
| `FOG_WOL_HOST` | Server IP/FQDN for Wake-on-LAN | `192.168.1.100` | `FOG_WEB_HOST` |
| `FOG_HTTP_PROTOCOL` | Protocol (http/https) | `https` | `http` |
| `FOG_MULTICAST_INTERFACE` | Network interface for multicast | `eth0` | `eth0` |

## Database Configuration

| Variable | Description | Example | Default |
|----------|-------------|---------|---------|
| `FOG_DB_HOST` | Database host | `fog-db` | `fog-db` |
| `FOG_DB_PORT` | Database port | `3306` | `3306` |
| `FOG_DB_NAME` | Database name | `fog` | `fog` |
| `FOG_DB_USER` | Database user | `fogmaster` | `fogmaster` |
| `FOG_DB_PASS` | Database password | `fogmaster123` | `fogmaster123` |

## Database Migration Configuration

| Variable | Description | Example | Default |
|----------|-------------|---------|---------|
| `FOG_DB_MIGRATION_ENABLED` | Enable database migration | `true` | `false` |
| `FOG_DB_MIGRATION_FORCE` | Force migration over existing data | `true` | `false` |

## FOG User Configuration

| Variable | Description | Example | Default |
|----------|-------------|---------|---------|
| `FOG_USER` | FOG system user | `fogproject` | `fogproject` |
| `FOG_PASS` | FOG system password | `fogftp123` | `fogftp123` |

## FTP Configuration

| Variable | Description | Example | Default |
|----------|-------------|---------|---------|
| `FOG_FTP_PASV_MIN_PORT` | FTP passive mode minimum port | `21100` | `21100` |
| `FOG_FTP_PASV_MAX_PORT` | FTP passive mode maximum port | `21110` | `21110` |

## Secure Boot Configuration

| Variable | Description | Example | Default |
|----------|-------------|---------|---------|
| `FOG_SECURE_BOOT_ENABLED` | Enable Secure Boot support | `true` | `false` |
| `FOG_SECURE_BOOT_KEYS_DIR` | Secure Boot keys directory | `/opt/fog/secure-boot/keys` | `/opt/fog/secure-boot/keys` |
| `FOG_SECURE_BOOT_CERT_DIR` | Secure Boot certificates directory | `/opt/fog/secure-boot/certs` | `/opt/fog/secure-boot/certs` |
| `FOG_SECURE_BOOT_SHIM_DIR` | Secure Boot shim directory | `/opt/fog/secure-boot/shim` | `/opt/fog/secure-boot/shim` |
| `FOG_SECURE_BOOT_MOK_IMG` | Secure Boot MOK image file | `/opt/fog/secure-boot/mok-certs.img` | `/opt/fog/secure-boot/mok-certs.img` |

## DHCP Configuration

### Basic DHCP Settings

| Variable | Description | Example | Default |
|----------|-------------|---------|---------|
| `FOG_DHCP_ENABLED` | Enable FOG's DHCP server | `true` | `false` |
| `FOG_DHCP_SUBNET` | DHCP subnet | `192.168.1.0` | - |
| `FOG_DHCP_NETMASK` | DHCP netmask | `255.255.255.0` | - |
| `FOG_DHCP_ROUTER` | DHCP gateway | `192.168.1.1` | - |
| `FOG_DHCP_DOMAIN_NAME` | DHCP domain name | `fog.local` | - |

### DHCP IP Range

| Variable | Description | Example | Default |
|----------|-------------|---------|---------|
| `FOG_DHCP_START_RANGE` | DHCP start IP | `192.168.1.100` | - |
| `FOG_DHCP_END_RANGE` | DHCP end IP | `192.168.1.200` | - |

### DHCP Boot Files

| Variable | Description | Example | Default |
|----------|-------------|---------|---------|
| `FOG_DHCP_BOOTFILE_BIOS` | BIOS boot file (Arch:00000) | `undionly.kkpxe` | `undionly.kkpxe` |
| `FOG_DHCP_BOOTFILE_UEFI32` | UEFI 32-bit boot file (Arch:00002, 00006) | `i386-efi/snponly.efi` | `i386-efi/snponly.efi` |
| `FOG_DHCP_BOOTFILE_UEFI64` | UEFI 64-bit boot file (Arch:00007, 00008, 00009, plus SURFACE-PRO-4, Apple-Intel-Netboot) | `snponly.efi` | `snponly.efi` |
| `FOG_DHCP_BOOTFILE_ARM64` | UEFI ARM64 boot file (Arch:00011) | `arm64-efi/snponly.efi` | `arm64-efi/snponly.efi` |
| `FOG_DHCP_BOOTFILE_UEFI` | Legacy variable (maps to UEFI64) | `snponly.efi` | `snponly.efi` |

### DHCP Lease Times

| Variable | Description | Example | Default |
|----------|-------------|---------|---------|
| `FOG_DHCP_DEFAULT_LEASE_TIME` | Default lease time (seconds) | `600` | `600` |
| `FOG_DHCP_MAX_LEASE_TIME` | Maximum lease time (seconds) | `7200` | `7200` |

### DHCP DNS

| Variable | Description | Example | Default |
|----------|-------------|---------|---------|
| `FOG_DHCP_DNS` | DNS servers | `8.8.8.8` | `8.8.8.8` |

## SSL/HTTPS Configuration

### Apache SSL Settings

| Variable | Description | Example | Default |
|----------|-------------|---------|---------|
| `FOG_INTERNAL_HTTPS_ENABLED` | Enable internal HTTPS | `true` | `false` |
| `FOG_APACHE_SSL_CERT_FILE` | Apache SSL certificate file | `server.crt` | - |
| `FOG_APACHE_SSL_KEY_FILE` | Apache SSL key file | `server.key` | - |
| `FOG_APACHE_SSL_CN` | SSL certificate common name | `fog.example.com` | - |
| `FOG_APACHE_SSL_SAN` | SSL certificate SAN | `alt1.example.com,alt2.example.com` | - |

## Migration Configuration

| Variable | Description | Example | Default |
|----------|-------------|---------|---------|
| `FOG_DB_MIGRATION_ENABLED` | Enable database migration | `true` | `false` |
| `FOG_DB_MIGRATION_FORCE` | Force migration over existing data | `true` | `false` |

## Timezone Configuration

| Variable | Description | Example | Default |
|----------|-------------|---------|---------|
| `TZ` | Container timezone | `America/New_York` | `UTC` |

## Debug Configuration

| Variable | Description | Example | Default |
|----------|-------------|---------|---------|
| `DEBUG` | Enable debug mode | `true` | `false` |
| `FORCE_FIRST_START_INIT` | Force FOG first start initialization | `true` | `false` |

## Variable Relationships and Dependencies

### Host Configuration
The following variables work together to define how clients access FOG services:

- **`FOG_WEB_HOST`** - Primary hostname/IP for web access
- **`FOG_STORAGE_HOST`** - Hostname/IP for image storage (defaults to `FOG_WEB_HOST`)
- **`FOG_TFTP_HOST`** - Hostname/IP for TFTP/PXE boot (defaults to `FOG_WEB_HOST`)
- **`FOG_WOL_HOST`** - Hostname/IP for Wake-on-LAN (defaults to `FOG_WEB_HOST`)

### Port Configuration
Apache port variables control internal and external port mappings:

- **`FOG_APACHE_PORT`** - Internal HTTP port (usually 80)
- **`FOG_APACHE_SSL_PORT`** - Internal HTTPS port (usually 443)
- **`FOG_APACHE_EXPOSED_PORT`** - External HTTP port mapping
- **`FOG_APACHE_EXPOSED_SSL_PORT`** - External HTTPS port mapping

### SSL Configuration Scenarios
Choose one of these SSL scenarios:

**Scenario 1: External Certificates (Let's Encrypt, etc.)**
```bash
FOG_INTERNAL_HTTPS_ENABLED=true
FOG_HTTP_PROTOCOL=https
FOG_APACHE_SSL_CERT_FILE=fullchain.pem
FOG_APACHE_SSL_KEY_FILE=privkey.pem
```

**Scenario 2: Self-signed Certificates**
```bash
FOG_INTERNAL_HTTPS_ENABLED=true
FOG_HTTP_PROTOCOL=https
FOG_APACHE_SSL_CN=192.168.1.100
FOG_APACHE_SSL_SAN=alt1.domain.com,alt2.domain.com
```

**Scenario 3: Reverse Proxy (No Apache SSL)**
```bash
FOG_INTERNAL_HTTPS_ENABLED=false
FOG_HTTP_PROTOCOL=https
```

**Scenario 4: HTTP Only**
```bash
FOG_INTERNAL_HTTPS_ENABLED=false
FOG_HTTP_PROTOCOL=http
```

### Database Configuration
Database variables work together for connection:

- **`FOG_DB_HOST`** - Database server hostname/IP
- **`FOG_DB_PORT`** - Database server port
- **`FOG_DB_NAME`** - Database name
- **`FOG_DB_USER`** - Database username
- **`FOG_DB_PASS`** - Database password

### DHCP Integration
DHCP variables define PXE boot configuration:

- **`FOG_TFTP_HOST`** - Used for DHCP Option 66 (Next Server)
- **`FOG_DHCP_BOOTFILE_BIOS`** - Used for DHCP Option 67 (BIOS/Legacy clients, Arch:00000)
- **`FOG_DHCP_BOOTFILE_UEFI32`** - Used for DHCP Option 67 (UEFI 32-bit clients, Arch:00002, 00006)
- **`FOG_DHCP_BOOTFILE_UEFI64`** - Used for DHCP Option 67 (UEFI 64-bit clients, Arch:00007, 00008, 00009, plus SURFACE-PRO-4, Apple-Intel-Netboot)
- **`FOG_DHCP_BOOTFILE_ARM64`** - Used for DHCP Option 67 (UEFI ARM64 clients, Arch:00011)
- **`FOG_DHCP_BOOTFILE_UEFI`** - Legacy variable (maps to UEFI64 for backward compatibility)

### FTP Configuration
FTP passive mode requires port range configuration:

- **`FOG_FTP_PASV_MIN_PORT`** - Minimum passive port
- **`FOG_FTP_PASV_MAX_PORT`** - Maximum passive port
- **`FOG_WEB_HOST`** - Used for passive mode address resolution

## Configuration Examples

### Single Server Setup

```bash
# Core configuration
FOG_WEB_HOST=192.168.1.100
FOG_DB_ROOT_PASSWORD=your-secure-password

# Network configuration (all same server)
FOG_STORAGE_HOST=192.168.1.100
FOG_TFTP_HOST=192.168.1.100
FOG_WOL_HOST=192.168.1.100

# Protocol
FOG_HTTP_PROTOCOL=http
FOG_INTERNAL_HTTPS_ENABLED=false

# DHCP (use existing)
FOG_DHCP_ENABLED=false
```

### FQDN with Reverse Proxy

```bash
# Core configuration
FOG_WEB_HOST=fog.example.com
FOG_DB_ROOT_PASSWORD=your-secure-password

# Network configuration (all same server)
FOG_STORAGE_HOST=fog.example.com
FOG_TFTP_HOST=fog.example.com
FOG_WOL_HOST=fog.example.com

# Protocol (HTTPS via reverse proxy)
FOG_HTTP_PROTOCOL=https
FOG_INTERNAL_HTTPS_ENABLED=false

# DHCP (use existing)
FOG_DHCP_ENABLED=false
```

### Distributed Setup

```bash
# Core configuration
FOG_WEB_HOST=192.168.1.100
FOG_DB_ROOT_PASSWORD=your-secure-password

# Network configuration (different servers)
FOG_STORAGE_HOST=192.168.1.101
FOG_TFTP_HOST=192.168.1.102
FOG_WOL_HOST=192.168.1.100

# Protocol
FOG_HTTP_PROTOCOL=http
FOG_INTERNAL_HTTPS_ENABLED=false

# DHCP (use existing)
FOG_DHCP_ENABLED=false
```

### FOG as DHCP Server

```bash
# Core configuration
FOG_WEB_HOST=192.168.1.100
FOG_DB_ROOT_PASSWORD=your-secure-password

# Network configuration
FOG_STORAGE_HOST=192.168.1.100
FOG_TFTP_HOST=192.168.1.100
FOG_WOL_HOST=192.168.1.100

# Protocol
FOG_HTTP_PROTOCOL=http
FOG_INTERNAL_HTTPS_ENABLED=false

# DHCP configuration
FOG_DHCP_ENABLED=true
FOG_DHCP_SUBNET=192.168.1.0
FOG_DHCP_NETMASK=255.255.255.0
FOG_DHCP_ROUTER=192.168.1.1
FOG_DHCP_DOMAIN_NAME=fog.local
FOG_DHCP_START_RANGE=192.168.1.100
FOG_DHCP_END_RANGE=192.168.1.200
FOG_DHCP_DNS=8.8.8.8
FOG_DHCP_BOOTFILE_BIOS=undionly.kkpxe
FOG_DHCP_BOOTFILE_UEFI32=i386-efi/snponly.efi
FOG_DHCP_BOOTFILE_UEFI64=snponly.efi
FOG_DHCP_BOOTFILE_ARM64=arm64-efi/snponly.efi
FOG_DHCP_BOOTFILE_UEFI=snponly.efi
```

### HTTPS with External Certificates

```bash
# Core configuration
FOG_WEB_HOST=fog.example.com
FOG_DB_ROOT_PASSWORD=your-secure-password

# Network configuration
FOG_STORAGE_HOST=fog.example.com
FOG_TFTP_HOST=fog.example.com
FOG_WOL_HOST=fog.example.com

# Protocol
FOG_HTTP_PROTOCOL=https
FOG_INTERNAL_HTTPS_ENABLED=true

# SSL configuration
FOG_APACHE_SSL_CERT_FILE=fullchain.pem
FOG_APACHE_SSL_KEY_FILE=privkey.pem

# DHCP (use existing)
FOG_DHCP_ENABLED=false
```

### HTTPS with Self-signed Certificates

```bash
# Core configuration
FOG_WEB_HOST=192.168.1.100
FOG_DB_ROOT_PASSWORD=your-secure-password

# Network configuration
FOG_STORAGE_HOST=192.168.1.100
FOG_TFTP_HOST=192.168.1.100
FOG_WOL_HOST=192.168.1.100

# Protocol
FOG_HTTP_PROTOCOL=https
FOG_INTERNAL_HTTPS_ENABLED=true

# SSL configuration
FOG_APACHE_SSL_CN=192.168.1.100
FOG_APACHE_SSL_SAN=alt1.domain.com,alt2.domain.com

# DHCP (use existing)
FOG_DHCP_ENABLED=false
```

## Environment Variable Validation

### Required Variables Check

```bash
# Check required variables are set
if [ -z "$FOG_WEB_HOST" ]; then
    echo "ERROR: FOG_WEB_HOST is required"
    exit 1
fi

if [ -z "$FOG_DB_ROOT_PASSWORD" ]; then
    echo "ERROR: FOG_DB_ROOT_PASSWORD is required"
    exit 1
fi
```

### Network Configuration Check

```bash
# Check network configuration
echo "Web Host: $FOG_WEB_HOST"
echo "Storage Host: ${FOG_STORAGE_HOST:-$FOG_WEB_HOST}"
echo "TFTP Host: ${FOG_TFTP_HOST:-$FOG_WEB_HOST}"
echo "WOL Host: ${FOG_WOL_HOST:-$FOG_WEB_HOST}"
echo "Protocol: ${FOG_HTTP_PROTOCOL:-http}"
```

## Best Practices

1. **Use strong passwords** for database and FOG user accounts
2. **Set appropriate timezone** for your location
3. **Configure FTP passive ports** for firewall compatibility
4. **Use HTTPS** in production environments
5. **Regular backup** of environment configuration
6. **Document custom configurations** for team members

## Next Steps

After configuring environment variables:

1. **[Installation Guide](installation.md)** - Deploy FOG Docker
2. **[Configuration Guide](configuration.md)** - Additional configuration
3. **[Troubleshooting Guide](troubleshooting.md)** - Common issues and solutions

---
layout: default
title: Configuration Guide
nav_order: 3
description: "Configure FOG Docker for your environment"
permalink: /configuration
---

# Configuration Guide

This guide covers configuring FOG Docker for your environment.

## Required Settings

Edit your `.env` file and set these **required** variables:

```bash
# Your server's IP address or FQDN that clients will use to access FOG
FOG_WEB_HOST=192.168.1.100

# Secure password for the MySQL root user
FOG_DB_ROOT_PASSWORD=your-secure-password
```

## Network Configuration

Configure how clients will connect to your FOG server:

```bash
# Storage node - where clients access image storage
FOG_STORAGE_HOST=192.168.1.100

# TFTP server - where PXE clients download boot files
FOG_TFTP_HOST=192.168.1.100

# Wake-on-LAN server - sends WOL packets
FOG_WOL_HOST=192.168.1.100
```

**For single-server setups:** Set all host variables to the same IP/FQDN as `FOG_WEB_HOST`.

## FOG User Configuration

The FOG user account is used for various FOG operations:

```bash
# FOG User Configuration
FOG_USER=fogproject
FOG_PASS=fogftp123
```

**What the FOG user is used for:**
- **FTP access** to image storage directories
- **Service operations** for FOG background services
- **File permissions** for images, snapins, and logs
- **General FOG functionality** throughout the system

**Important:** This is **SEPARATE** from the FOG web UI admin user!

**FOG Web UI Admin User:**
- **Username:** `fog`
- **Password:** `password` (default)
- **Created:** During database initialization
- **Action Required:** **MUST be changed immediately** after first login for security!

## FTP Configuration

### Passive Mode Configuration

FOG Docker supports configurable FTP passive mode for better compatibility with firewalls and NAT environments:

```bash
# FTP Passive Mode Configuration
FOG_FTP_PASV_MIN_PORT=21100
FOG_FTP_PASV_MAX_PORT=21110
```

**Benefits:**
- **Firewall Friendly**: Passive mode works better through firewalls
- **NAT Compatible**: Works properly with NAT environments
- **Configurable Range**: Customize port range for your network
- **Automatic Configuration**: Passive mode is automatically configured based on your `FOG_WEB_HOST` setting

**Important**: Make sure to open the passive port range (21100-21110 by default) in your firewall for FTP image transfers to work properly.

## DHCP Configuration (Optional)

If you want FOG to handle DHCP services (`FOG_DHCP_ENABLED=true`), configure these network-specific variables:

```bash
# Network Configuration
FOG_DHCP_SUBNET=192.168.1.0
FOG_DHCP_NETMASK=255.255.255.0
FOG_DHCP_ROUTER=192.168.1.1
FOG_DHCP_DOMAIN_NAME=fog.local

# IP Address Range
FOG_DHCP_START_RANGE=192.168.1.100
FOG_DHCP_END_RANGE=192.168.1.200

# DNS and Boot Files
FOG_DHCP_DNS=8.8.8.8
FOG_DHCP_BOOTFILE_BIOS=undionly.kpxe   # Legacy BIOS clients (TFTP only)
FOG_DHCP_BOOTFILE_UEFI=ipxe.efi       # UEFI clients (x86_64, ARM64, etc.)

# Lease Times (in seconds)
FOG_DHCP_DEFAULT_LEASE_TIME=600        # 10 minutes
FOG_DHCP_MAX_LEASE_TIME=7200           # 2 hours
```

**Note:** Most setups use an existing DHCP server. Only enable FOG's DHCP if you need it to handle DHCP services.

## Setup Scenarios

### Scenario 1: Single Server (Most Common)

For a single FOG server handling everything:

```bash
FOG_WEB_HOST=192.168.1.100
FOG_STORAGE_HOST=192.168.1.100
FOG_TFTP_HOST=192.168.1.100
FOG_WOL_HOST=192.168.1.100
FOG_DHCP_ENABLED=false  # Use existing DHCP server
FOG_INTERNAL_HTTPS_ENABLED=false
FOG_HTTP_PROTOCOL=http
```

**DHCP Configuration:** Configure your existing DHCP server with:
- Option 66 (next-server): `192.168.1.100`
- Option 67 (filename): Architecture-specific boot files (see [Network Boot Guide](network-boot.md))

### Scenario 2: FQDN with Reverse Proxy

For a server behind a reverse proxy with a domain name:

```bash
FOG_WEB_HOST=fog.example.com
FOG_STORAGE_HOST=fog.example.com
FOG_TFTP_HOST=fog.example.com
FOG_WOL_HOST=fog.example.com
FOG_DHCP_ENABLED=false  # Use existing DHCP server
FOG_INTERNAL_HTTPS_ENABLED=false
FOG_HTTP_PROTOCOL=https
```

**DHCP Configuration:** Configure your existing DHCP server with:
- Option 66 (next-server): `fog.example.com`
- Option 67 (filename): Architecture-specific boot files (see [Network Boot Guide](network-boot.md))

### Scenario 3: Distributed Setup

For separate servers handling different functions:

```bash
FOG_WEB_HOST=192.168.1.100      # Web interface server
FOG_STORAGE_HOST=192.168.1.101  # Storage server
FOG_TFTP_HOST=192.168.1.102     # TFTP server
FOG_WOL_HOST=192.168.1.100      # WOL server
FOG_DHCP_ENABLED=false
```

**DHCP Configuration:** Configure your existing DHCP server with:
- Option 66 (next-server): `192.168.1.102`
- Option 67 (filename): Architecture-specific boot files (see [Network Boot Guide](network-boot.md))

### Scenario 4: FOG as DHCP Server

For FOG to handle DHCP as well (less common):

```bash
FOG_WEB_HOST=192.168.1.100
FOG_STORAGE_HOST=192.168.1.100
FOG_TFTP_HOST=192.168.1.100
FOG_WOL_HOST=192.168.1.100

# Enable FOG's DHCP server
FOG_DHCP_ENABLED=true

# Network configuration
FOG_DHCP_SUBNET=192.168.1.0
FOG_DHCP_NETMASK=255.255.255.0
FOG_DHCP_ROUTER=192.168.1.1
FOG_DHCP_DOMAIN_NAME=fog.local

# IP address range
FOG_DHCP_START_RANGE=192.168.1.100
FOG_DHCP_END_RANGE=192.168.1.200

# DNS and boot files
FOG_DHCP_DNS=8.8.8.8
FOG_DHCP_BOOTFILE_BIOS=undionly.kpxe
FOG_DHCP_BOOTFILE_UEFI=ipxe.efi
```

**Note:** This scenario is less common and requires careful network configuration to avoid conflicts with existing DHCP servers.

## Environment Variables Reference

### Core Configuration
- `FOG_WEB_HOST` - Server IP/FQDN for web access
- `FOG_STORAGE_HOST` - Server IP/FQDN for storage access
- `FOG_TFTP_HOST` - Server IP/FQDN for TFTP access
- `FOG_WOL_HOST` - Server IP/FQDN for Wake-on-LAN
- `FOG_HTTP_PROTOCOL` - Protocol (http/https)

### Database Configuration
- `FOG_DB_ROOT_PASSWORD` - MySQL root password
- `FOG_DB_HOST` - Database host (default: fog-db)
- `FOG_DB_PORT` - Database port (default: 3306)
- `FOG_DB_NAME` - Database name (default: fog)
- `FOG_DB_USER` - Database user (default: fogmaster)
- `FOG_DB_PASS` - Database password

### Web Configuration
- `FOG_WEB_ROOT` - Web root path for FOG
- `FOG_APACHE_PORT` - Internal Apache HTTP port
- `FOG_APACHE_SSL_PORT` - Internal Apache HTTPS port
- `FOG_APACHE_EXPOSED_PORT` - External HTTP port mapping
- `FOG_APACHE_EXPOSED_SSL_PORT` - External HTTPS port mapping

### FTP Configuration
- `FOG_FTP_PASV_MIN_PORT` - FTP passive mode minimum port
- `FOG_FTP_PASV_MAX_PORT` - FTP passive mode maximum port

### SSL Configuration
- `FOG_INTERNAL_HTTPS_ENABLED` - Enable internal HTTPS
- `FOG_APACHE_SSL_CERT_FILE` - Apache SSL certificate file
- `FOG_APACHE_SSL_KEY_FILE` - Apache SSL key file
- `FOG_APACHE_SSL_CN` - SSL certificate common name
- `FOG_APACHE_SSL_SAN` - SSL certificate subject alternative names

### Network Configuration
- `FOG_MULTICAST_INTERFACE` - Network interface for multicast operations

### Debug Configuration
- `DEBUG` - Enable debug mode for troubleshooting
- `FORCE_FIRST_START_INIT` - Force FOG first start initialization

## Next Steps

After configuration:

1. **[SSL/HTTPS Setup](ssl-https.md)** - Configure SSL certificates (optional)
2. **[Network Boot Setup](network-boot.md)** - Set up PXE and HTTPBoot
3. **[Troubleshooting Guide](troubleshooting.md)** - Common issues and solutions

# FOG Docker

**⚠️ BETA SOFTWARE - This project is in active development and may have bugs or incomplete features.**

A Docker containerization of the FOG Project - an open-source computer cloning and imaging solution. This project provides a complete FOG server running in Docker containers with automatic configuration and setup.

## Quick Start

### Production Setup (Recommended)

1. **Clone the repository:**
   ```bash
   git clone https://github.com/88fingerslukee/fog-docker.git
   cd fog-docker
   ```

2. **Configure your environment:**
   ```bash
   cp .env.example .env
   # Edit .env with your settings (see Configuration section below)
   ```

3. **Start FOG:**
   ```bash
   docker compose up -d
   ```

4. **Access FOG:**
   - Web Interface: `http://your-server-ip/fog`
   - Default login: `fog` / `password`

### Development Setup

For development, testing, or custom FOG versions:

1. **Configure your environment:**
   ```bash
   cp .env.example .env
   # Edit .env to set your variables, including FOG_GIT_REF for specific versions
   ```

2. **Build and start the containers:**
   ```bash
   docker compose -f docker-compose-dev.yml up -d --build
   ```

**Note:** Development setup builds from source and uses different ports (8080, 8443, 6969, 2121) to avoid conflicts with production.

## Automatic Releases

This project automatically builds and publishes new Docker images when the FOG Project releases new versions:

- **Automatic Detection**: Checks for new FOG releases every 6 hours
- **Versioned Tags**: Each FOG release gets its own Docker tag (e.g., `fog-1.5.10`)
- **Latest Tag**: The latest stable FOG version is always available as `latest`
- **Manual Trigger**: You can manually trigger builds for specific FOG versions

### Available Image Tags

- `ghcr.io/88fingerslukee/fog-docker:latest` - Latest stable FOG version
- `ghcr.io/88fingerslukee/fog-docker:fog-1.5.10` - Specific FOG version
- `ghcr.io/88fingerslukee/fog-docker:fog-dev-branch` - Development branch

## Configuration

### Required Settings

Edit your `.env` file and set these **required** variables:

```bash
# Your server's IP address or FQDN that clients will use to access FOG
FOG_WEB_HOST=192.168.1.100

# Secure password for the MySQL root user
FOG_DB_ROOT_PASSWORD=your-secure-password
```

### Network Configuration

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

### FOG User Configuration

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

**Security Notes:**
- Choose a strong password for `FOG_PASS` in production environments
- Change the web UI admin password immediately after setup

### DHCP Configuration (Optional)

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
FOG_DHCP_BOOTFILE_BIOS=undionly.kpxe   # Legacy BIOS clients
FOG_DHCP_BOOTFILE_UEFI32=ipxe32.efi   # UEFI 32-bit clients
FOG_DHCP_BOOTFILE_UEFI64=ipxe.efi     # UEFI 64-bit clients
FOG_DHCP_BOOTFILE_ARM32=arm32.efi     # ARM 32-bit clients
FOG_DHCP_BOOTFILE_ARM64=arm64.efi     # ARM 64-bit clients

# Optional: HTTPBoot support (for clients that support HTTPBoot)
# URL is automatically constructed from FOG_HTTP_PROTOCOL, FOG_WEB_HOST, and FOG_WEB_ROOT
FOG_DHCP_HTTPBOOT_ENABLED=false

# Lease Times (in seconds)
FOG_DHCP_DEFAULT_LEASE_TIME=600        # 10 minutes
FOG_DHCP_MAX_LEASE_TIME=7200           # 2 hours
```

**Note:** Most setups use an existing DHCP server. Only enable FOG's DHCP if you need it to handle DHCP services.

### HTTPBoot Support

FOG Docker supports HTTPBoot for clients that prefer HTTP over TFTP for network booting. HTTPBoot offers several advantages:

- **Faster booting** - HTTP is typically faster than TFTP
- **Better reliability** - HTTP has superior error handling and retry mechanisms
- **Modern client support** - Many newer UEFI clients prefer HTTPBoot
- **Automatic URL construction** - The HTTPBoot URL is built from your existing FOG configuration

When `FOG_DHCP_HTTPBOOT_ENABLED=true`, the DHCP server will provide:
```
{{FOG_HTTP_PROTOCOL}}://{{FOG_WEB_HOST}}{{FOG_WEB_ROOT}}/service/ipxe/boot.php
```

For example:
- HTTP: `http://192.168.1.100/fog/service/ipxe/boot.php`
- HTTPS: `https://fog.example.com/fog/service/ipxe/boot.php`

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
- Option 67 (filename): Architecture-specific boot files (see DHCP Configuration section)

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
- Option 67 (filename): Architecture-specific boot files (see DHCP Configuration section)

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
- Option 67 (filename): Architecture-specific boot files (see DHCP Configuration section)

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
FOG_DHCP_BOOTFILE_UEFI32=ipxe32.efi
FOG_DHCP_BOOTFILE_UEFI64=ipxe.efi
FOG_DHCP_BOOTFILE_ARM32=arm32.efi
FOG_DHCP_BOOTFILE_ARM64=arm64.efi
```

**Note:** This scenario is less common and requires careful network configuration to avoid conflicts with existing DHCP servers.

## SSL/HTTPS Configuration

### Option 1: External Certificates (Recommended)

```bash
FOG_INTERNAL_HTTPS_ENABLED=true
FOG_HTTP_PROTOCOL=https
FOG_SSL_GENERATE_SELF_SIGNED=false
FOG_SSL_CERT_FILE=fullchain.pem
FOG_SSL_KEY_FILE=privkey.pem
```

Mount your certificates:
```bash
# Add to docker-compose.yml volumes:
- /path/to/certs:/opt/fog/snapins/ssl:ro
```

### Option 2: Self-signed Certificates

```bash
FOG_INTERNAL_HTTPS_ENABLED=true
FOG_HTTP_PROTOCOL=https
FOG_SSL_GENERATE_SELF_SIGNED=true
FOG_SSL_CN=192.168.1.100
FOG_SSL_SAN=alt1.domain.com,alt2.domain.com
```

### Option 3: Reverse Proxy (No SSL in Container)

```bash
FOG_INTERNAL_HTTPS_ENABLED=false
FOG_HTTP_PROTOCOL=https
FOG_SSL_GENERATE_SELF_SIGNED=false
```

### Option 4: HTTP Only (Default)

```bash
FOG_INTERNAL_HTTPS_ENABLED=false
FOG_HTTP_PROTOCOL=http
FOG_SSL_GENERATE_SELF_SIGNED=false
```

## Ports

FOG Docker exposes the following ports:

- **80/443**: Web interface (HTTP/HTTPS)
- **69/UDP**: TFTP server
- **21**: FTP server
- **2049**: NFS server
- **111**: NFS RPC portmapper
- **32765**: NFS RPC statd
- **32767**: NFS RPC mountd

## Troubleshooting

### Storage Node Connectivity Issues

1. Verify `FOG_STORAGE_HOST` is reachable from client machines
2. Check that the FQDN resolves correctly from client machines
3. Verify firewall rules allow access to ports 80, 443, 69, 2049, 21

### PXE Boot Issues

1. Ensure `FOG_TFTP_HOST` is reachable from client machines
2. Check that port 69/UDP is open and accessible
3. Verify DHCP is configured to point to the correct TFTP server
4. Check that DHCP option 66 (next-server) points to `FOG_TFTP_HOST`
5. Verify DHCP option 67 (filename) is set to the correct boot file
6. For UEFI/ARM clients, ensure appropriate boot files are configured (`FOG_DHCP_BOOTFILE_UEFI32`, `FOG_DHCP_BOOTFILE_UEFI64`, etc.)
7. For HTTPBoot clients, verify `FOG_DHCP_HTTPBOOT_ENABLED=true` and check that the constructed URL is accessible

### Image Capture/Deploy Failures

1. Check that `FOG_STORAGE_HOST` is accessible from client machines
2. Verify NFS exports are working (port 2049)
3. Check FTP connectivity (port 21)

### DHCP Configuration Issues

1. Verify all DHCP network variables match your actual network configuration
2. Ensure `FOG_DHCP_SUBNET` and `FOG_DHCP_NETMASK` are correct for your network
3. Check that `FOG_DHCP_ROUTER` points to your actual gateway
4. Verify IP address range (`FOG_DHCP_START_RANGE` to `FOG_DHCP_END_RANGE`) doesn't conflict with existing devices
5. Ensure `FOG_DHCP_DNS` contains valid DNS servers
6. Check that all required boot files are present in `/tftpboot/` (BIOS, UEFI 32/64-bit, ARM 32/64-bit)

### Container Logs

```bash
# View FOG server logs
docker compose logs fog-server

# View database logs
docker compose logs fog-db

# Follow logs in real-time
docker compose logs -f fog-server
```

## Features

- ✅ **Complete FOG Server**: Full FOG functionality in Docker
- ✅ **Automatic Configuration**: Environment-based configuration
- ✅ **Database Integration**: MySQL database with automatic setup
- ✅ **NFS Support**: Image storage via NFS
- ✅ **FTP Support**: Image transfer via FTP
- ✅ **TFTP Support**: PXE boot file serving
- ✅ **UEFI Support**: Automatic BIOS/UEFI client detection and boot file selection
- ✅ **SSL/HTTPS Support**: Multiple SSL configuration options
- ✅ **Reverse Proxy Support**: Works behind reverse proxies

## Beta Features (Needs Testing)

The following features are implemented but need thorough testing:

- 🔄 **Multicasting**: Image deployment to multiple clients simultaneously
- 🔄 **Secure Boot**: UEFI Secure Boot support
- 🔄 **DHCP Server**: Built-in DHCP server functionality

## Contributing

This project is in active development. Contributions, bug reports, and feature requests are welcome!

## Support

If you find this project useful, consider supporting development:

[![PayPal](https://www.paypalobjects.com/en_US/i/btn/btn_donateCC_LG.gif)](https://paypal.me/88fingerslukee)

## License

This project is licensed under the GPL v3 License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- [FOG Project](https://github.com/FOGProject/fogproject) - The original FOG imaging solution
- Docker community for containerization best practices
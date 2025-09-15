# FOG Docker

A FOG Docker implementation for complete containerization.

## 🎯 Goals

This implementation achieves true statelessness by:
- **Pre-building everything** in the Docker image
- **Environment-driven configuration** for all runtime settings
- **Template-based configuration** generation
- **Persistent data separation** from application code
- **State management** to avoid re-initialization

## 🚀 Features

- **Two-stage build process** for optimal image size
- **Environment variable configuration** for all settings
- **Automatic configuration generation** from templates
- **Supervisor-based service management** for all FOG services
- **Secure Boot support** with automatic key generation
- **Persistent data management** via Docker volumes
- **Database schema initialization** without web interface dependency

## 📋 Prerequisites

- Docker Engine 20.10+
- Docker Compose 2.0+
- At least 4GB RAM
- At least 20GB free disk space
- Root or sudo access

## 🛠️ Quick Start

### 1. Clone and Configure

```bash
git clone <repository-url> fog-docker
cd fog-docker

# Copy environment template
cp .env.example .env

# Edit configuration
nano .env
```

### 2. Required Configuration

**Minimum required settings in `.env`:**

```bash
# REQUIRED - No defaults
FOG_WEB_HOST=192.168.1.100                    # Your server IP or FQDN
FOG_DB_ROOT_PASSWORD=your_secure_password     # Database root password
```

### 3. Deploy

```bash
# Build and start services
docker compose up -d

# View logs
docker compose logs -f

# Check status
docker compose ps
```

### 4. Access FOG

- **Web Interface**: `http://your-server-ip/fog/management/`
- **Default Login**: `fog` / `password`

## ⚙️ Configuration

### Environment Variables

All configuration is done via environment variables in the `.env` file:

#### Required Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `FOG_WEB_HOST` | Server IP or FQDN | `192.168.1.100` |
| `FOG_DB_ROOT_PASSWORD` | MySQL root password | `secure_password123` |

#### Optional Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `FOG_VERSION` | FOG version to install | `stable` |
| `FOG_WEB_ROOT` | Web root path | `/fog` |
| `FOG_HTTPS_ENABLED` | Enable HTTPS | `false` |
| `FOG_SECURE_BOOT_ENABLED` | Enable Secure Boot | `false` |
| `FOG_DHCP_ENABLED` | Enable DHCP server | `false` |

### Persistent Storage

The implementation uses Docker volumes for persistent data:

- `fog_mysql`: Database data
- `fog_data`: All FOG data (images, snapins, logs, SSL certificates)

### Secure Boot

When `FOG_SECURE_BOOT_ENABLED=true`:

1. **Automatic key generation** on first run
2. **iPXE compilation** with Secure Boot support
3. **Shim and MOK manager** integration
4. **FAT32 image creation** for MOK certificate enrollment

## 🔧 Architecture

### Two-Stage Build Process

**Stage 1 (fog-builder):**
- Installs build dependencies
- Clones FOG source code
- Compiles iPXE with Secure Boot support
- Creates installation tarball

**Stage 2 (Production):**
- Installs all FOG dependencies
- Extracts pre-built FOG installation
- Sets up directory structure
- Removes configuration files (generated at runtime)

### Runtime Configuration

**Configuration Generation:**
- Templates processed with environment variables
- Dynamic file creation from templates
- Type-aware configuration (string, bool, array)

**Service Management:**
- Supervisor manages all FOG services
- Automatic service restarts on failure
- Centralized logging for all services
- Process monitoring and health checks

**State Management:**
- Tracks initialization state
- Avoids re-running setup steps
- Database schema initialization

## 📁 Directory Structure

```
fog-docker/
├── Dockerfile                 # Two-stage build
├── docker-compose.yml         # Service orchestration
├── entrypoint.sh             # Runtime configuration
├── .env.example              # Environment template
├── README.md                 # This file
├── config/
│   └── server/               # Server configuration
├── templates/                # Configuration templates
│   ├── config.class.php.template
│   ├── apache-fog.conf.template
│   ├── tftpd-hpa.conf.template
│   ├── exports.template
│   └── dhcpd.conf.template
└── scripts/                  # Utility scripts
    ├── generate-keys.sh
    └── setup-secure-boot.sh
```

## 🔍 Troubleshooting

### Common Issues

1. **Database Connection Failed**
   - Check `FOG_DB_ROOT_PASSWORD` is set
   - Verify database container is running
   - Check network connectivity

2. **Configuration Generation Failed**
   - Verify all required environment variables are set
   - Check template files exist
   - Review container logs

3. **Secure Boot Issues**
   - Ensure `FOG_SECURE_BOOT_ENABLED=true`
   - Check key generation completed
   - Verify shim binaries are present

### Debug Mode

Enable debug mode for detailed logging:

```bash
DEBUG=true docker compose up
```

### Logs

View container logs:

```bash
# All services
docker compose logs -f

# Specific service
docker compose logs -f fog
docker compose logs -f database
```

## 🚀 Advanced Usage

### Custom FOG Version

```bash
# Use development branch
FOG_VERSION=dev-branch

# Use specific version
FOG_VERSION=1.5.10.1673

# Use custom repository
FOG_GIT_URL=https://github.com/your-fork/fogproject.git
```

### HTTPS Configuration

FOG Docker supports three HTTPS scenarios:

#### **Scenario 1: HTTP (Default)**
```bash
FOG_HTTPS_ENABLED=false
# No SSL configuration needed
```

#### **Scenario 2: External Certificates (Let's Encrypt, Commercial)**
```bash
FOG_HTTPS_ENABLED=true
FOG_SSL_GENERATE_SELF_SIGNED=false
FOG_SSL_CERT_FILE=fullchain.pem
FOG_SSL_KEY_FILE=privkey.pem
# Mount certificates as volume: /path/to/certs:/opt/fog/snapins/ssl:ro
```

#### **Scenario 3: Self-Signed Certificates**
```bash
FOG_HTTPS_ENABLED=true
FOG_SSL_GENERATE_SELF_SIGNED=true
FOG_SSL_CN=your-domain.com
FOG_SSL_SAN=alt1.your-domain.com,alt2.your-domain.com
# iPXE will be automatically recompiled with certificate trust
```

#### **Scenario 4: Reverse Proxy**
```bash
FOG_HTTPS_ENABLED=false
# SSL termination handled by reverse proxy (Nginx, Apache, etc.)
```

### DHCP Server

FOG Docker includes a comprehensive DHCP server configuration that supports all the same features as bare metal FOG installation.

#### Basic Configuration

```bash
FOG_DHCP_ENABLED=true
FOG_DHCP_START_RANGE=192.168.1.100
FOG_DHCP_END_RANGE=192.168.1.200
FOG_DHCP_DNS=8.8.8.8
FOG_DHCP_BOOTFILE=undionly.kpxe
```

#### DHCP Features Comparison

| Feature | Bare Metal FOG | FOG Docker | Status |
|---------|----------------|------------|---------|
| **Basic DHCP** | ✅ | ✅ | **Full Support** |
| **PXE Boot Configuration** | ✅ | ✅ | **Full Support** |
| **Multiple Architecture Support** | ✅ | ✅ | **Full Support** |
| **UEFI Boot Support** | ✅ | ✅ | **Full Support** |
| **Legacy BIOS Support** | ✅ | ✅ | **Full Support** |
| **Apple Intel Netboot** | ✅ | ✅ | **Full Support** |
| **Surface Pro 4 Support** | ✅ | ✅ | **Full Support** |
| **ARM64 UEFI Support** | ✅ | ✅ | **Full Support** |
| **Custom Lease Times** | ✅ | ✅ | **Full Support** |
| **Domain Name Configuration** | ✅ | ✅ | **Full Support** |
| **Router/Gateway Configuration** | ✅ | ✅ | **Full Support** |
| **DNS Server Configuration** | ✅ | ✅ | **Full Support** |
| **Subnet Mask Configuration** | ✅ | ✅ | **Full Support** |
| **PXE Vendor Options** | ✅ | ✅ | **Full Support** |
| **MTFTP Configuration** | ✅ | ✅ | **Full Support** |
| **Dynamic DNS Updates** | ✅ | ✅ | **Full Support** |

#### Supported Architectures

The DHCP server automatically detects and serves the appropriate boot file for:

- **Legacy BIOS** (`undionly.kpxe`)
- **UEFI 32-bit** (`i386-efi/snponly.efi`)
- **UEFI 64-bit** (`snponly.efi`)
- **ARM64 UEFI** (`arm64-efi/snponly.efi`)
- **Apple Intel** (Special Apple NetBoot configuration)
- **Surface Pro 4** (Special UEFI configuration)

#### Advanced Configuration

For advanced DHCP configuration, you can modify the template at `templates/dhcpd.conf.template` or extend the environment variables in the entrypoint script.

#### DHCP vs External DHCP

**Using FOG DHCP Server:**
- ✅ Automatic PXE configuration
- ✅ All architecture support included
- ✅ No external DHCP configuration needed
- ✅ Integrated with FOG services

**Using External DHCP Server:**
- Set `FOG_DHCP_ENABLED=false`
- Configure your existing DHCP server with the following options:

#### Required DHCP Options

| DHCP Server Type | Option Name | Value | Description |
|------------------|-------------|-------|-------------|
| **Linux DHCP** | `next-server` | FOG server IP | TFTP server IP address |
| **Linux DHCP** | `filename` | Boot file name | PXE boot file to download |
| **Windows DHCP** | **Option 66** | FOG server IP | TFTP server IP address |
| **Windows DHCP** | **Option 67** | Boot file name | PXE boot file to download |

#### Boot Files by Architecture

| Architecture | Boot File | Description |
|--------------|-----------|-------------|
| **Legacy BIOS** | `undionly.kpxe` | Standard BIOS PXE boot |
| **UEFI 64-bit** | `snponly.efi` | Standard UEFI boot |
| **UEFI 32-bit** | `i386-efi/snponly.efi` | 32-bit UEFI boot |
| **ARM64 UEFI** | `arm64-efi/snponly.efi` | ARM64 UEFI boot |

#### External DHCP Server Examples

**pfSense Configuration:**
1. Navigate to **Services → DHCP Server**
2. Edit your DHCP scope
3. Add the following options:
   - **Option 66**: Your FOG server IP (e.g., `192.168.1.100`)
   - **Option 67**: Boot file (e.g., `undionly.kpxe` for BIOS or `snponly.efi` for UEFI)

**Microsoft DHCP Server Configuration:**
1. Open **DHCP Manager**
2. Right-click your scope → **Configure Options**
3. Add the following options:
   - **Option 66**: Your FOG server IP (e.g., `192.168.1.100`)
   - **Option 67**: Boot file (e.g., `undionly.kpxe` for BIOS or `snponly.efi` for UEFI)

**PowerShell Script for Microsoft DHCP:**
```powershell
# Set DHCP options for FOG PXE boot
Set-DhcpServerv4OptionValue -ScopeId 192.168.1.0 -OptionId 66 -Value "192.168.1.100"
Set-DhcpServerv4OptionValue -ScopeId 192.168.1.0 -OptionId 67 -Value "undionly.kpxe"
```

**Linux ISC DHCP Server:**
```bash
# Add to your dhcpd.conf
subnet 192.168.1.0 netmask 255.255.255.0 {
    range 192.168.1.100 192.168.1.200;
    option routers 192.168.1.1;
    option domain-name-servers 8.8.8.8;
    next-server 192.168.1.100;  # FOG server IP
    filename "undionly.kpxe";   # Boot file
}
```

**Cisco DHCP Server:**
```cisco
ip dhcp pool FOG_POOL
   network 192.168.1.0 255.255.255.0
   default-router 192.168.1.1
   dns-server 8.8.8.8
   option 66 ip 192.168.1.100
   option 67 ascii "undionly.kpxe"
```

#### Network Requirements

When using FOG DHCP server:
- Container must run with `network_mode: host`
- DHCP server binds to the specified network interface
- Requires root privileges for DHCP port binding
- Automatically configures `/etc/default/isc-dhcp-server`

## 📚 References

- [FOG Project](https://fogproject.org/)
- [Docker Compose Documentation](https://docs.docker.com/compose/)

## 🤝 Contributing

This implementation follows the Zulip Docker pattern for statelessness. Contributions are welcome to improve the implementation and add features.

## 📄 License

This project is licensed under the same terms as the FOG Project.


# FOG Docker Stack

## ⚠️ CAUTION - This Setup is Very Alpha!! ⚠️

A complete Docker Compose stack for running the FOG Project (Free and Open Ghost) disk imaging and cloning solution. This setup provides a FOG server with all necessary services containerized and configured for easy deployment.

## 🚀 Features

- **Complete FOG Stack**: Web interface, TFTP, NFS, FTP, and database services
- **Reverse Proxy Ready**: Compatible with any reverse proxy (Traefik, Nginx, Caddy, etc.)
- **Dynamic Configuration**: Environment-based configuration with templates
- **Secure Boot**: Auto-setup and configuration of secure boot-enabled ipxe files
- **Community Resource**: Includes roadmap for FOG Project containerization improvements

## ⚠️ Current Limitations & Trade-offs

This Docker stack works around FOG's architectural limitations without modifying the FOG source code. While functional, it requires several compromises to work in a containerized environment.

**For detailed information about these limitations and proposed solutions, see the [FOG Project Improvements](FOG-IMPROVEMENTS.md) document.**

## 📋 Prerequisites

- Docker Engine 20.10+
- Docker Compose 2.0+
- At least 4GB RAM
- At least 20GB free disk space
- Root or sudo access

## 🛠️ Quick Start

### 1. Clone the Repository

```bash
git clone https://github.com/88fingerslukee/fog-docker.git
cd fog-docker
```

### 2. Configure Environment

```bash
# Copy environment template
cp .env.example .env
# Edit .env with your configuration
nano .env
# Copy Docker Compose template
cp docker-compose-example.yml docker-compose.yml
```

**Note**: The `docker-compose-example.yml` file is a template that will be overwritten during updates. Always copy it to `docker-compose.yml` for your local configuration.

**Required Configuration:**

- `FOG_WEB_HOST`: Your host IP address or FQDN (e.g., `fog.example.com`) - **No default, must be set. FQDN is required for reverse proxy setups**
- `FOG_DB_ROOT_PASSWORD`: Database root password - **No default, must be set for security**

**Example Password Generation Command:**

```bash
# Generate a secure database root password
openssl rand -base64 32
```

**Optional Configuration (with defaults):**

- `FOG_VERSION`: FOG version (e.g., `1.5.10.1673`) - **Default: `stable`**
- `FOG_WEB_ROOT`: Web root path - **Default: `/fog`**
- `FOG_DB_PORT`: Database port - **Default: `3306`**
- `FOG_APACHE_PORT`: Apache HTTP port - **Default: `80` - Change for reverse proxy setups**
- `FOG_APACHE_SSL_PORT`: Apache HTTPS port - **Default: `443` - Change for reverse proxy setups**

### 3. Deploy the Stack

```bash
# Start all services
docker compose up -d

# View logs
docker compose logs -f

# Check service status
docker compose ps
```

### 4. Access FOG

- **Web Interface**: `https://your-fqdn/fog/management/`
- **Default Login**: `fog` / `password`

## ⚙️ Configuration

### Environment Variables

The stack is configured through environment variables in the `.env` file. Copy `.env.example` to `.env` and modify the values for your environment.

#### Required Variables

| Variable | Description | Example | Default |
|----------|-------------|---------|---------|
| `FOG_WEB_HOST` | FOG server hostname/IP (must be FQDN if behind reverse proxy) | `192.168.1.100` or `fog.example.com` | **None** |
| `FOG_DB_ROOT_PASSWORD` | MySQL root password | `secure_password123` | **None** |

#### Optional Variables

| Variable | Description | Example | Default |
|----------|-------------|---------|---------|
| `FOG_VERSION` | FOG version to install | `1.5.10.1673` | `stable` |
| `FOG_WEB_ROOT` | Web root path | `/fog` | `/fog` |
| `FOG_DB_PORT` | Database port | `3306` | `3306` |
| `FOG_APACHE_PORT` | Apache HTTP port | `80` | `80` |
| `FOG_APACHE_SSL_PORT` | Apache HTTPS port | `443` | `443` |
| `FOG_DB_NAME` | Database name | `fog` | `fog` |
| `FOG_DB_USER` | Database user | `fogmaster` | `fogmaster` |
| `FOG_DB_PASS` | Database password | `fogpass123` | `fogmaster123` |
| `FOG_FTP_USER` | FTP username | `fogproject` | `fogproject` |
| `FOG_FTP_PASS` | FTP password | `ftppass123` | `fogftp123` |
| `FOG_ADMIN_USER` | FOG admin username | `admin` | `fog` |
| `FOG_ADMIN_PASS` | FOG admin password | `adminpass123` | `password` |
| `TZ` | System timezone | `America/New_York` | `UTC` |
| `FOG_HTTPS_ENABLED` | Enable HTTPS | `true` | `false` |
| `FOG_SSL_GENERATE_SELF_SIGNED` | Generate self-signed cert | `true` | `true` |
| `FOG_SSL_CN` | Certificate Common Name | `fog.example.com` | `${FOG_WEB_HOST}` |
| `FOG_SSL_SAN` | Subject Alternative Names | `DNS:www.fog.com,IP:192.168.1.100` | **None** |

### FOG_WEB_HOST Configuration

The `FOG_WEB_HOST` variable can be either an IP address or FQDN, but **must be an FQDN if behind a reverse proxy**:

```bash
# Direct access - can use IP or FQDN
FOG_WEB_HOST=192.168.1.100

# Behind reverse proxy - must use FQDN
FOG_WEB_HOST=fog.example.com
```

### Important

This variable is used for:

- Web interface access
- TFTP service configuration
- NFS/Storage service configuration
- iPXE boot file generation
- All internal FOG service communication

When behind a reverse proxy, using an IP address will cause issues with iPXE booting and service communication, as the boot files will reference the internal IP instead of the public FQDN.

### Version Management

- **Latest Release**: Leave `FOG_VERSION` empty to use the latest stable release
- **Specific Version**: Set `FOG_VERSION` to a specific version (e.g., `1.5.10.1673`)
- **Rebuild Required**: Changing the version requires rebuilding the fog-server container

### Port Configuration

If you have conflicts with standard ports, you can change them:

```bash
# Example: Use custom ports to avoid conflicts
FOG_DB_PORT=3307
FOG_APACHE_PORT=8080
FOG_APACHE_SSL_PORT=8443
```

### Note

After changing ports, you may need to update your reverse proxy configuration and rebuild containers.

### SSL/HTTPS Configuration

The stack supports both HTTP and HTTPS configurations:

#### Standalone HTTPS (Self-Signed Certificate)

```bash
FOG_HTTPS_ENABLED=true
FOG_SSL_GENERATE_SELF_SIGNED=true
FOG_SSL_CN=fog.yourdomain.com
```

#### Self-Signed Certificate with SAN (Subject Alternative Names)

```bash
FOG_HTTPS_ENABLED=true
FOG_SSL_GENERATE_SELF_SIGNED=true
FOG_SSL_CN=fog.yourdomain.com
FOG_SSL_SAN=DNS:www.fog.yourdomain.com,DNS:fog.local,IP:192.168.1.100
```

**SAN Format**: Comma-separated list of alternative names:

- `DNS:domain.com` - Domain names
- `IP:192.168.1.100` - IP addresses
- `DNS:*.example.com` - Wildcard domains

#### Standalone HTTPS (Custom Certificate)

```bash
FOG_HTTPS_ENABLED=true
FOG_SSL_GENERATE_SELF_SIGNED=false
# Place your certificate files in the SSL path:
# - /opt/fog/snapins/ssl/server.crt
# - /opt/fog/snapins/ssl/server.key
```

#### Behind Reverse Proxy (HTTP)

```bash
FOG_HTTPS_ENABLED=false
# Let reverse proxy handle SSL termination
# iPXE files will automatically use HTTPS URLs (assumes reverse proxy)
```

#### Behind Reverse Proxy (Custom Protocol)

```bash
FOG_HTTPS_ENABLED=false
FOG_IPXE_PROTOCOL=http
# Force iPXE files to use HTTP URLs
```

**Note**:

- When `FOG_HTTPS_ENABLED=false`, iPXE files default to HTTPS URLs (assumes reverse proxy)
- Use `FOG_IPXE_PROTOCOL` to override this behavior
- When `FOG_HTTPS_ENABLED=true`, iPXE files use the container's SSL configuration

## 💾 Persistent Storage

By default, this stack uses Docker's built-in volume management, which provides automatic data persistence. However, you can configure custom persistent storage paths for better control and backup management.

### Default Behavior (Recommended for Most Users)

When volume paths are not specified in `.env`, Docker automatically creates and manages volumes:

- **Database**: `fog_mysql` volume for MariaDB data
- **Images**: `fog_images` volume for disk images
- **TFTP**: `fog_tftpboot` volume for PXE boot files
- **Logs**: `fog_logs` volume for FOG logs
- **SSL**: `fog_ssl` volume for certificates

### Custom Persistent Storage

To use custom storage paths, uncomment and configure the volume variables in `.env`:

#### Option 1: Host Directory Mounts

```bash
# Mount host directories for direct access
FOG_IMAGES_PATH=/opt/fog/images:/images
FOG_MYSQL_PATH=/opt/fog/mysql:/var/lib/mysql
FOG_TFTP_PATH=/opt/fog/tftpboot:/tftpboot
FOG_LOGS_PATH=/opt/fog/logs:/opt/fog/log
FOG_SSL_PATH=/opt/fog/ssl:/opt/fog/snapins/ssl
```

#### Option 2: Named Docker Volumes

```bash
# Use named Docker volumes for better portability
FOG_IMAGES_PATH=fog_images:/images
FOG_MYSQL_PATH=fog_mysql:/var/lib/mysql
FOG_TFTP_PATH=fog_tftpboot:/tftpboot
FOG_LOGS_PATH=fog_logs:/opt/fog/log
FOG_SSL_PATH=fog_ssl:/opt/fog/snapins/ssl
```

### Storage Considerations

**Important Data to Persist:**
- **Database** (`FOG_MYSQL_PATH`): Critical - contains all FOG configuration and image metadata
- **Images** (`FOG_IMAGES_PATH`): Critical - contains actual disk images
- **TFTP Boot Files** (`FOG_TFTP_PATH`): Important - PXE boot files and iPXE scripts
- **SSL Certificates** (`FOG_SSL_PATH`): Important - custom SSL certificates
- **Logs** (`FOG_LOGS_PATH`): Optional - for troubleshooting and monitoring

**Backup Recommendations:**
- Regular database backups (MariaDB dump)
- Image storage backups (large files, consider compression)
- Configuration backups (environment files, SSL certificates)

### Volume Management Commands

```bash
# List all FOG-related volumes
docker volume ls | grep fog

# Inspect a specific volume
docker volume inspect fog_mysql

# Backup a volume (example)
docker run --rm -v fog_mysql:/data -v $(pwd):/backup alpine tar czf /backup/mysql-backup.tar.gz -C /data .

# Restore a volume (example)
docker run --rm -v fog_mysql:/data -v $(pwd):/backup alpine tar xzf /backup/mysql-backup.tar.gz -C /data
```

## 🔐 Secure Boot Support

This FOG Docker stack includes experimental support for UEFI Secure Boot using shim and MOK (Machine Owner Key) management. This allows FOG to work with systems that have Secure Boot enabled.

### How Secure Boot Works

Secure Boot uses Microsoft-signed shim binaries to boot custom iPXE binaries that are signed with your own keys. The process involves:

1. **Shim Boot**: UEFI boots Microsoft-signed shim
2. **Key Enrollment**: MOK Manager allows enrollment of custom keys
3. **iPXE Boot**: Signed iPXE binary boots and loads FOG
4. **Nested Shim**: iPXE loads shim again for additional binary validation

### Prerequisites


**Note**: iPXE is automatically compiled with `SHIM_CMD` support, and shim/MOK Manager binaries are automatically included from Debian packages during container build. The container creates a FAT32 image file containing the MOK certificate that is accessible over the network.

Before enabling Secure Boot, you need:

### Setup Process

#### 1. Enable Secure Boot

Add to your `.env` file:

```bash
FOG_SECURE_BOOT_ENABLED=true
```

#### 2. Build and Deploy

```bash
# Build the container with Secure Boot dependencies
docker compose build

# Deploy the stack
docker compose up -d

# The container will automatically:
# - Use pre-compiled iPXE with SHIM_CMD support
# - Generate Secure Boot keys and certificates
# - Sign iPXE binaries with custom keys
# - Set up shim and MOK manager from Debian packages
# - Create BOOTX64.efi for DHCP configuration
# - Create FAT32 image with MOK certificate
```

**Note**: Building the container is required to include Secure Boot dependencies (FAT32 tools, iPXE compilation, shim packages). The container will automatically run the complete Secure Boot setup when `FOG_SECURE_BOOT_ENABLED=true`.

#### 3. Configure DHCP

Point your DHCP server to the shim binary (which will be created as `BOOTX64.efi` in the TFTP directory):

```
filename "BOOTX64.efi";
```

**Note**: The container automatically creates `BOOTX64.efi` from the Debian shim binary during Secure Boot setup.

#### 4. Enroll Keys

1. Boot a machine with Secure Boot enabled
2. Use MOK Manager to enroll the key from the network-accessible FAT32 image
3. Reboot - the machine should now boot into FOG

**Note**: The FAT32 image containing the MOK certificate is automatically accessible over the network from the container.

### Verify Setup

You can verify the Secure Boot setup is working:

```bash
# Check if Secure Boot files are present
docker exec fog-server ls -la /tftpboot/ | grep -E "(BOOTX64|mmx64|ipxe)"

# Check if keys were generated
docker exec fog-server ls -la /opt/fog/secure-boot/keys/

# Check if certificates were created
docker exec fog-server ls -la /opt/fog/secure-boot/certs/

# Check if FAT32 image was created
docker exec fog-server ls -la /opt/fog/secure-boot/mok-certs.img
```

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `FOG_SECURE_BOOT_ENABLED` | Enable Secure Boot setup and auto-run complete setup | `false` |

### Manual Setup

If you prefer manual control:

```bash
# Generate keys
docker exec fog-server /opt/fog/secure-boot/scripts/generate-keys.sh

# Setup Secure Boot
docker exec fog-server /opt/fog/secure-boot/scripts/setup-secure-boot.sh
```

### Troubleshooting

#### Dell Machines

Some Dell machines have UEFI bugs:

- **Boot Entry Issue**: Create files matching network card boot entry names
- **Key Enrollment Issue**: Use specific certificate filenames like `ENROL_THIS_KEY_IN_MOK_MANAGER.cer`

#### Common Issues

- **Shim not loading**: Ensure DHCP points to `BOOTX64.efi` and Secure Boot is enabled in UEFI
- **MOK Manager not appearing**: Check that `mmx64.efi` is present in TFTP directory
- **Key enrollment fails**: Verify certificate is on FAT32 USB drive and UEFI Secure Boot is enabled
- **iPXE not loading**: Ensure iPXE binary is signed and Secure Boot keys are properly enrolled
- **Container startup issues**: Check that `FOG_SECURE_BOOT_ENABLED=true` is set in `.env` file

### Security Considerations

- Keep private keys secure and never distribute them
- The MOK certificate can be safely distributed for key enrollment
- Consider key rotation for production environments
- Monitor for UEFI firmware updates that might affect compatibility

### References

- [FOG Project Forum - Secure Boot Tutorial](https://forums.fogproject.org/)
- [rhboot/shim GitHub](https://github.com/rhboot/shim)
- [iPXE shim command documentation](https://ipxe.org/cmd/shim)

## 🌐 Network Configuration

This stack uses **host networking mode** for optimal performance with network booting. This means:

- All containers share the host's network stack
- No port mapping conflicts
- Direct access to network interfaces for multicast
- TFTP, NFS, and FTP services work seamlessly

### Port Usage

| Service | Port | Protocol | Description |
|---------|------|----------|-------------|
| Apache | 80 (configurable) | HTTP | FOG web interface |
| Apache | 443 (configurable) | HTTPS | FOG web interface (SSL) |
| MariaDB | 3306 (configurable) | TCP | Database |
| TFTP | 69 | UDP | Network booting |
| NFS | 2049 | TCP/UDP | Image storage |
| FTP | 21 | TCP | File transfers |

## 🏗️ Architecture

### **Current Implementation (Host Networking)**

```text
┌─────────────────────────────────────────────────────────────┐
│                    HOST NETWORK STACK                       │
│  ┌─────────────────┐    ┌─────────────────┐    ┌──────────┐ │
│  │   fog-server    │    │    fog-db       │    │fog-tftp  │ │
│  │   (Apache/PHP)  │◄──►│   (MariaDB)     │    │(TFTP)    │ │
│  └─────────────────┘    └─────────────────┘    └──────────┘ │
│           │                                                 │
│           ▼                                                 │
│  ┌─────────────────┐    ┌─────────────────┐                 │
│  │   fog-nfs       │    │   fog-ftp       │                 │
│  │   (NFS Server)  │    │   (FTP Server)  │                 │
│  └─────────────────┘    └─────────────────┘                 │
└─────────────────────────────────────────────────────────────┘
```

**Note**: All containers share the host's network stack due to FOG's networking requirements. This limits portability but ensures compatibility with the FOG Services

### **Ideal Architecture (Container Networking)**

For a truly portable, cloud-ready deployment, see the [FOG Project Improvements](FOG-IMPROVEMENTS.md) document for the proposed container-native architecture with proper service discovery and networking.

## 🔄 Services

### fog-server

- **Image**: Custom FOG server image
- **Purpose**: Main FOG web interface and services
- **Ports**: 80 (HTTP), 443 (HTTPS)
- **Features**: Apache, PHP, FOG services, supervisor
- **Workarounds**:
  - Runtime configuration generation using environment variables
  - Dynamic `default.ipxe` creation for iPXE booting
  - Database schema updates at startup

### fog-db

- **Image**: `mariadb:10.11`
- **Purpose**: FOG database
- **Port**: 3306
- **Features**: Persistent storage, optimized for FOG
- **Workarounds**:Custom port (3307) required because FOG assumes MySQL runs on standard port 3306, creating configuration complexity

### fog-tftp

- **Image**: `fogproject/tftp:latest`
- **Purpose**: TFTP server for network booting
- **Port**: 69 (UDP)
- **Features**: iPXE boot files, network boot support
- **Workarounds**:Host networking required because FOG assumes TFTP runs on localhost, though TFTP itself could work on container networks

### fog-nfs

- **Image**: `fogproject/nfs:latest`
- **Purpose**: NFS server for image storage
- **Port**: 2049
- **Features**: Image storage, multicast support
- **Workarounds**:Host networking required for multicast operations

### fog-ftp

- **Image**: `fogproject/ftp:latest`
- **Purpose**: FTP server for file transfers
- **Port**: 21
- **Features**: File uploads, image transfers
- **Workarounds**:Host networking for direct file access

## 🌐 Reverse Proxy Integration

This stack can used standalone or in a reverse proxy configuration. Here is a traefik example, but it should work with others.

```yaml
# traefik/dynamic/fog.yml
http:
  routers:
    fog:
      rule: "Host(`fog.example.com`)"
      service: fog
      tls: {}
  services:
    fog:
      loadBalancer:
        servers:
          - url: "http://192.168.3.184:8080"
```

## 📁 Directory Structure

```text
fog-docker/
├── docker-compose-example.yaml  # Docker Compose template
├── .env.example                 # Environment template
├── .gitignore                   # Git ignore rules
├── README.md                    # This file
└── config/
    └── server/
        ├── Dockerfile           # FOG server image
        ├── entrypoint.sh        # Container startup script
        ├── supervisord.conf     # Service management
        ├── apache-fog.conf      # Apache configuration
        ├── ports.conf           # Apache ports
        └── fog-config.php       # FOG configuration template
```

## 🔧 Customization

### Custom FOG Version

To use a different FOG version, modify the Dockerfile:

```dockerfile
ARG FOG_VERSION=1.5.10.1673
ARG FOG_GIT_REF=1.5.10.1673
```

### Adding Custom Boot Files

Place custom iPXE boot files in the `config/server/` directory and they will be copied to the TFTP server.

### SSL Configuration

To enable SSL:

1. Set `FOG_HTTPS_ENABLED=true` in `.env`
2. Place SSL certificates in the appropriate directory
3. Update reverse proxy configuration for HTTPS

## 🐛 Troubleshooting

### Common Issues

### Database Connection Failed

```bash
# Check database status
docker compose logs fog-db

# Verify database is running
docker compose ps fog-db
```

### TFTP Not Working

```bash
# Check TFTP service
docker compose logs fog-tftp

# Verify port 69 is available
sudo netstat -ulnp | grep :69
```

### Web Interface Not Accessible

```bash
# Check Apache logs
docker compose logs fog-server

# Verify port 8080 is available
sudo netstat -tlnp | grep :8080
```

### Logs

View logs for all services:

```bash
docker compose logs -f
```

View logs for specific service:

```bash
docker compose logs -f fog-server
```

### Health Checks

Check service health:

```bash
docker compose ps
```

## 🔄 Updates

To update the FOG stack:

```bash
# Pull latest changes
git pull

# Rebuild and restart
docker compose down
docker compose build --no-cache
docker compose up -d
```

## 📋 TODO

- [ ] Full testing in various environments (community support required)
- [ ] Let's Encrypt cert generation
- [ ] Secure Boot testing with various UEFI implementations
- [ ] Secure Boot testing with Dell machines (known UEFI issues - community support required)
- [ ] Secure Boot key enrollment workflow testing

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

### **FOG Project Improvements**

This Docker stack represents a **pragmatic workaround** for FOG's current architecture limitations. For information about the changes needed to make FOG Project truly Docker-friendly and container-native, see [FOG-IMPROVEMENTS.md](FOG-IMPROVEMENTS.md).

**The improvements document outlines:**

- Specific code changes needed in FOG's source code
- How to make FOG stateless and portable
- Container-native networking solutions
- Environment variable support implementation
- Static vs dynamic configuration strategies

**Why This Matters:**

- **Current State**: This Docker stack works but requires compromises
- **Future State**: With FOG improvements, we could have a truly portable, cloud-ready deployment
- **Community Impact**: These improvements would benefit all FOG users, not just Docker deployments

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/88fingerslukee/fog-docker/issues)
- **Documentation**: [FOG Project Wiki](https://wiki.fogproject.org/)
- **Community**: [FOG Project Forum](https://forums.fogproject.org/)

## 🙏 Acknowledgments

- [FOG Project](https://fogproject.org/) - The amazing disk imaging solution
- [Docker](https://www.docker.com/) - Containerization platform
- [PHP Official Image](https://hub.docker.com/_/php) - Base image for FOG server
- [MariaDB Official Image](https://hub.docker.com/_/mariadb) - Database container
- [kalaksi/tftpd](https://hub.docker.com/r/kalaksi/tftpd) - TFTP server container
- [erichough/nfs-server](https://hub.docker.com/r/erichough/nfs-server) - NFS server container
- [stilliard/pure-ftpd](https://hub.docker.com/r/stilliard/pure-ftpd) - FTP server container
- [Supervisor](http://supervisord.org/) - Process management within containers

---

**Note**: This is a community project and is not officially affiliated with the FOG Project. Use at your own risk in production environments.

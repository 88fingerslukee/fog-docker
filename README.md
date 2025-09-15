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

```bash
FOG_DHCP_ENABLED=true
FOG_DHCP_START_RANGE=192.168.1.100
FOG_DHCP_END_RANGE=192.168.1.200
FOG_DHCP_DNS=8.8.8.8
```

## 📚 References

- [FOG Project](https://fogproject.org/)
- [FOG Installation Analysis](fog_installation_analysis.md)
- [Zulip Statelessness Analysis](zulip_statelessness_analysis.md)
- [Docker Compose Documentation](https://docs.docker.com/compose/)

## 🤝 Contributing

This implementation follows the Zulip Docker pattern for statelessness. Contributions are welcome to improve the implementation and add features.

## 📄 License

This project is licensed under the same terms as the FOG Project.

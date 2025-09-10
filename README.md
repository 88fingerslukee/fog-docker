# FOG Project Docker Stack

A complete Docker Compose stack for running the FOG Project (Free and Open Ghost) disk imaging and cloning solution. This setup provides a production-ready FOG server with all necessary services containerized and configured for easy deployment.

## 🚀 Features

- **Complete FOG Stack**: Web interface, TFTP, NFS, FTP, and database services
- **Host Networking**: Optimized for network booting and multicast operations
- **Reverse Proxy Ready**: Compatible with any reverse proxy (Traefik, Nginx, Caddy, etc.)
- **Dynamic Configuration**: Environment-based configuration with templates
- **Production Ready**: Includes logging, health checks, and proper service management
- **Easy Deployment**: One-command setup with Docker Compose
- **Community Resource**: Includes roadmap for FOG Project containerization improvements

## ⚠️ Current Limitations & Trade-offs

This Docker stack works around FOG's **two fundamental architectural issues** without modifying the FOG source code:

### **1. IP Matching Logic Doesn't Work in Containers**
- **Why**: FOG services use `getIPAddress()` to auto-detect if they're the master storage node by comparing their IP addresses against storage node IPs in the database. In containers, this IP matching fails because the container's view of IPs doesn't match the storage node configuration.
- **Impact**: Forces the use of host networking to make the IP matching work, limiting portability and preventing true container isolation
- **Example**: Services can't determine if they're the master storage node without host networking

### **2. Inability to Make it Stateless**
- **Why**: FOG's install script generates configuration files at installation time with hardcoded values. There's no support for environment variables in the core configuration system, and database settings must be updated at runtime.
- **Impact**: Can't create static images because configuration depends on runtime environment. Configuration must be regenerated and the main fog-server container must be rebuilt with environment variables and database updates in order to implement changes.

### **Additional Compromises Required:**
- **Database Dependency at Startup**: FOG requires database connection and schema updates during initialization
- **Port Conflicts**: FOG assumes standard ports (80, 443, 69, 21, 2049, 3306) are available and has no dynamic port configuration. 
- **Apache Dependency**: FOG is tightly coupled to Apache as the web server and cannot easily use other web servers (nginx, Caddy, etc.)

**For solutions to these limitations, see the [FOG Project Improvements](FOG-IMPROVEMENTS.md) document.**

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
cp .env.example .env
# Edit .env with your configuration
nano .env
```

**Required Configuration:**
- `FOG_WEB_HOST`: Your FQDN (e.g., `fog.example.com`) - **No default, must be set**
- `FOG_DB_ROOT_PASSWORD`: Database root password - **No default, must be set for security**

**Optional Configuration (with defaults):**
- `FOG_VERSION`: FOG version (e.g., `1.5.10.1673`) - **Default: Latest stable release**
- `FOG_WEB_ROOT`: Web root path - **Default: `/fog`**
- `FOG_DB_PORT`: Database port - **Default: `3306`**
- `FOG_APACHE_PORT`: Apache HTTP port - **Default: `80`**
- `FOG_APACHE_SSL_PORT`: Apache HTTPS port - **Default: `443`**

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
| `FOG_WEB_HOST` | FQDN for FOG server (required for reverse proxy) | `fog.example.com` | **None** |
| `FOG_DB_ROOT_PASSWORD` | MySQL root password | `secure_password123` | **None** |

#### Optional Variables

| Variable | Description | Example | Default |
|----------|-------------|---------|---------|
| `FOG_VERSION` | FOG version to install | `1.5.10.1673` | `latest` |
| `FOG_WEB_ROOT` | Web root path | `/fog` | `/fog` |
| `FOG_DB_PORT` | Database port | `3306` | `3306` |
| `FOG_APACHE_PORT` | Apache HTTP port | `80` | `80` |
| `FOG_APACHE_SSL_PORT` | Apache HTTPS port | `443` | `443` |
| `FOG_DB_NAME` | Database name | `fog` | `fog` |
| `FOG_DB_USER` | Database user | `fogmaster` | `fogmaster` |
| `FOG_DB_PASS` | Database password | `fogpass123` | `fogmaster123` |
| `FOG_USERNAME` | FTP username | `fogproject` | `fogproject` |
| `FOG_PASSWORD` | FTP password | `ftppass123` | `fogftp123` |
| `FOG_TIMEZONE` | System timezone | `America/New_York` | `UTC` |
| `FOG_HTTPS_ENABLED` | Enable HTTPS | `true` | `false` |
| `FOG_SSL_GENERATE_SELF_SIGNED` | Generate self-signed cert | `true` | `true` |
| `FOG_SSL_CN` | Certificate Common Name | `fog.example.com` | `${FOG_WEB_HOST}` |

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

**Note**: After changing ports, you may need to update your reverse proxy configuration and rebuild containers.

### SSL/HTTPS Configuration

The stack supports both HTTP and HTTPS configurations:

#### Standalone HTTPS (Self-Signed Certificate)
```bash
FOG_HTTPS_ENABLED=true
FOG_SSL_GENERATE_SELF_SIGNED=true
FOG_SSL_CN=fog.yourdomain.com
```

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
```
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
- **Workarounds**: Custom port (3307) required because FOG assumes MySQL runs on standard port 3306, creating configuration complexity

### fog-tftp
- **Image**: `fogproject/tftp:latest`
- **Purpose**: TFTP server for network booting
- **Port**: 69 (UDP)
- **Features**: iPXE boot files, network boot support
- **Workarounds**: Host networking required because FOG assumes TFTP runs on localhost, though TFTP itself could work on container networks

### fog-nfs
- **Image**: `fogproject/nfs:latest`
- **Purpose**: NFS server for image storage
- **Port**: 2049
- **Features**: Image storage, multicast support
- **Workarounds**: Host networking required for multicast operations

### fog-ftp
- **Image**: `fogproject/ftp:latest`
- **Purpose**: FTP server for file transfers
- **Port**: 21
- **Features**: File uploads, image transfers
- **Workarounds**: Host networking for direct file access

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

```
fog-docker/
├── compose.yaml              # Docker Compose configuration
├── .env.example             # Environment template
├── .gitignore               # Git ignore rules
├── README.md                # This file
└── config/
    └── server/
        ├── Dockerfile       # FOG server image
        ├── entrypoint.sh    # Container startup script
        ├── supervisord.conf # Service management
        ├── apache-fog.conf  # Apache configuration
        ├── ports.conf       # Apache ports
        └── fog-config.php   # FOG configuration template
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

**Database Connection Failed**
```bash
# Check database status
docker compose logs fog-db

# Verify database is running
docker compose ps fog-db
```

**TFTP Not Working**
```bash
# Check TFTP service
docker compose logs fog-tftp

# Verify port 69 is available
sudo netstat -ulnp | grep :69
```

**Web Interface Not Accessible**
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

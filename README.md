# FOG Docker

**⚠️ BETA SOFTWARE - This project is in active development and may have bugs or incomplete features.**

A Docker containerization of the FOG Project - an open-source computer cloning and imaging solution. This project provides a complete FOG server running in Docker containers with automatic configuration and setup.

## Quick Start

### Production Setup (Recommended)

1. **Create a directory and download the required files:**
   ```bash
   mkdir fog-docker && cd fog-docker
   curl -O https://raw.githubusercontent.com/88fingerslukee/fog-docker/main/docker-compose.yml
   curl -O https://raw.githubusercontent.com/88fingerslukee/fog-docker/main/.env.example
   cp .env.example .env
   ```

2. **Edit .env with your settings:**
   ```bash
   # Required settings
   FOG_WEB_HOST=192.168.1.100
   FOG_DB_ROOT_PASSWORD=your-secure-password
   ```

3. **Start FOG:**
   ```bash
   docker compose up -d
   ```

4. **Access FOG:**
   - Web Interface: `https://your-server-ip/fog/management/` (accept the self-signed certificate warning on first visit)
   - Default login: `fog` / `password` (change immediately!)

### Development Setup

For development, testing, or custom FOG versions:

```bash
git clone https://github.com/88fingerslukee/fog-docker.git
cd fog-docker
cp .env.example .env
# Edit .env to set your variables
docker compose -f docker-compose-dev.yml up -d --build
```

## Configuration

### Required Settings

Edit your `.env` file and set these **required** variables:

```bash
# Your server's IP address or FQDN that clients will use to access FOG
FOG_WEB_HOST=192.168.1.100

# Secure password for the MySQL root user
FOG_DB_ROOT_PASSWORD=your-secure-password
```

### Common Optional Settings

```bash
# Network configuration (defaults to FOG_WEB_HOST if not set)
FOG_STORAGE_HOST=192.168.1.100
FOG_TFTP_HOST=192.168.1.100
FOG_WOL_HOST=192.168.1.100

# Protocol configuration (default: self-signed HTTPS — see .env.example scenarios)
FOG_HTTP_PROTOCOL=https
FOG_INTERNAL_HTTPS_ENABLED=true

# FTP passive mode (default: 21100-21110)
FOG_FTP_PASV_MIN_PORT=21100
FOG_FTP_PASV_MAX_PORT=21110
```

## Ports

FOG Docker exposes the following ports:

- **80/443**: Web interface (HTTP/HTTPS)
- **69/UDP**: TFTP server
- **21**: FTP server
- **21100-21110**: FTP passive mode port range (configurable)
- **2049**: NFS server
- **111**: NFS RPC portmapper
- **32765**: NFS RPC statd (kernel NFS only)
- **32767**: NFS RPC mountd

## Userland NFS (optional)

Kernel NFS is the default and needs privileged mode. To use the userland NFSv3 server instead:

```bash
FOG_NFS_MODE=unfs3
FOG_PRIVILEGED=false
```

Ports 111, 2049, and 32767 are still required. Port 32765 is used only by kernel NFS.

## Available Image Tags

- `ghcr.io/88fingerslukee/fog-docker:latest` - Latest **final** FOG release
- `ghcr.io/88fingerslukee/fog-docker:fog-1.5.10.2482` - Specific FOG version
- `ghcr.io/88fingerslukee/fog-docker:fog-1.6.0-RC-6` - Release candidate (also listed as a GitHub pre-release; **not** tagged `:latest`)
- `ghcr.io/88fingerslukee/fog-docker:fog-dev-branch` - Development branch

## Documentation

**👉 [View Complete Documentation](https://88fingerslukee.github.io/fog-docker/)**

Our comprehensive documentation covers:

### Quick Reference
- **[Installation Guide](https://88fingerslukee.github.io/fog-docker/installation)** - Detailed installation instructions
- **[Configuration Guide](https://88fingerslukee.github.io/fog-docker/configuration)** - Complete configuration options
- **[Environment Variables](https://88fingerslukee.github.io/fog-docker/environment-variables)** - All 50+ variables explained

### Advanced Topics
- **[SSL/HTTPS Setup](https://88fingerslukee.github.io/fog-docker/ssl-https)** - SSL certificate configuration
- **[Reverse Proxy Setup](https://88fingerslukee.github.io/fog-docker/reverse-proxy)** - Deploy behind Traefik, Nginx, Apache, or Caddy
- **[Network Boot Setup](https://88fingerslukee.github.io/fog-docker/network-boot)** - PXE and HTTPBoot configuration
- **[DHCP Integration](https://88fingerslukee.github.io/fog-docker/dhcp-integration)** - Integrate with existing DHCP servers

### Migration & Integration
- **[Migration from Bare Metal](https://88fingerslukee.github.io/fog-docker/migration-bare-metal)** - Migrate existing FOG installations
- **[External Database](https://88fingerslukee.github.io/fog-docker/external-database)** - Use external MySQL/MariaDB
- **[Troubleshooting Guide](https://88fingerslukee.github.io/fog-docker/troubleshooting)** - Common issues and solutions

## Common Use Cases

### Single Server Setup (default — self-signed HTTPS)
```bash
FOG_WEB_HOST=192.168.1.100
FOG_DB_ROOT_PASSWORD=your-secure-password
FOG_HTTP_PROTOCOL=https
FOG_INTERNAL_HTTPS_ENABLED=true
# Browse https://192.168.1.100/fog/management/
```

### HTTP Only (lab/testing)
```bash
FOG_WEB_HOST=192.168.1.100
FOG_DB_ROOT_PASSWORD=your-secure-password
FOG_HTTP_PROTOCOL=http
FOG_INTERNAL_HTTPS_ENABLED=false
# Browse http://192.168.1.100/fog/management/
```

### Reverse Proxy with HTTPS (Traefik, Nginx, Caddy — access via proxy only)
```bash
FOG_WEB_HOST=fog.example.com
FOG_DB_ROOT_PASSWORD=your-secure-password
FOG_HTTP_PROTOCOL=https
FOG_INTERNAL_HTTPS_ENABLED=false
```

### Internal HTTPS with custom certificate
```bash
FOG_WEB_HOST=192.168.1.100
FOG_DB_ROOT_PASSWORD=your-secure-password
FOG_HTTP_PROTOCOL=https
FOG_INTERNAL_HTTPS_ENABLED=true
FOG_APACHE_SSL_CN=192.168.1.100
```

## Troubleshooting

### Quick Fixes

**Container won't start:**
```bash
docker compose logs fog-server
```

**Can't access web interface:**
- Check `FOG_WEB_HOST` is correct
- Verify port 80/443 is accessible
- Check firewall rules

**PXE boot not working:**
- Verify `FOG_TFTP_HOST` is reachable
- Check DHCP option 66 (next-server) points to your server
- Ensure port 69/UDP is open

**FTP image upload fails:**
- Check FTP passive port range (21100-21110) is open
- Verify `FOG_WEB_HOST` resolves correctly from clients

**Default admin login (fog/password) loops back to empty form:**
This usually means the URL in your browser does not match `FOG_HTTP_PROTOCOL` / `FOG_INTERNAL_HTTPS_ENABLED`. See the [Troubleshooting Guide](https://88fingerslukee.github.io/fog-docker/troubleshooting#login-loops-back-to-empty-form-no-error).

**Default admin login (fog/password) doesn't work:**
If the default credentials `fog` / `password` don't work, verify the admin user was created:

```bash
# Check if admin user exists in database
docker exec fog-server mysql -h fog-db -u fogmaster -pfogmaster123 -e "SELECT uName FROM fog.users WHERE uName='fog';"

# If the user doesn't exist, you may need to complete installation through the web interface
# Visit: http://your-server-ip/fog/management/index.php?node=schema
# Click "Install/Update Now" to ensure the admin user is created
```

**Note:** Future versions will automatically verify and report admin user creation status in the logs.

For detailed troubleshooting, see the [Troubleshooting Guide](https://88fingerslukee.github.io/fog-docker/troubleshooting).

## Contributing

This project is in active development. Contributions, bug reports, and feature requests are welcome!

## Support

If you find this project useful, consider supporting development:

[![PayPal](https://www.paypalobjects.com/en_US/i/btn/btn_donateCC_LG.gif)](https://paypal.me/88fingerslukee)

## License

This project is licensed under the GPL v3 License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- [FOG Project](https://github.com/FOGProject/fogproject) - The original FOG imaging solution
- [@Cpasjuste](https://github.com/Cpasjuste) for the userland NFS approach in [docker-fog](https://github.com/Cpasjuste/docker-fog)
- [@MonolithicRamone](https://github.com/MonolithicRamone) for testing and issue reporting
- [@LuukBlankenstijn](https://github.com/LuukBlankenstijn) for UDP Casting testing and fix
- [@IMazarithI](https://github.com/IMazarithI) for iPXE boot file and storage node testing
- [@derricklee88](https://github.com/derricklee88) for tftpboot testing
- [@craiggc-hub](https://github.com/craiggc-hub) for boot file and login testing
- [@Toratoru](https://github.com/Toratoru) for login testing
- [@BennettPaul](https://github.com/BennettPaul) for Compose database configuration testing
- Docker community for containerization best practices

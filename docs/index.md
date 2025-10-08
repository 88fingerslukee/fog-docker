---
layout: default
title: FOG Docker Documentation
nav_order: 1
description: "Complete documentation for FOG Docker - an open-source computer cloning and imaging solution"
permalink: /
---

# FOG Docker Documentation

Welcome to the FOG Docker documentation! This comprehensive guide covers everything you need to deploy and manage FOG (Free Open-source Ghost) in Docker containers.

## Quick Start

Get FOG Docker up and running in minutes:

1. **Download and configure:**
   ```bash
   mkdir fog-docker && cd fog-docker
   curl -O https://raw.githubusercontent.com/88fingerslukee/fog-docker/main/docker-compose.yml
   curl -O https://raw.githubusercontent.com/88fingerslukee/fog-docker/main/.env.example
   cp .env.example .env
   ```

2. **Edit .env with your settings:**
   ```bash
   FOG_WEB_HOST=192.168.1.100
   FOG_DB_ROOT_PASSWORD=your-secure-password
   ```

3. **Start FOG:**
   ```bash
   docker compose up -d
   ```

4. **Access FOG:**
   - Web Interface: `http://your-server-ip/fog`
   - Default login: `fog` / `password` (change immediately!)

## What is FOG Docker?

FOG Docker is a complete containerization of the FOG Project, providing:

- **🖥️ Computer Imaging**: Capture and deploy disk images across your network
- **📦 Docker Containerization**: Easy deployment and management
- **🔧 Automatic Configuration**: Environment-based setup
- **🌐 Network Boot**: PXE and HTTPBoot support
- **🔒 SSL/HTTPS**: Multiple SSL configuration options
- **🔄 Migration Support**: Import from existing FOG installations

## Documentation Sections

### Getting Started
- **[Installation Guide](installation.md)** - Detailed installation instructions
- **[Configuration Guide](configuration.md)** - Complete configuration options
- **[Network Boot Setup](network-boot.md)** - PXE and HTTPBoot configuration

### SSL & Security
- **[SSL/HTTPS Setup](ssl-https.md)** - SSL certificate configuration
- **[Reverse Proxy Setup](reverse-proxy.md)** - Deploy behind Traefik, Nginx, Apache, or Caddy

### Integration & Migration
- **[Migration from Bare Metal](migration-bare-metal.md)** - Migrate existing FOG installations
- **[External Database](external-database.md)** - Use external MySQL/MariaDB
- **[DHCP Integration](dhcp-integration.md)** - Integrate with existing DHCP servers

### Reference
- **[Environment Variables](environment-variables.md)** - Complete list of configuration options (50+ variables explained)
- **[Troubleshooting Guide](troubleshooting.md)** - Common issues and solutions

## Common Use Cases

### Single Server Setup
Perfect for small to medium environments:
```bash
FOG_WEB_HOST=192.168.1.100
FOG_DB_ROOT_PASSWORD=your-secure-password
FOG_HTTP_PROTOCOL=http
FOG_INTERNAL_HTTPS_ENABLED=false
```

### Production with Reverse Proxy
For production environments with SSL:
```bash
FOG_WEB_HOST=fog.example.com
FOG_DB_ROOT_PASSWORD=your-secure-password
FOG_HTTP_PROTOCOL=https
FOG_INTERNAL_HTTPS_ENABLED=false
```

### Internal HTTPS
For secure internal networks:
```bash
FOG_WEB_HOST=192.168.1.100
FOG_DB_ROOT_PASSWORD=your-secure-password
FOG_HTTP_PROTOCOL=https
FOG_INTERNAL_HTTPS_ENABLED=true
FOG_APACHE_SSL_CN=192.168.1.100
```

## Support

- **GitHub Repository**: [88fingerslukee/fog-docker](https://github.com/88fingerslukee/fog-docker)
- **FOG Project**: [FOGProject/fogproject](https://github.com/FOGProject/fogproject)
- **Issues**: Report bugs and request features on GitHub

---

**⚠️ BETA SOFTWARE** - This project is in active development and may have bugs or incomplete features.

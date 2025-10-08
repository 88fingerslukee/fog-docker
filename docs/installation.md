# Installation Guide

This guide will help you get FOG Docker up and running quickly.

## Prerequisites

- Docker and Docker Compose installed
- At least 4GB RAM available
- 20GB+ free disk space
- Network access for downloading FOG client files

## Quick Installation

### Option 1: Quick Setup (Recommended)

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
   - Web Interface: `http://your-server-ip/fog`
   - Default login: `fog` / `password`

### Option 2: Full Repository Clone

```bash
git clone https://github.com/88fingerslukee/fog-docker.git
cd fog-docker
cp .env.example .env
# Edit .env with your settings
docker compose up -d
```

## Development Setup

For development, testing, or custom FOG versions:

1. **Clone the repository:**
   ```bash
   git clone https://github.com/88fingerslukee/fog-docker.git
   cd fog-docker
   ```

2. **Configure your environment:**
   ```bash
   cp .env.example .env
   # Edit .env to set your variables, including FOG_VERSION for specific versions
   ```

3. **Build and start the containers:**
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

## Next Steps

After installation, continue with:

1. **[Configuration Guide](configuration.md)** - Configure FOG for your environment
2. **[Network Boot Setup](network-boot.md)** - Set up PXE and HTTPBoot
3. **[SSL/HTTPS Setup](ssl-https.md)** - Configure SSL certificates (optional)

## Troubleshooting

If you encounter issues during installation:

1. **Check container logs:**
   ```bash
   docker compose logs fog-server
   docker compose logs fog-db
   ```

2. **Verify environment variables:**
   ```bash
   cat .env
   ```

3. **Check port availability:**
   ```bash
   netstat -tulpn | grep -E ':(80|443|69|21|2049)'
   ```

4. **See [Troubleshooting Guide](troubleshooting.md)** for common issues and solutions.

## Security Notes

**Important**: Change the default FOG web UI admin password immediately after first login:

- **Default Username**: `fog`
- **Default Password**: `password`
- **Action Required**: Change this password in the FOG web interface for security!

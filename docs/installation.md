---
layout: default
title: Installation Guide
nav_order: 2
description: "Get FOG Docker up and running quickly"
permalink: /installation
---

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

   # FOG 1.6 capture finalize (default; keep for single-container installs)
   FOG_STORAGE_NODE_SSH_HOST=127.0.0.1
   ```

3. **Start FOG:**
   ```bash
   docker compose up -d
   ```

4. **Access FOG:**
   - Web Interface: `https://your-server-ip/fog/management/` (accept the self-signed certificate on first visit)
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
   # Edit .env: set FOG_WEB_HOST, FOG_DB_ROOT_PASSWORD, and optionally FOG_VERSION
   # FOG_VERSION is any FOG git ref (stable, working-1.6, 1.6.0-RC-6, …)
   ```

3. **Build and start the containers:**
   ```bash
   docker compose -f docker-compose-dev.yml up -d --build
   ```

**Note:** Development setup builds FOG from source. Web UI is published on 8080/8443 by default; TFTP/FTP stay on 69/21. Set `FOG_VERSION` in `.env` to any FOG git ref (`stable`, `working-1.6`, `1.6.0-RC-6`, etc.).

## Automatic Releases

This project automatically builds and publishes new Docker images when the FOG Project releases new versions:

- **Automatic Detection**: Checks for new FOG releases every 6 hours
- **Final releases**: Tagged `fog-<upstream-tag>` and `:latest`
- **Release candidates**: Tagged `fog-<upstream-tag>` and `:rc`; published as a GitHub **pre-release** (**not** `:latest`)
- **Every push to `main`**: CI rebuilds **both** the newest final release (`:latest`) and the newest RC (`:rc` + `fog-<RC>`), so pinned and rolling tags pick up fog-docker fixes without waiting for a new upstream FOG tag
- **Not auto-built**: alpha / beta / preview tags (use the dev compose file or a manual workflow dispatch if needed)
- **Manual Trigger**: You can manually trigger builds for specific FOG versions

### Available Image Tags

| Tag | Meaning |
|-----|---------|
| `:latest` | Newest final FOG release |
| `:fog-<release>` | Pin to a specific published build (see [GitHub Releases](https://github.com/88fingerslukee/fog-docker/releases)) |
| `:rc` | Newest release candidate (pre-release channel) |

Full image reference: `ghcr.io/88fingerslukee/fog-docker:<tag>`. Custom FOG refs are built locally with `docker-compose-dev.yml` and `FOG_VERSION`.

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

4. **Capture stuck on “Updating Database” or task Failed after upload:** see [Post_Stage2 / SSH finalize](troubleshooting.md#capture-finishes-but-task-fails-on-updating-database-post_stage2-http-500).

5. **See [Troubleshooting Guide](troubleshooting.md)** for other common issues and solutions.

## Security Notes

Kernel NFS requires `privileged: true`. To run without privileged mode, set `FOG_NFS_MODE=unfs3` and `FOG_PRIVILEGED=false`. See the [configuration guide](configuration.md#nfs-server).

**Important**: Change the default FOG web UI admin password immediately after first login:

- **Default Username**: `fog`
- **Default Password**: `password`
- **Action Required**: Change this password in the FOG web interface for security!

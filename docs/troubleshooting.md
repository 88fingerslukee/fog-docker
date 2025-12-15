---
layout: default
title: Troubleshooting
nav_order: 11
description: "Common issues and solutions for FOG Docker"
permalink: /troubleshooting
---

# Troubleshooting Guide

This guide covers common issues and solutions for FOG Docker.

## Container Issues

### Container Won't Start

1. **Check container logs:**
   ```bash
   docker compose logs fog-server
   docker compose logs fog-db
   ```

2. **Verify environment variables:**
   ```bash
   cat .env
   ```

3. **Check port conflicts:**
   ```bash
   netstat -tulpn | grep -E ':(80|443|69|21|2049)'
   ```

4. **Verify Docker resources:**
   ```bash
   docker system df
   docker system prune  # Clean up if needed
   ```

### Database Connection Issues

1. **Check database container status:**
   ```bash
   docker compose ps fog-db
   ```

2. **Test database connectivity:**
   ```bash
   docker exec fog-server mysql -h fog-db -u root -p$FOG_DB_ROOT_PASSWORD
   ```

3. **Check database logs:**
   ```bash
   docker compose logs fog-db
   ```

4. **Verify database environment variables:**
   ```bash
   grep FOG_DB_ .env
   ```

### Default Admin Login (fog/password) Not Working

If the default credentials `fog` / `password` don't work, follow these steps to diagnose and fix the issue.

#### Step 1: Verify the Admin User Exists

Check if the admin user was created in the database:

```bash
docker exec fog-server mysql -h fog-db -u fogmaster -pfogmaster123 -e "SELECT uName, uId FROM fog.users WHERE uName='fog';"
```

**Expected output:** Should show a row with `uName='fog'` and a `uId` number.

**If empty:** The admin user wasn't created during schema initialization.

#### Step 2: Check Schema Initialization Logs

Review the container logs for schema initialization:

```bash
docker compose logs fog-server | grep -i "schema\|admin\|user" | tail -20
```

Look for:
- "Database schema check/update completed successfully"
- Any errors during schema initialization

#### Step 3: Manually Trigger Schema Initialization

If the admin user doesn't exist, manually complete the installation:

1. Open your browser and go to:
   ```
   http://your-server-ip/fog/management/index.php?node=schema
   ```
   (Replace `your-server-ip` with your actual server IP or FQDN)

2. You should see a page titled "Database Schema Installer / Updater"

3. Click the **"Install/Update Now"** button

4. Wait for the success message

5. Try logging in again with `fog` / `password`

#### Step 4: Verify After Manual Installation

After completing Step 3, verify the user exists:

```bash
docker exec fog-server mysql -h fog-db -u fogmaster -pfogmaster123 -e "SELECT uName, uId FROM fog.users WHERE uName='fog';"
```

#### Step 5: Check Database Connection

If schema initialization fails, verify the database connection:

```bash
# Check if database container is running
docker compose ps fog-db

# Check database logs
docker compose logs fog-db --tail 50

# Test database connection from fog-server
docker exec fog-server mysql -h fog-db -u fogmaster -pfogmaster123 -e "SELECT 1;"
```

**Note:** Future versions will automatically verify and report admin user creation status in the logs to make this easier to diagnose.

## Network Issues

### Storage Node Connectivity Issues

1. **Verify `FOG_STORAGE_HOST` is reachable** from client machines
2. **Check that the FQDN resolves correctly** from client machines
3. **Verify firewall rules** allow access to ports 80, 443, 69, 2049, 21
4. **Test connectivity:**
   ```bash
   ping fog.example.com
   telnet fog.example.com 80
   telnet fog.example.com 443
   ```

### PXE Boot Issues

1. **Ensure `FOG_TFTP_HOST` is reachable** from client machines
2. **Check that port 69/UDP is open** and accessible
3. **Verify DHCP is configured** to point to the correct TFTP server
4. **Check that DHCP option 66** (next-server) points to `FOG_TFTP_HOST`
5. **Verify DHCP option 67** (filename) is set to the correct boot file
6. **For UEFI clients**, ensure the boot file is configured (`FOG_DHCP_BOOTFILE_UEFI`)
7. **For HTTPBoot clients**, verify that the iPXE files are accessible via HTTP (automatically available)

### HTTPBoot Issues

1. **Verify iPXE files are accessible** via HTTP/HTTPS
2. **Check protocol matches** your `FOG_HTTP_PROTOCOL` setting
3. **Test URLs directly** in a browser
4. **Verify reverse proxy** configuration (if using)

## FTP Issues

### Passive Mode Problems

1. **Ensure FTP passive port range** (21100-21110) is open in firewall
2. **Check `FOG_FTP_PASV_MIN_PORT` and `FOG_FTP_PASV_MAX_PORT`** configuration
3. **Verify `FOG_WEB_HOST` resolves correctly** from client machines
4. **Test FTP connectivity:**
   ```bash
   ftp fog.example.com
   # Try passive mode
   ```

### Connection Issues

1. **Verify `FOG_WEB_HOST` resolves correctly** from client machines
2. **Check FTP server is running:**
   ```bash
   docker exec fog-server systemctl status vsftpd
   ```

3. **Check FTP logs:**
   ```bash
   docker exec fog-server tail -f /var/log/vsftpd.log
   ```

### Permission Errors

1. **Check that FOG user has proper permissions** on image directories
2. **Verify file ownership:**
   ```bash
   docker exec fog-server ls -la /images/
   ```

3. **Check FOG user configuration:**
   ```bash
   grep FOG_USER .env
   grep FOG_PASS .env
   ```

### "Cannot Create File" Errors

Usually indicates passive mode configuration issues:
1. **Check passive mode configuration** in vsftpd
2. **Verify passive port range** is open in firewall
3. **Check `FOG_WEB_HOST` setting** for FQDN resolution

## NFS Issues

### Permission Problems

1. **NFS exports use `root_squash`** with `anonuid=999,anongid=33` mapping
2. **Check NFS export configuration:**
   ```bash
   docker exec fog-server cat /etc/exports
   ```

3. **Verify NFS server is running:**
   ```bash
   docker exec fog-server systemctl status nfs-kernel-server
   ```

### Image Capture Issues

1. **If captured images create files instead of directories**, check NFS export configuration
2. **Verify proper ownership mapping** in NFS exports
3. **Check FOG user permissions** on image directories

### Mount Failures

1. **Verify NFS server is running** and exports are properly configured
2. **Check NFS port accessibility** (2049)
3. **Test NFS mount:**
   ```bash
   mount -t nfs fog.example.com:/images /mnt/test
   ```

## DHCP Configuration Issues

1. **Verify all DHCP network variables** match your actual network configuration
2. **Ensure `FOG_DHCP_SUBNET` and `FOG_DHCP_NETMASK`** are correct for your network
3. **Check that `FOG_DHCP_ROUTER`** points to your actual gateway
4. **Verify IP address range** (`FOG_DHCP_START_RANGE` to `FOG_DHCP_END_RANGE`) doesn't conflict with existing devices
5. **Ensure `FOG_DHCP_DNS`** contains valid DNS servers
6. **Check that all required boot files** are present in `/tftpboot/` (BIOS, UEFI)

## SSL/HTTPS Issues

### Certificate Issues

1. **Check certificate file paths** in `FOG_APACHE_SSL_CERT_FILE` and `FOG_APACHE_SSL_KEY_FILE`
2. **Verify volume mounts** are correct
3. **Check file permissions** on certificate files
4. **Verify certificate and key match**

### SSL Handshake Failed

1. **Check certificate validity dates**
2. **Ensure proper certificate chain**
3. **Verify SSL configuration** in Apache

### Mixed Content Warnings

1. **Set `FOG_HTTP_PROTOCOL=https`**
2. **Check for hardcoded HTTP URLs** in configuration

## Image Management Issues

### Image Capture/Deploy Failures

1. **Check that `FOG_STORAGE_HOST` is accessible** from client machines
2. **Verify NFS exports are working** (port 2049)
3. **Check FTP connectivity** (port 21)
4. **Verify FTP passive mode is working** (ports 21100-21110)
5. **Check NFS permissions** - captured images should create directories, not files

### Client Download Issues

1. **Verify FOG client files** are accessible at `/fog/client/`
2. **Check CA certificate** is accessible at `/fog/management/other/ca.cert.der`
3. **Verify server public certificate** at `/fog/management/other/ssl/srvpublic.crt`

## Common Error Messages

### "Cannot create file line 709"
- **Cause**: FTP passive mode configuration issues
- **Solution**: Check passive mode configuration and port range

### "Undefined array key 8" in fogftp.class.php
- **Cause**: FTP directory listing issues
- **Solution**: Check FTP server configuration and passive mode

### "Chainloading permission denied"
- **Cause**: iPXE file permission issues
- **Solution**: Check file permissions and accessibility

### "Failed to download nbp file"
- **Cause**: HTTPBoot URL accessibility issues
- **Solution**: Check HTTPBoot URL and file accessibility

## Debug Commands

### Container Debugging

```bash
# Check container status
docker compose ps

# View container logs
docker compose logs -f fog-server

# Execute shell in container
docker exec -it fog-server bash

# Check service status
docker exec fog-server supervisorctl status
```

### Network Debugging

```bash
# Test connectivity
ping fog.example.com
telnet fog.example.com 80
telnet fog.example.com 443
telnet fog.example.com 69

# Check DNS resolution
nslookup fog.example.com
dig fog.example.com
```

### File System Debugging

```bash
# Check file permissions
docker exec fog-server ls -la /images/
docker exec fog-server ls -la /tftpboot/

# Check NFS exports
docker exec fog-server cat /etc/exports

# Check FTP configuration
docker exec fog-server cat /etc/vsftpd.conf
```

## Getting Help

If you're still experiencing issues:

1. **Check the logs** for specific error messages
2. **Search existing issues** on GitHub
3. **Create a new issue** with detailed information:
   - FOG Docker version
   - Docker version
   - Operating system
   - Error messages and logs
   - Configuration details (sanitized)

## Next Steps

After resolving issues:

1. **[Configuration Guide](configuration.md)** - Review and optimize configuration
2. **[Network Boot Setup](network-boot.md)** - Verify network boot configuration
3. **[SSL/HTTPS Setup](ssl-https.md)** - Check SSL configuration if using HTTPS

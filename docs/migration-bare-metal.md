# Migration from Bare Metal FOG

This guide covers migrating from a bare metal FOG installation to FOG Docker.

## Overview

Migrating from bare metal FOG to FOG Docker involves:
1. **Exporting your existing FOG database**
2. **Configuring FOG Docker with migration settings**
3. **Importing the database automatically**
4. **Verifying the migration**

## Prerequisites

- Existing bare metal FOG installation
- Access to the FOG database
- FOG Docker environment set up
- Sufficient disk space for database export

## Migration Process

### Step 1: Export Database from Bare Metal FOG

On your existing bare metal FOG server:

```bash
# Create a complete database dump
mysqldump --single-transaction --routines --triggers --databases fog > FOG_MIGRATION_DUMP.sql

# Verify the dump file was created
ls -la FOG_MIGRATION_DUMP.sql

# Check the dump file size (should be several MB)
du -h FOG_MIGRATION_DUMP.sql
```

**Important**: The dump file must be named exactly `FOG_MIGRATION_DUMP.sql` for automatic detection.

### Step 2: Transfer Database Dump

Copy the database dump to your Docker host:

```bash
# Using SCP
scp FOG_MIGRATION_DUMP.sql user@docker-host:/path/to/fog-docker/

# Using rsync
rsync -avz FOG_MIGRATION_DUMP.sql user@docker-host:/path/to/fog-docker/

# Using USB drive or other method
# Copy FOG_MIGRATION_DUMP.sql to your Docker host
```

### Step 3: Configure FOG Docker for Migration

1. **Enable migration in your `.env` file:**
   ```bash
   # Enable database migration
   FOG_DB_MIGRATION_ENABLED=true
   
   # Optional: Force migration over existing data
   # FOG_DB_MIGRATION_FORCE=true
   ```

2. **Mount the dump file in `docker-compose.yml`:**
   ```yaml
   services:
     fog-server:
       environment:
         - FOG_WEB_HOST=${FOG_WEB_HOST}
         - FOG_HTTP_PROTOCOL=${FOG_HTTP_PROTOCOL}
         - FOG_INTERNAL_HTTPS_ENABLED=${FOG_INTERNAL_HTTPS_ENABLED}
         - FOG_APACHE_EXPOSED_PORT=${FOG_APACHE_EXPOSED_PORT}
         - FOG_DB_MIGRATION_ENABLED=${FOG_DB_MIGRATION_ENABLED}
         - FOG_DB_MIGRATION_FORCE=${FOG_DB_MIGRATION_FORCE}
       ports:
         - "${FOG_APACHE_EXPOSED_PORT:-8080}:80"
       volumes:
         - ./FOG_MIGRATION_DUMP.sql:/opt/migration/FOG_MIGRATION_DUMP.sql:ro
         # ... other volumes
   ```

   **Required .env variables:**
   ```bash
   FOG_WEB_HOST=fog.example.com
   FOG_HTTP_PROTOCOL=https
   FOG_INTERNAL_HTTPS_ENABLED=false
   FOG_APACHE_EXPOSED_PORT=8080
   FOG_DB_MIGRATION_ENABLED=true
   FOG_DB_MIGRATION_FORCE=false
   ```

### Step 4: Start FOG Docker

```bash
# Start the containers
docker compose up -d

# Monitor the migration process
docker compose logs -f fog-server
```

The container will automatically:
1. **Detect the migration dump file**
2. **Import the database**
3. **Remove the dump file** after successful import
4. **Continue with normal FOG setup**

## Migration Safety Features

### Automatic Safety Checks

- **Migration is disabled by default** (`FOG_DB_MIGRATION_ENABLED=false`)
- **Existing database protection**: If FOG database already exists, migration is skipped
- **Force migration option**: Use `FOG_DB_MIGRATION_FORCE=true` to override safety checks
- **Automatic cleanup**: Dump file is removed after successful import

### Migration Environment Variables

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `FOG_DB_MIGRATION_ENABLED` | Enable database migration | `false` | Yes |
| `FOG_DB_MIGRATION_FORCE` | Force migration over existing data | `false` | No |

### Additional Configuration Variables

| Variable | Description | Example | Default |
|----------|-------------|---------|---------|
| `FOG_WEB_HOST` | New FOG server hostname/IP | `192.168.1.100` | Required |
| `FOG_STORAGE_HOST` | Storage node hostname/IP | `192.168.1.100` | `FOG_WEB_HOST` |
| `FOG_TFTP_HOST` | TFTP server hostname/IP | `192.168.1.100` | `FOG_WEB_HOST` |
| `FOG_WOL_HOST` | Wake-on-LAN server hostname/IP | `192.168.1.100` | `FOG_WEB_HOST` |
| `FOG_HTTP_PROTOCOL` | Protocol (http/https) | `https` | `http` |

## Post-Migration Steps

### 1. Verify Database Import

```bash
# Check if migration was successful
docker exec fog-server mysql -u root -p$FOG_DB_ROOT_PASSWORD -e "USE fog; SHOW TABLES;"

# Check for your existing hosts
docker exec fog-server mysql -u root -p$FOG_DB_ROOT_PASSWORD -e "USE fog; SELECT hostname, mac FROM hosts LIMIT 10;"
```

### 2. Update Network Configuration

Update your FOG Docker configuration to match your network:

```bash
# Update .env file with your network settings
FOG_WEB_HOST=your-new-fog-server-ip
FOG_STORAGE_HOST=your-new-fog-server-ip
FOG_TFTP_HOST=your-new-fog-server-ip
FOG_WOL_HOST=your-new-fog-server-ip
```

### 3. Update DHCP Configuration

Update your DHCP server to point to the new FOG Docker server:

**DHCP Option 66 (Next Server)**: `your-new-fog-server-ip`
**DHCP Option 67 (Boot File)**:
- BIOS: `undionly.kpxe`
- UEFI: `ipxe.efi`

### 4. Test Client Connectivity

1. **Test web interface**: `http://your-new-fog-server-ip/fog`
2. **Test PXE boot**: Boot a client machine
3. **Test image operations**: Capture or deploy an image

### 5. Update Client Registrations

If your FOG server IP changed, you may need to:
1. **Re-register existing clients** via PXE boot
2. **Update client configurations** if they have hardcoded IPs
3. **Verify client communication** with the new server

## Troubleshooting Migration

### Common Issues

#### Migration Not Starting

**Symptoms**: Container starts but no migration occurs
**Solutions**:
1. **Check migration is enabled**:
   ```bash
   grep FOG_DB_MIGRATION_ENABLED .env
   ```

2. **Verify dump file is mounted**:
   ```bash
   docker exec fog-server ls -la /opt/migration/
   ```

3. **Check file permissions**:
   ```bash
   ls -la FOG_MIGRATION_DUMP.sql
   ```

#### Database Already Exists Error

**Symptoms**: Migration skipped due to existing database
**Solutions**:
1. **Use force migration**:
   ```bash
   FOG_DB_MIGRATION_FORCE=true
   ```

2. **Or remove existing database**:
   ```bash
   docker compose down
   docker volume rm fog-docker_fog-db-data
   docker compose up -d
   ```

#### Import Errors

**Symptoms**: Database import fails with errors
**Solutions**:
1. **Check dump file integrity**:
   ```bash
   head -20 FOG_MIGRATION_DUMP.sql
   tail -20 FOG_MIGRATION_DUMP.sql
   ```

2. **Verify MySQL compatibility**:
   ```bash
   # Check FOG version compatibility
   grep "FOG" FOG_MIGRATION_DUMP.sql | head -5
   ```

3. **Check container logs**:
   ```bash
   docker compose logs fog-server | grep -i error
   ```

### Debug Commands

```bash
# Check migration status
docker exec fog-server ls -la /opt/migration/

# Check database contents
docker exec fog-server mysql -u root -p$FOG_DB_ROOT_PASSWORD -e "USE fog; SHOW TABLES;"

# Check FOG configuration
docker exec fog-server cat /opt/fog/config/fog.config

# Check container logs
docker compose logs fog-server
```

## Migration Best Practices

### Before Migration

1. **Backup your existing FOG server** completely
2. **Document your current FOG configuration**
3. **Test FOG Docker in a lab environment** first
4. **Plan for network changes** (IP addresses, DNS, etc.)

### During Migration

1. **Use a maintenance window** for the migration
2. **Monitor the migration process** closely
3. **Keep the original FOG server running** until migration is verified
4. **Test all functionality** before decommissioning the old server

### After Migration

1. **Verify all hosts are accessible** in the new system
2. **Test image capture and deployment**
3. **Update documentation** with new server details
4. **Monitor system performance** for any issues

## Rollback Plan

If migration fails or issues arise:

1. **Stop FOG Docker**:
   ```bash
   docker compose down
   ```

2. **Restore original FOG server** from backup

3. **Update DHCP** to point back to original server

4. **Investigate and fix issues** before retrying migration

## Advanced Migration Scenarios

### Large Database Migration

For large FOG installations:

```bash
# Compress the dump file
gzip FOG_MIGRATION_DUMP.sql

# Update docker-compose.yml to mount compressed file
volumes:
  - ./FOG_MIGRATION_DUMP.sql.gz:/opt/migration/FOG_MIGRATION_DUMP.sql.gz:ro
```

### Multi-Server FOG Migration

If migrating from a distributed FOG setup:

1. **Export from master server** only
2. **Update storage node configurations** in FOG Docker
3. **Migrate image files** separately if needed
4. **Update client configurations** for new server locations

## Next Steps

After successful migration:

1. **[Configuration Guide](configuration.md)** - Optimize FOG Docker configuration
2. **[Network Boot Setup](network-boot.md)** - Verify PXE and HTTPBoot configuration
3. **[Troubleshooting Guide](troubleshooting.md)** - Address any post-migration issues

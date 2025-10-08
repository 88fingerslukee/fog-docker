---
layout: default
title: External Database
nav_order: 8
description: "Use external MySQL/MariaDB with FOG Docker"
permalink: /external-database
---

# External Database Setup

This guide covers using an external MySQL/MariaDB database with FOG Docker instead of the built-in database container.

## Overview

Using an external database provides:
- **Centralized database management**
- **Better performance** for large installations
- **Easier backup and maintenance**
- **Integration with existing database infrastructure**

## Prerequisites

- External MySQL/MariaDB server
- Database server accessible from FOG Docker host
- Appropriate database permissions
- Network connectivity between FOG Docker and database server

## Database Server Setup

### Create Database and User

On your external database server:

```sql
-- Create the FOG database
CREATE DATABASE fog CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Create FOG user
CREATE USER 'fogmaster'@'%' IDENTIFIED BY 'your-secure-password';

-- Grant permissions
GRANT ALL PRIVILEGES ON fog.* TO 'fogmaster'@'%';

-- Grant additional permissions for FOG operations
GRANT CREATE, DROP, ALTER, INDEX, LOCK TABLES ON fog.* TO 'fogmaster'@'%';

-- Flush privileges
FLUSH PRIVILEGES;
```

### Verify Database Setup

```sql
-- Test the connection
SHOW DATABASES;
USE fog;
SHOW TABLES;

-- Check user permissions
SHOW GRANTS FOR 'fogmaster'@'%';
```

## FOG Docker Configuration

### 1. Update Environment Variables

Edit your `.env` file:

```bash
# External Database Configuration
FOG_DB_HOST=your-db-server-ip-or-hostname
FOG_DB_PORT=3306
FOG_DB_NAME=fog
FOG_DB_USER=fogmaster
FOG_DB_PASS=your-secure-password

# Keep the root password for initial setup (can be removed later)
FOG_DB_ROOT_PASSWORD=your-db-root-password

# Optional: Database Migration Configuration
FOG_DB_MIGRATION_ENABLED=false
FOG_DB_MIGRATION_FORCE=false
```

### 2. Modify Docker Compose

Update your `docker-compose.yml` to remove the database service:

```yaml
services:
  fog-server:
    image: ghcr.io/88fingerslukee/fog-docker:latest
    environment:
      - FOG_DB_HOST=${FOG_DB_HOST}
      - FOG_DB_PORT=${FOG_DB_PORT}
      - FOG_DB_NAME=${FOG_DB_NAME}
      - FOG_DB_USER=${FOG_DB_USER}
      - FOG_DB_PASS=${FOG_DB_PASS}
      - FOG_DB_ROOT_PASSWORD=${FOG_DB_ROOT_PASSWORD}
    # Remove depends_on: fog-db
    # ... other configuration

  # Comment out or remove the entire fog-db service:
  # fog-db:
  #   image: mariadb:10.11
  #   environment:
  #     - MYSQL_ROOT_PASSWORD=${FOG_DB_ROOT_PASSWORD}
  #     - MYSQL_DATABASE=${FOG_DB_NAME}
  #     - MYSQL_USER=${FOG_DB_USER}
  #     - MYSQL_PASSWORD=${FOG_DB_PASS}
  #   volumes:
  #     - fog-db-data:/var/lib/mysql
  #   healthcheck:
  #     test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
  #     timeout: 20s
  #     retries: 10

# Remove the fog-db-data volume:
# volumes:
#   fog-db-data:
```

**Required .env variables:**
```bash
FOG_DB_HOST=your-db-server-ip-or-hostname
FOG_DB_PORT=3306
FOG_DB_NAME=fog
FOG_DB_USER=fogmaster
FOG_DB_PASS=your-secure-password
FOG_DB_ROOT_PASSWORD=your-db-root-password
```

### 3. Start FOG Server Only

```bash
# Start only the FOG server (no database container)
docker compose up -d fog-server

# Check if FOG server starts successfully
docker compose logs -f fog-server
```

## Database Connection Testing

### Test Connectivity

```bash
# Test database connectivity from FOG container
docker exec -it fog-server mysql -h your-db-host -u fogmaster -p

# Test with connection parameters
docker exec -it fog-server mysql -h your-db-host -P 3306 -u fogmaster -p$FOG_DB_PASS fog
```

### Test Network Connectivity

```bash
# Test if database port is accessible
docker exec -it fog-server telnet your-db-host 3306

# Test DNS resolution
docker exec -it fog-server nslookup your-db-host
```

## Database Migration

### From Built-in Database

If you're migrating from the built-in database:

1. **Export from built-in database**:
   ```bash
   # Start with built-in database first
   docker compose up -d
   
   # Export the database
   docker exec fog-db mysqldump --single-transaction --routines --triggers --databases fog > fog-export.sql
   
   # Copy the export file
   docker cp fog-server:/tmp/fog-export.sql ./fog-export.sql
   ```

2. **Import to external database**:
   ```bash
   # Import to external database
   mysql -h your-db-host -u root -p < fog-export.sql
   ```

3. **Update FOG Docker configuration** and restart

### From Existing FOG Installation

If migrating from an existing FOG installation:

1. **Export from existing FOG**:
   ```bash
   mysqldump --single-transaction --routines --triggers --databases fog > fog-migration.sql
   ```

2. **Import to external database**:
   ```bash
   mysql -h your-db-host -u root -p < fog-migration.sql
   ```

## Security Considerations

### Database Security

1. **Use strong passwords** for database users
2. **Limit database user permissions** to only what's needed
3. **Use SSL/TLS** for database connections if possible
4. **Restrict network access** to database server

### Network Security

1. **Use firewall rules** to restrict database access
2. **Consider VPN** for remote database access
3. **Use private networks** when possible
4. **Monitor database connections**

### Example Secure Configuration

```sql
-- Create user with limited permissions
CREATE USER 'fogmaster'@'fog-docker-host-ip' IDENTIFIED BY 'strong-password';

-- Grant only necessary permissions
GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, ALTER, INDEX, LOCK TABLES ON fog.* TO 'fogmaster'@'fog-docker-host-ip';

-- Remove wildcard access
DROP USER 'fogmaster'@'%';
```

## Performance Optimization

### Database Configuration

For better performance with external databases:

```sql
-- Optimize MySQL/MariaDB settings
SET GLOBAL innodb_buffer_pool_size = 1G;
SET GLOBAL max_connections = 200;
SET GLOBAL query_cache_size = 64M;
```

### Connection Pooling

Consider using connection pooling for high-traffic environments:

```yaml
# In docker-compose.yml
services:
  fog-server:
    environment:
      - FOG_DB_POOL_SIZE=10
      - FOG_DB_POOL_TIMEOUT=30
```

## Troubleshooting

### Connection Issues

**Symptoms**: FOG server can't connect to database
**Solutions**:
1. **Check database server status**:
   ```bash
   systemctl status mysql
   # or
   systemctl status mariadb
   ```

2. **Verify network connectivity**:
   ```bash
   ping your-db-host
   telnet your-db-host 3306
   ```

3. **Check firewall rules**:
   ```bash
   iptables -L | grep 3306
   ufw status | grep 3306
   ```

### Permission Issues

**Symptoms**: Database connection works but operations fail
**Solutions**:
1. **Check user permissions**:
   ```sql
   SHOW GRANTS FOR 'fogmaster'@'%';
   ```

2. **Verify database exists**:
   ```sql
   SHOW DATABASES;
   USE fog;
   ```

3. **Test with root user**:
   ```bash
   docker exec -it fog-server mysql -h your-db-host -u root -p
   ```

### Performance Issues

**Symptoms**: Slow database operations
**Solutions**:
1. **Check database performance**:
   ```sql
   SHOW PROCESSLIST;
   SHOW STATUS LIKE 'Slow_queries';
   ```

2. **Optimize database configuration**
3. **Check network latency**:
   ```bash
   ping your-db-host
   ```

## Monitoring and Maintenance

### Database Monitoring

```sql
-- Check database status
SHOW STATUS;

-- Monitor connections
SHOW PROCESSLIST;

-- Check slow queries
SHOW STATUS LIKE 'Slow_queries';
```

### Backup Strategy

```bash
# Regular database backups
mysqldump --single-transaction --routines --triggers --databases fog > fog-backup-$(date +%Y%m%d).sql

# Compressed backups
mysqldump --single-transaction --routines --triggers --databases fog | gzip > fog-backup-$(date +%Y%m%d).sql.gz
```

### Log Monitoring

```bash
# Monitor FOG database logs
docker compose logs -f fog-server | grep -i database

# Monitor database server logs
tail -f /var/log/mysql/error.log
```

## High Availability

### Database Replication

For high availability, consider setting up database replication:

1. **Master-Slave replication**
2. **Master-Master replication**
3. **Galera cluster** (for MariaDB)

### Load Balancing

For multiple FOG servers:

1. **Database connection pooling**
2. **Read replicas** for reporting
3. **Load balancer** for FOG servers

## Next Steps

After setting up external database:

1. **[Configuration Guide](configuration.md)** - Optimize FOG configuration
2. **[Migration Guide](migration-bare-metal.md)** - Migrate existing data
3. **[Troubleshooting Guide](troubleshooting.md)** - Address any issues

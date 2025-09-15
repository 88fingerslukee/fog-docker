# FOG Installation Analysis

## Overview

This document provides a comprehensive analysis of the FOG installation process (`installfog.sh`) and all its sub-functions. The goal is to understand every step, variable, and requirement needed to achieve true statelessness in a Docker container.

## Installation Flow Analysis

### Phase 1: Pre-Installation Setup

#### 1.1 Environment Validation
- **Function**: Direct script validation
- **Requirements**:
  - Must run as root user (`$EUID -eq 0`)
  - Must be Linux OS (`uname -s`)
  - Must have proper PATH with sbin directories
  - Must have `useradd` command available

#### 1.2 Version Detection
- **Function**: Direct script logic
- **Variables**:
  - `$version`: Extracted from `../packages/web/lib/fog/system.class.php`
  - `$error_log`: `${workingdir}/error_logs/fog_error_${version}.log`

#### 1.3 Configuration Loading
- **Function**: Sources `../lib/common/functions.sh` and `../lib/common/config.sh`
- **Critical Variables Initialized** (with defaults):
  - `$dnsaddress=""` - DNS server address
  - `$username=""` - FOG system username
  - `$password=""` - FOG system password
  - `$osid=""` - Operating system ID
  - `$osname=""` - Operating system name
  - `$dodhcp=""` - DHCP configuration flag
  - `$installtype=""` - Installation type (Normal/Storage)
  - `$interface=""` - Network interface
  - `$ipaddress=""` - Server IP address
  - `$hostname=""` - Server hostname
  - `$routeraddress=""` - Router/gateway address
  - `$httpproto="http"` - HTTP protocol (http/https)
  - `$mysqldbname="fog"` - MySQL database name

### Phase 2: OS Detection and Package Installation

#### 2.1 OS Detection
- **Function**: `doOSSpecificIncludes()`
- **Process**:
  - Detects Linux distribution using `/etc/os-release`
  - Sets `$osid` (1=RedHat/CentOS, 2=Debian/Ubuntu, 3=Arch)
  - Sets `$osname` (distribution name)
  - Installs `lsb-release` package if needed

#### 2.2 Package Installation
- **Function**: `installPackages()` (called from OS-specific includes)
- **Debian/Ubuntu Packages**:
  - `apache2`, `bc`, `build-essential`, `cpp`, `curl`, `g++`
  - `gawk`, `gcc`, `git`, `htmldoc`, `isc-dhcp-server`
  - `isolinux`, `lftp`, `libapache2-mod-php`, `libc6-dev`
  - `libcurl4-openssl-dev`, `liblzma-dev`, `m4`, `mysql-client`
  - `mysql-server`, `net-tools`, `nfs-kernel-server`, `openssh-server`
  - `php`, `php-bcmath`, `php-cli`, `php-curl`, `php-fpm`
  - `php-gd`, `php-gettext`, `php-json`, `php-ldap`
  - `php-mysql`, `php-mysqlnd`, `sysv-rc-conf`, `tar`
  - `tftpd-hpa`, `tftp-hpa`, `unzip`, `vsftpd`, `wget`, `xinetd`

### Phase 3: User Configuration

#### 3.1 User Creation/Validation
- **Function**: `configureUsers()`
- **Variables Required**:
  - `$username` - FOG system user (default: `fog`)
  - `$password` - FOG system password (default: `password`)
- **Process**:
  - Creates system user if doesn't exist
  - Sets password for user
  - Creates home directory
  - Sets proper shell

### Phase 4: Network Configuration

#### 4.1 Network Interface Detection
- **Function**: Direct installer logic
- **Variables Required**:
  - `$interface` - Network interface name (e.g., `eth0`)
  - `$ipaddress` - Server IP address
  - `$hostname` - Server hostname
  - `$routeraddress` - Gateway IP address

### Phase 5: Installation Type Selection

#### 5.1 Installation Type
- **Options**:
  - **Normal Installation** (`[Nn]`): Full FOG server
  - **Storage Installation** (`[Ss]`): Storage node only
- **Variable**: `$installtype`

## Normal Installation Process (Full FOG Server)

### Step 1: MySQL Database Setup
- **Function**: `configureMySql()`
- **Variables Required**:
  - `$mysqldbname` - Database name (default: `fog`)
  - `$snmysqluser` - MySQL user (default: `root`)
  - `$snmysqlpass` - MySQL root password
  - `$snmysqlstoragepass` - Storage node MySQL password
- **Process**:
  1. Stops any running MySQL service
  2. Configures MySQL networking (disables skip-networking, bind-address)
  3. Initializes MySQL data directory if needed
  4. Starts MySQL service
  5. Sets root password if not set
  6. Creates FOG database and users

### Step 2: Web Server Configuration
- **Function**: `configureHttpd()`
- **Variables Required**:
  - `$docroot` - Apache document root (default: `/var/www/html`)
  - `$webroot` - FOG web root path (default: `/fog`)
  - `$httpproto` - Protocol (http/https)
  - `$sslpath` - SSL certificate path (default: `/opt/fog/snapins/ssl`)
- **Process**:
  1. Stops Apache and PHP-FPM services
  2. Configures PHP settings (`php.ini`)
  3. Creates Apache virtual host configuration
  4. Enables required Apache modules (rewrite, ssl, headers)
  5. Configures SSL if HTTPS enabled
  6. Copies FOG web files to document root
  7. Sets proper file permissions

### Step 3: Database Schema Creation
- **Function**: `updateDB()`
- **Variables Required**:
  - `$storageLocation` - Storage directory path (default: `/images`)
  - `$webdirdest` - Web directory destination
  - All database connection variables
- **Process**:
  1. Updates storage location in schema file
  2. Calls FOG web interface to create database schema
  3. Handles database upgrades and migrations

### Step 4: Storage Configuration
- **Function**: `configureStorage()`
- **Variables Required**:
  - `$storageLocation` - Main storage path (default: `/images`)
  - `$storageLocationCapture` - Capture storage path (default: `/images/dev`)
- **Process**:
  1. Creates storage directories
  2. Creates mount check files (`.mntcheck`)
  3. Creates post-download scripts directory
  4. Creates post-init scripts directory
  5. Sets up default script templates

### Step 5: DHCP Configuration
- **Function**: `configureDHCP()`
- **Variables Required**:
  - `$dodhcp` - Enable DHCP server (Y/N)
  - `$startrange` - DHCP start IP range
  - `$endrange` - DHCP end IP range
  - `$bootfilename` - PXE boot filename (default: `undionly.kpxe`)
  - `$dnsaddress` - DNS server address
- **Process**:
  1. Configures ISC DHCP server
  2. Sets up PXE boot options
  3. Configures DHCP ranges and options

### Step 6: TFTP and PXE Configuration
- **Function**: `configureTFTPandPXE()`
- **Variables Required**:
  - `$tftpdirdst` - TFTP destination directory (default: `/tftpboot`)
  - `$tftpdirsrc` - TFTP source directory
  - `$httpproto` - Protocol for iPXE compilation
  - `$sslpath` - SSL path for HTTPS iPXE
- **Process**:
  1. **CRITICAL**: Compiles iPXE binaries if HTTPS enabled
  2. Copies TFTP files from source to destination
  3. Sets proper file permissions and ownership
  4. Configures TFTP server (systemd or xinetd)
  5. Creates default iPXE configuration files

### Step 7: FTP Configuration
- **Function**: `configureFTP()`
- **Variables Required**:
  - `$username` - FTP username
  - `$password` - FTP password
  - `$storageLocation` - FTP root directory
- **Process**:
  1. Configures vsftpd server
  2. Sets up user access and chroot
  3. Configures passive mode ports

### Step 8: Snapins Configuration
- **Function**: `configureSnapins()`
- **Variables Required**:
  - `$snapindir` - Snapins directory (default: `/opt/fog/snapins`)
- **Process**:
  1. Creates snapins directory
  2. Sets proper permissions
  3. Configures web access to snapins

### Step 9: Multicast Configuration
- **Function**: `configureUDPCast()`
- **Variables Required**:
  - `$interface` - Network interface for multicast
- **Process**:
  1. Configures UDPCast for multicast imaging
  2. Sets up multicast interface binding

### Step 10: FOG Services Installation
- **Function**: `installFOGServices()`
- **Process**:
  1. Copies FOG service binaries
  2. Creates systemd service files
  3. Enables and starts FOG services

### Step 11: NFS Configuration
- **Function**: `configureNFS()`
- **Variables Required**:
  - `$storageLocation` - NFS export path
  - `$storageLocationCapture` - Capture export path
- **Process**:
  1. Configures NFS exports
  2. Sets up NFS server
  3. Starts NFS services

## Storage Installation Process (Storage Node)

### Storage Node Specific Steps
- **Function**: Storage node installation (`[Ss]`)
- **Additional Variables**:
  - `$snmysqlhost` - Master server hostname
  - `$maxClients` - Maximum concurrent clients
- **Process**:
  1. Connects to master database
  2. Configures minimal HTTP server
  3. Registers node with master server
  4. Configures storage, TFTP, FTP, NFS
  5. No database schema creation (uses master)

## Critical Variables Summary

### Required Environment Variables
- `$username` - System username (default: `fog`)
- `$password` - System password (default: `password`)
- `$ipaddress` - Server IP address **[REQUIRED]**
- `$interface` - Network interface **[REQUIRED]**
- `$storageLocation` - Storage path (default: `/images`)
- `$mysqldbname` - Database name (default: `fog`)
- `$snmysqlpass` - MySQL root password **[REQUIRED]**

### Optional Configuration Variables
- `$hostname` - Server hostname
- `$routeraddress` - Gateway IP
- `$dnsaddress` - DNS server
- `$httpproto` - Protocol (http/https)
- `$webroot` - Web root path (default: `/fog`)
- `$docroot` - Document root (default: `/var/www/html`)
- `$sslpath` - SSL certificate path
- `$dodhcp` - Enable DHCP (Y/N)
- `$startrange` - DHCP start range
- `$endrange` - DHCP end range
- `$bootfilename` - PXE boot file

## Statelessness Analysis

### Build-Time Operations (Can be pre-built)
1. **Package Installation**: All system packages can be installed in Docker image
2. **User Creation**: System users can be created at build time
3. **Directory Structure**: All directories can be created at build time
4. **File Copying**: Web files, TFTP files, binaries can be copied at build time
5. **Service Installation**: FOG services can be installed at build time
6. **iPXE Compilation**: Can be done at build time with generic SSL support

### Runtime Operations (Must be configured at runtime)
1. **Database Connection**: Requires runtime database host/credentials
2. **Network Configuration**: Requires runtime IP/interface detection
3. **SSL Certificates**: May need runtime generation for specific hostnames
4. **Database Schema**: Requires runtime database initialization
5. **Configuration Files**: Apache, PHP, DHCP configs need runtime values
6. **Service Configuration**: Some services need runtime network parameters

### Key Insight for Statelessness
The main blocker is that FOG's installation process assumes it can:
1. Modify system configuration files at runtime
2. Create and initialize database schema via web interface
3. Generate SSL certificates for specific hostnames
4. Detect and configure network interfaces dynamically

**For true statelessness, we need to:**
1. Pre-build all possible components
2. Use environment variables for all runtime configuration
3. Template all configuration files
4. Handle database schema initialization separately (init container or external)
5. Use generic SSL certificates or external certificate management

## Conclusion

FOG's installation is complex with many interdependent steps. True statelessness requires careful separation of build-time vs runtime operations, with most system-level configuration moved to build time and only network/database parameters configured at runtime.

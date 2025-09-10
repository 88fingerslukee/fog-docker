# FOG Project Containerization Improvements

This document outlines the necessary changes to FOG's source code to enable proper containerization without the current workarounds.

## 🎯 Goal

Enable FOG to run as a truly containerized application with:
- **Container Networking**: Services communicate via Docker service names
- **Stateless**: Minimal runtime configuration dependencies  
- **Portable**: Works across different environments without modification
- **Scalable**: Support for microservices architecture

## 🔧 Required Changes

FOG has two fundamental architectural issues that prevent proper containerization:

### 1. **IP Matching Logic Doesn't Work in Containers**

#### **Current Problem:**
FOG services use `getIPAddress()` to auto-detect if they're the master storage node by comparing their IP addresses against storage node IPs in the database. In containers, this IP matching fails because the container's view of IPs doesn't match the storage node configuration.

#### **Current Implementation:**
```php
// From /opt/fog/packages/web/lib/service/fogservice.class.php
protected function checkIfNodeMaster()
{
    self::getIPAddress();  // Gets container's IP addresses
    // Compares against storage node IPs in database
    // FAILS in containers because IPs don't match
}
```

#### **Needed Changes:**
- Services need explicit role configuration instead of IP auto-detection
- Or IP matching logic needs to be container-aware
- Or services need to be able to identify their role without IP matching

### 2. **Inability to Make it Stateless**

#### **Current Problem:**
FOG's install script generates configuration files at installation time with hardcoded values. There's no support for environment variables in the core configuration system, and database settings must be updated at runtime.

#### **Current Implementation:**
```php
// Static defines generated at install time (CANNOT be changed at runtime)
// Generated in /opt/fog/lib/common/functions.sh line 2273-2388
define('TFTP_HOST', "${ipaddress}");
define('STORAGE_HOST', "${ipaddress}");
define('WEB_HOST', "${ipaddress}");
define('DATABASE_HOST', '$snmysqlhost');  // This becomes 'localhost' and stays that way

// Database settings (CAN be updated at runtime but require DB access)
UPDATE globalSettings SET settingValue = '$FOG_WEB_HOST' WHERE settingKey = 'FOG_WEB_HOST';
UPDATE globalSettings SET settingValue = '$FOG_TFTP_HOST' WHERE settingKey = 'FOG_TFTP_HOST';
```

#### **Needed Changes:**
- Support environment variables in static defines
- Separate configuration from persistent data
- Eliminate runtime database updates for configuration
- Enable creation of static, stateless images

## 🛠️ Implementation Strategy

### **Phase 1: Configuration Management**
1. **Add Environment Variable Support**
   ```php
   // Support environment variables with fallbacks
   define('TFTP_HOST', $_ENV['FOG_TFTP_HOST'] ?? 'localhost');
   define('STORAGE_HOST', $_ENV['FOG_STORAGE_HOST'] ?? 'localhost');
   define('WEB_HOST', $_ENV['FOG_WEB_HOST'] ?? 'localhost');
   define('DATABASE_HOST', $_ENV['FOG_DB_HOST'] ?? 'localhost');
   ```

2. **Separate Configuration from Data**
   - Move runtime settings to configuration files
   - Keep only persistent data in database
   - Use configuration hierarchy: env vars → config files → defaults

### **Phase 2: Service Discovery**
1. **Replace IP Matching with Explicit Configuration**
   ```php
   // Instead of auto-detection, use explicit role configuration
   define('FOG_NODE_ROLE', $_ENV['FOG_NODE_ROLE'] ?? 'master');
   define('FOG_NODE_ID', $_ENV['FOG_NODE_ID'] ?? 'default');
   ```

2. **Support Container Networking**
   ```php
   // Use Docker service names for communication
   define('DB_HOST', $_ENV['FOG_DB_HOST'] ?? 'fog-db');
   define('DB_PORT', $_ENV['FOG_DB_PORT'] ?? 3306);
   ```

### **Phase 3: Port Configuration & Web Server Agnostic**
1. **Dynamic Port Configuration**
   - Make HTTP/HTTPS ports configurable (80/443 can be changed)
   - Make database ports configurable (3306 can be changed)

2. **Remove Apache Dependency**
   - Abstract web server configuration
   - Support multiple web servers (nginx, Caddy, etc.)
   - Use standard PHP-FPM or similar interfaces

3. **Container-Native Features**
   - Health checks and monitoring endpoints
   - Structured logging (JSON format)
   - Graceful shutdown procedures

## 📁 Files That Need Changes

### **Configuration Generation**
- `/opt/fog/lib/common/functions.sh` (lines 2273-2388) - Configuration generation
- `/opt/fog/bin/installfog.sh` - Installation script

### **Service Classes**
- `/opt/fog/packages/web/lib/service/fogservice.class.php` - IP matching logic
- `/opt/fog/packages/web/lib/fog/fogbase.class.php` - `getIPAddress()` function

### **Web Server Configuration**
- Apache-specific configuration files and modules
- Web server abstraction layer needed

### **Database Schema**
- `/opt/fog/packages/web/commons/schema.php` - Remove runtime config from database
- Create separate configuration files for runtime settings

## 🚀 Benefits

Once implemented, FOG would support:
- **True Container Networking**: Services communicate via Docker service names
- **Stateless Images**: No runtime configuration generation required
- **Environment Portability**: Same image works across different environments
- **Microservices Architecture**: Services can be scaled independently
- **Cloud Deployment**: Compatible with Kubernetes, Docker Swarm, etc.

## 📋 Migration Path

1. **Backward Compatibility**: Maintain support for current installation method
2. **Gradual Migration**: Add environment variable support alongside existing config
3. **Container-First**: New installations default to container-friendly configuration
4. **Documentation**: Update installation guides for container deployment

---

*This document serves as a roadmap for FOG Project maintainers to implement proper containerization support.*
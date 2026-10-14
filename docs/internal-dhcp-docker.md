---
layout: default
title: Internal DHCP in Docker
nav_order: 10
description: "Run FOG's built-in DHCP server (isc-dhcp-server) with Docker networking"
permalink: /internal-dhcp-docker
---

# Internal DHCP in Docker

Use this guide when **`FOG_DHCP_ENABLED=true`** and FOG should be the **only DHCP server** on a LAN (standalone lab, isolated imaging network, etc.).

For **existing DHCP servers** (options 66/67 only), see [DHCP Integration](dhcp-integration.md).

## Why default Compose is not enough

FOG's DHCP server (`isc-dhcp-server`) inside the container must receive **broadcast** DHCP DISCOVER packets from clients on your LAN.

Default **`docker-compose.yml`** puts `fog-server` on a **bridge network**. Broadcasts from physical clients stay on the LAN segment and **do not reach** the container. Enabling `FOG_DHCP_ENABLED` and tuning `FOG_DHCP_*` variables does not fix that by itself. Use **host networking** on `fog-server` (below) or another approach that puts DHCP on the same L2 segment as clients (e.g. macvlan).

## Recommended: host network on `fog-server`

Edit **`docker-compose.yml`** (or **`docker-compose-dev.yml`** for local builds). Commented blocks are already in the file — uncomment/adjust as below so **`fog-server` uses the host network stack**. MariaDB stays on the bridge with **MySQL published on localhost**.

### Steps

1. **`fog-db`:** Uncomment the **`ports`** block under “Internal DHCP” so MariaDB is on **`127.0.0.1:3306`**.

2. **`fog-server`:**
   - Uncomment **`network_mode: host`**
   - Comment out the entire **`ports:`** section (ignored in host mode, but avoids confusion)
   - Comment out **`networks:`** (cannot combine bridge networks with host mode)

3. In **`.env`**, set at minimum:

   ```bash
   FOG_WEB_HOST=192.168.1.100          # Your host's LAN IP (not a Docker bridge IP)
   FOG_STORAGE_HOST=192.168.1.100
   FOG_TFTP_HOST=192.168.1.100
   FOG_WOL_HOST=192.168.1.100
   FOG_MULTICAST_INTERFACE=eth0        # Replace with your PXE/LAN interface name

   FOG_DHCP_ENABLED=true
   FOG_DHCP_SUBNET=192.168.1.0
   FOG_DHCP_NETMASK=255.255.255.0
   FOG_DHCP_ROUTER=192.168.1.1
   FOG_DHCP_START_RANGE=192.168.1.100
   FOG_DHCP_END_RANGE=192.168.1.200

   FOG_DB_HOST=127.0.0.1
   ```

   Adjust subnet, ranges, and interface for your lab network.

4. Recreate the stack:

   ```bash
   docker compose up -d
   ```

   Development:

   ```bash
   docker compose -f docker-compose-dev.yml up -d --build
   ```

5. Confirm DHCP is running:

   ```bash
   docker exec fog-server supervisorctl status isc-dhcp-server
   docker exec fog-server tail -20 /opt/fog/log/dhcpd.log
   ```

### How it works

| Service     | Network        | Database access |
|------------|----------------|-----------------|
| `fog-db`   | Bridge (default) | MariaDB listens in container; **127.0.0.1:3306** published on host |
| `fog-server` | **`network_mode: host`** | Connects to **`127.0.0.1:3306`** via `FOG_DB_HOST` |

With host mode, TFTP, DHCP, NFS, and multicast use the **host interfaces** directly. You do **not** need the published `ports:` list on `fog-server` for those services.

## Alternative: macvlan / ipvlan

Give the container a **real LAN IP** on the same segment as clients while keeping bridge isolation for other services. Requires custom network definitions and static IP planning. Useful when you cannot use host mode but need L2 visibility.

## Prerequisites and warnings

- **Only one DHCP server** per broadcast domain. Disable router DHCP and any other `dnsmasq`/`dhcpd` on the host before testing.
- **Host port conflicts:** With `network_mode: host`, Apache binds host **80/443** (or your `FOG_APACHE_*` ports). Stop other web servers or change FOG Apache ports in `.env`.
- **`FOG_TFTP_HOST` / `next-server`** in generated `dhcpd.conf` must be the **LAN IP clients can reach**, not `172.x.x.x` Docker addresses.
- **Firewall:** Allow DHCP, TFTP, and the NFS/FTP ports you use on the LAN interface.

## Troubleshooting

| Symptom | Likely cause |
|--------|----------------|
| No DHCP offers on clients | Still on bridge-only compose; or another DHCP server winning; or wrong interface/subnet |
| `Waiting for database server` with host mode | `FOG_DB_HOST` not `127.0.0.1`, or `fog-db` ports not published, or wrong password |
| PXE gets IP but TFTP fails | `FOG_TFTP_HOST` wrong; firewall on UDP 69; empty `/tftpboot` mount — see [Troubleshooting](troubleshooting.md) |
| `no address range available for DHCP request via …` | Request arrived on an interface that does not match `FOG_DHCP_SUBNET` in `dhcpd.conf` (common on multi-NIC hosts if DHCP listens on `docker0` or the wrong NIC) |

## Related

- [Configuration — Scenario 4: FOG as DHCP Server](configuration.md#scenario-4-fog-as-dhcp-server)
- [Network Boot](network-boot.md)
- [Environment variables — DHCP](environment-variables.md#dhcp-configuration)

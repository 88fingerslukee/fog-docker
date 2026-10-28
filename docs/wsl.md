---
layout: default
title: Windows (WSL2)
nav_order: 3
description: "Run fog-docker on Windows Subsystem for Linux for lab and UI testing"
permalink: /wsl
---

# FOG Docker on Windows (WSL2)

You can run fog-docker on **Windows** using **WSL2** and **Docker** (Docker Desktop with WSL integration, or Docker Engine inside an Ubuntu-on-WSL distro). This is useful for **lab testing**, **FOG Agent** trials, and learning the UI — **full PXE/imaging across your LAN is much harder on WSL** than on a Linux server or VM.

## How WSL differs from a Linux server

On a normal Linux host, clients reach FOG on one IP and published ports **80** / **443**. On WSL2, traffic goes:

```text
Windows browser  →  Windows networking  →  WSL2 VM  →  Docker  →  fog-server
```

Use an address and ports that work **from Windows** (where you open the browser), not only from inside WSL.

## Prerequisites

- **Windows 11** or **Windows 10** with WSL2 enabled
- **Docker** (Docker Desktop recommended for simpler port forwarding to Windows, or Docker in your WSL distro)
- Enough RAM/disk for FOG (see [Installation](installation.md))

### Optional: mirrored networking (WSL 2.0+)

Some setups use mirrored mode so WSL shares the host network more closely. Example `%UserProfile%\.wslconfig`:

```ini
[wsl2]
networkingMode=mirrored
dnsTunneling=true

[experimental]
hostAddressLoopback=true
```

After editing, run **`wsl --shutdown`** from Windows, then reopen your distro. Mirrored mode is optional; you still must publish Docker ports and set **`FOG_WEB_HOST`** to a name/IP clients (and your browser) can use.

## Install fog-docker in WSL

1. Open your **WSL** terminal (e.g. Ubuntu).
2. Follow the [Quick Installation](installation.md#quick-installation) steps (`docker-compose.yml`, `.env`, `docker compose up -d`).
3. Use a recent image tag (e.g. **`ghcr.io/88fingerslukee/fog-docker:rc`** for FOG 1.6 RC) — see [Available Image Tags](installation.md#available-image-tags).

## Recommended `.env` for WSL lab (standard TLS)

```bash
FOG_WEB_HOST=192.168.x.x          # IP or hostname you use from Windows in the browser
FOG_DB_ROOT_PASSWORD=your-password
FOG_TLS_MODE=standard

# If you enroll FOG Agent or use short names / LAN IP — see ssl-https.md
FOG_CERT_SAN=fogproject,192.168.x.x
```

Set **`FOG_WEB_HOST`** to the same host/IP you type in the browser (not `127.0.0.1` unless you always browse that way from Windows).

## Web UI: HTTP vs HTTPS

With **`FOG_TLS_MODE=standard`**, the **management UI is HTTPS** (port **443** inside the container). Map **both** HTTP and HTTPS in compose (defaults **80** and **443** unless you change `FOG_APACHE_EXPOSED_PORT` / `FOG_APACHE_EXPOSED_SSL_PORT`).

- Open **`https://<FOG_WEB_HOST>/fog/management/`** from **Windows** (accept the self-signed certificate warning on first visit).
- **`http://…`** may work for some paths, but that is not the intended UI mode for `standard`.

Confirm published ports:

```bash
docker ps --filter name=fog-server
```

You should see mappings for **80** and **443** (or your custom host ports).

### Edge/Chrome: `ERR_SSL_KEY_USAGE_INCOMPATIBLE`

If HTTPS fails with **`ERR_SSL_KEY_USAGE_INCOMPATIBLE`**, the container’s **self-signed Apache certificate** was generated with Key Usage that older templates did not set correctly for TLS 1.3. **Pull a current fog-docker image** (includes **`digitalSignature`** on managed `server.crt`) and **recreate** the container so **`server.crt`** regenerates. See [SSL/HTTPS — self-signed](ssl-https.md#self-signed-default).

## FOG Agent on WSL

- Use **`FOG_CERT_SAN`** for any extra names/IPs agents use to enroll ([SSL/HTTPS — FOG Client certificates](ssl-https.md#fog-client-certificates)).
- Enroll with the **same scheme and hostname** as **`FOG_WEB_HOST`** (`https://…` for `standard`).
- Trust files: **`srvpublic.crt`** and CA under `/fog/management/other/` — see [Troubleshooting — FOG Agent](troubleshooting.md#fog-agent-enrollment--certificate-name-errors).

## PXE and imaging limitations

WSL is **not** a drop-in replacement for a dedicated imaging server:

- **Broadcast DHCP**, **TFTP**, and **NFS** to other machines on the LAN are often **problematic** (NAT/mirrored networking, firewall on Windows).
- For real imaging labs, prefer a **Linux VM or bare metal** on the same subnet as clients.

Use WSL primarily for **Web UI**, **configuration**, and **Agent/client testing** until you validate network boot separately.

## Troubleshooting

| Symptom | Things to check |
|--------|------------------|
| Only HTTP works | Publish **443**; browse **`https://`**; Windows firewall |
| Certificate / SSL errors | Current image + recreate; [SSL/HTTPS](ssl-https.md) |
| Agent enroll fails | **`FOG_CERT_SAN`**, **`FOG_WEB_HOST`**, [Agent troubleshooting](troubleshooting.md#fog-agent-enrollment--certificate-name-errors) |
| PXE does not work | Expected on many WSL setups — use a Linux server for LAN imaging |

```bash
docker compose logs fog-server
docker exec fog-server printenv FOG_WEB_HOST FOG_TLS_MODE FOG_CERT_SAN
```

See also [Troubleshooting Guide](troubleshooting.md).

---
layout: default
title: TLS Modes
nav_order: 4
description: "FOG_TLS_MODE — web UI, netboot, and reverse proxy presets"
permalink: /tls-modes
parent: SSL & Security
---

# TLS modes (`FOG_TLS_MODE`)

One setting configures **how you open the web UI**, **how iPXE reaches `boot.php`**, and **whether Apache terminates TLS inside the container**. This matches [FOG 1.6 netboot transport](https://docs.fogproject.org/en/latest/1.6/kb/reference/netboot-transport-and-pki/) (`WEB_url_proto` / `BOOT_url_proto`), extended for Docker and Traefik.

## Quick reference

| `FOG_TLS_MODE` | Open the UI at | PXE / `default.ipxe` chain | Apache `:443` in container |
|----------------|----------------|----------------------------|----------------------------|
| **`standard`** (default) | `https://FOG_WEB_HOST/...` (accept self-signed) | **`http://…/boot.php`** | Yes (auto self-signed) |
| **`http-only`** | `http://FOG_WEB_HOST/...` | `http://…/boot.php` | No |
| **`mounted-certs`** | `https://…` (your cert files) | **`http://…/boot.php`** | Yes (mounted) |
| **`public-cert`** | `https://FQDN/...` | **`https://FQDN/.../boot.php`** | Yes (mounted public cert) |
| **`reverse-proxy`** | **`https://FQDN/...` via proxy only** | `https://FQDN/.../boot.php` | No (proxy → `:80`) |

Set in `.env`:

```bash
FOG_TLS_MODE=standard
```

On container start, the entrypoint prints the resolved **Browse** and **Netboot** URLs.

## Mode details

### `standard`

Default single-server install: **HTTPS management UI**, **HTTP netboot** (same as upstream FOG 1.6 `standard`). PXE does not need to trust your self-signed Apache certificate.

### `http-only`

Plain HTTP for UI and netboot. Use for labs or when debugging protocol issues.

### `mounted-certs`

Mount certificate files into `/opt/fog/snapins/ssl/` and set filenames:

```bash
FOG_TLS_MODE=mounted-certs
FOG_APACHE_SSL_CERT_FILE=fullchain.pem
FOG_APACHE_SSL_KEY_FILE=privkey.pem
```

Netboot stays on **HTTP** unless you switch to `public-cert` or overrides.

### `public-cert`

HTTPS UI **and** HTTPS netboot using a **publicly trusted** certificate (e.g. Let's Encrypt) on Apache. Requires **`FOG_WEB_HOST`** to be the **FQDN** on the certificate (not an IP).

### `reverse-proxy`

Traefik, Caddy, or Nginx terminates TLS. The container serves **HTTP only**; PHP on port 80 is told the outside world uses HTTPS (`SetEnv HTTPS`) so sessions and boot URLs stay on `https://`.

Do **not** use `http://container-ip:80/fog/management/` for daily admin work — use the proxy URL. See [Reverse Proxy Setup](reverse-proxy.md) and [Troubleshooting](troubleshooting.md#login-loops-back-to-empty-form-no-error).

## Advanced overrides

Usually leave unset. When set, these override the preset for that field only:

```bash
FOG_WEB_PROTOCOL=https   # UI / session semantics
FOG_BOOT_PROTOCOL=http   # default.ipxe and DHCP HTTPBoot URL
```

## Legacy variables

**Recommended:** set `FOG_TLS_MODE` in `.env` (`.env.example` uses `standard`).

If **`FOG_TLS_MODE` is empty or unset** in the container environment, the entrypoint **infers** a mode from `FOG_INTERNAL_HTTPS_ENABLED` and `FOG_HTTP_PROTOCOL` and logs a reminder to set `FOG_TLS_MODE` explicitly.

When **`FOG_TLS_MODE` is set**, `FOG_INTERNAL_HTTPS_ENABLED` and `FOG_HTTP_PROTOCOL` are **ignored** (use `FOG_WEB_PROTOCOL` / `FOG_BOOT_PROTOCOL` for advanced overrides). `FOG_HTTP_PROTOCOL` is still populated internally as a mirror of `FOG_WEB_PROTOCOL` for older references.

## Related docs

- [SSL/HTTPS Setup](ssl-https.md) — certificates and mounts
- [Reverse Proxy Setup](reverse-proxy.md) — Traefik examples
- [Network Boot](network-boot.md) — boot file flow

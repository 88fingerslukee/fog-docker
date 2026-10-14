---
layout: default
title: Secure Boot
nav_order: 6
description: "UEFI Secure Boot enrollment and imaging with FOG Docker (FOG 1.6)"
permalink: /secure-boot
---

# Secure Boot (UEFI)

FOG 1.6 enrolls your server's signing certificate through the **PXE boot menu**, not a USB-only workflow. fog-docker follows the same layout as the native installer: signed iPXE/shim on **TFTP**, enrollment files on **`/fog/service/secureboot/`**, and **FOS kernels signed** with your server's key.

## What you need

1. **UEFI clients** with Secure Boot enabled in firmware.
2. **DHCP** pointing UEFI machines at the **signed** boot file (not the unsigned `snponly.efi` at the TFTP root).
3. **`FOG_SECURE_BOOT_ENABLED=true`** in `.env`, with the **`/opt/fog/secure-boot`** volume persisted (keys must survive container recreation).
4. Image built with **fog-ipxe-secureboot** assets (default in fog-docker builds).

## Enable on the server

```bash
FOG_SECURE_BOOT_ENABLED=true
```

Restart the container. On startup the entrypoint will:

- Generate a signing key pair under `/opt/fog/secure-boot/` (first run only).
- Sign `bzImage`, `bzImage32`, and related files under `/var/www/html/fog/service/ipxe/`.
- Publish **`MOK.der`** and **`mmx64.efi`** to `/var/www/html/fog/service/secureboot/`.

Verify from any client or the host:

```bash
curl -sS -o /dev/null -w 'MOK.der %{http_code}\n' \
  "https://${FOG_WEB_HOST}/fog/service/secureboot/MOK.der"
curl -sS -o /dev/null -w 'mmx64.efi %{http_code}\n' \
  "https://${FOG_WEB_HOST}/fog/service/secureboot/mmx64.efi"
```

Both should return **200**. A **404** means enrollment is not configured or publishing failed — check container logs for `setup-secure-boot.sh`.

## DHCP boot file (external DHCP)

| Client | Option 67 (boot file) |
|--------|------------------------|
| UEFI x64 | `secureboot/snponly-shimx64.efi` |
| UEFI ARM64 | `secureboot/arm64-efi/snponly-shimaa64.efi` |

Option **66** remains your FOG server (`FOG_TFTP_HOST`). See [Network Boot](network-boot.md) for BIOS and non–Secure Boot UEFI files.

If you use **FOG's built-in DHCP**, set the UEFI boot file variables to the same paths (see [DHCP Integration](dhcp-integration.md)).

## Enroll a machine (network-first)

1. PXE boot the client with Secure Boot **on**.
2. On the FOG menu, choose **Enroll Secure Boot Key (MOK attended setup)**.
3. iPXE downloads **`MOK.der`** and starts **MokManager** (`mmx64.efi`).
4. In MokManager: **Enroll key from disk** → select **`MOK.der`** (often listed under **iPXE**).
5. **Continue** → **Yes** → **Reboot**.

MokManager times out quickly if idle — be ready when it appears.

**USB fallback:** If `MOK.der` does not appear in the file browser, copy `MOK.der` from the URLs above onto a **FAT32** USB stick and enroll from removable media. This matches upstream's fallback text in the iPXE menu.

## After enrollment

- The key lives in **firmware**, not on disk. Reimaging or deleting the host in the FOG UI does **not** remove enrollment.
- You only re-enroll if firmware keys are cleared (some BIOS updates) or you replace the motherboard.
- Optional: run an **Enroll Secure Boot** task in FOG so the host record shows enrollment state (FOS reports what the firmware trusts).

## Capture and deploy with Secure Boot on

Once enrolled, clients can **capture** and **deploy** with Secure Boot left enabled. The chain is:

1. Microsoft-signed **shim** → FOG **iPXE** (from fog-ipxe-secureboot).
2. iPXE loads **signed FOS kernel** (`bzImage`) from the web server.
3. FOS imaging runs as usual.

If the kernel download succeeds but boot fails with a **security** error, enrollment does not match the server's signing certificate — re-enroll or confirm you did not regenerate keys on the server (that would invalidate prior enrollments).

## Troubleshooting

| Symptom | Likely cause |
|---------|----------------|
| Menu says signing is not configured | `MOK.der` missing under `service/secureboot/` — enable Secure Boot and check logs |
| `Could not load the Secure Boot enrollment menu` | `mmx64.efi` missing or HTTP error ([FOG #1868](https://github.com/FOGProject/fogproject/issues/1868) on native installs) |
| Kernel download timeout | Network/DHCP/HTTPS issue, not enrollment ([forum example](https://forums.fogproject.org/topic/18277/could-not-load-the-secure-boot-enrollment-menu/3)) |
| Secure Boot works until container rebuild with new keys | Keys not persisted — mount **`/opt/fog/secure-boot`** |

## Unattended enrollment

FOG 1.6 can offer **unattended** enrollment when **`PK.auth`**, **`KEK.auth`**, and **`db.auth`** exist in `service/secureboot/`. fog-docker does **not** generate these yet; use the attended PXE menu above. Unattended support may be added later via upstream `fog-build-sb-authvars`.

## Related

- [Environment variables](environment-variables.md) — `FOG_SECURE_BOOT_*`
- [Network Boot](network-boot.md) — PXE and HTTPBoot
- [Configuration](configuration.md)

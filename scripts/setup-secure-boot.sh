#!/bin/bash
#
# FOG 1.6 Secure Boot setup for fog-docker (single entrypoint):
#   1. Verify signed PXE chain on TFTP
#   2. Sign FOS kernels / Memtest (flat PKI — same cert as MOK.der)
#   3. Publish enrollment kit under /fog/service/secureboot/
#
# Key generation is separate: generate-keys.sh (run once when keys are absent).

set -euo pipefail

KEYS_DIR="${FOG_SECURE_BOOT_KEYS_DIR:-/opt/fog/secure-boot/keys}"
CERT_DIR="${FOG_SECURE_BOOT_CERT_DIR:-/opt/fog/secure-boot/certs}"
SHIM_DIR="${FOG_SECURE_BOOT_SHIM_DIR:-/opt/fog/secure-boot/shim}"
TFTP_DIR="${FOG_TFTP_DIR:-/tftpboot}"
FOG_SRC_DIR="${FOG_SRC_DIR:-/opt/fog/src}"
IPXE_DIR="${FOG_IPXE_SERVICE_DIR:-/var/www/html/fog/service/ipxe}"
WEB_FOG="${FOG_WEB_DOCROOT:-/var/www/html/fog}"
SB_DIR="${TFTP_DIR}/secureboot"
KITDIR="${WEB_FOG}/service/secureboot"

log_info() { echo "[INFO] $*"; }
log_warn() { echo "[WARN] $*"; }
log_error() { echo "[ERROR] $*" >&2; }

check_pxe_chain() {
    log_info "Checking Secure Boot PXE chain..."
    if [[ ! -d "$SB_DIR" ]]; then
        mkdir -p "$SB_DIR"
    fi
    if [[ ! -f "${SB_DIR}/mmx64.efi" && -f "${SHIM_DIR}/mmx64.efi" ]]; then
        log_warn "Copying MokManager into ${SB_DIR} from ${SHIM_DIR}"
        cp -f "${SHIM_DIR}/mmx64.efi" "${SB_DIR}/"
    fi
    if [[ ! -f "${SB_DIR}/snponly-shimx64.efi" ]]; then
        log_warn "Missing ${SB_DIR}/snponly-shimx64.efi — image build may not have fetched fog-ipxe-secureboot assets."
        log_warn "UEFI Secure Boot clients need DHCP option 67 pointing at secureboot/snponly-shimx64.efi"
    else
        log_info "Signed PXE chain present (secureboot/snponly-shimx64.efi)"
    fi
    if [[ ! -f "${SB_DIR}/mmx64.efi" ]]; then
        log_error "MokManager (mmx64.efi) not found under ${SB_DIR}"
        return 1
    fi
    chown -R www-data:www-data "$TFTP_DIR" 2>/dev/null || true
    return 0
}

sign_fos_kernels() {
    local key_file="${KEYS_DIR}/fog.key"
    local cert_pem="${CERT_DIR}/fog.crt"
    local failed=0

    if [[ ! -f "$key_file" || ! -f "$cert_pem" ]]; then
        log_error "Signing key or certificate missing under ${KEYS_DIR} / ${CERT_DIR}"
        return 1
    fi
    if ! command -v sbsign >/dev/null 2>&1 || ! command -v sbverify >/dev/null 2>&1; then
        log_warn "sbsign/sbverify not available; kernels will remain unsigned"
        return 1
    fi
    if ! openssl x509 -in "$cert_pem" -inform pem -noout >/dev/null 2>&1; then
        log_error "Certificate is not valid PEM: ${cert_pem}"
        return 1
    fi

    log_info "Signing FOS kernels for Secure Boot..."
    sign_one() {
        local kpath="$1"
        [[ -f "$kpath" ]] || return 0
        if sbverify --cert "$cert_pem" "$kpath" >/dev/null 2>&1; then
            log_info "Already signed: $(basename "$kpath")"
            return 0
        fi
        cp -af "$kpath" "${kpath}.unsigned"
        if sbsign --key "$key_file" --cert "$cert_pem" \
            --output "$kpath" "${kpath}.unsigned" >/dev/null 2>&1; then
            chown www-data:www-data "$kpath" 2>/dev/null || true
            log_info "Signed: $(basename "$kpath")"
        else
            log_error "Failed to sign: $(basename "$kpath")"
            failed=1
        fi
    }
    local kernel
    for kernel in bzImage bzImage32 arm_Image mt86plus_x86_64 mt86plus_i586; do
        sign_one "${IPXE_DIR}/${kernel}"
    done
    [[ $failed -eq 0 ]]
}

publish_enrollment_kit() {
    local enroll_cert="${CERT_DIR}/fog.crt"
    local mmsrc="${TFTP_DIR}/secureboot"

    if [[ ! -f "$enroll_cert" ]]; then
        log_error "Enrollment certificate not found: $enroll_cert"
        return 1
    fi

    log_info "Publishing Secure Boot enrollment kit to ${KITDIR}..."
    rm -rf "$KITDIR"
    mkdir -p "$KITDIR"

    if [[ -f "${CERT_DIR}/fog.der" ]]; then
        cp -f "${CERT_DIR}/fog.der" "${KITDIR}/MOK.der"
    elif openssl x509 -in "$enroll_cert" -inform pem -noout >/dev/null 2>&1; then
        openssl x509 -in "$enroll_cert" -outform der -out "${KITDIR}/MOK.der"
    elif openssl x509 -in "$enroll_cert" -inform der -noout >/dev/null 2>&1; then
        cp -f "$enroll_cert" "${KITDIR}/MOK.der"
    else
        log_error "Could not read ${enroll_cert} as a certificate"
        return 1
    fi

    if [[ -f "${mmsrc}/mmx64.efi" ]]; then
        cp -f "${mmsrc}/mmx64.efi" "${KITDIR}/"
    else
        log_error "MokManager binary missing: ${mmsrc}/mmx64.efi"
        return 1
    fi

    if [[ -f "${mmsrc}/arm64-efi/mmaa64.efi" ]]; then
        mkdir -p "${KITDIR}/arm64-efi"
        cp -f "${mmsrc}/arm64-efi/mmaa64.efi" "${KITDIR}/arm64-efi/"
    fi

    local pkg="${FOG_SRC_DIR}/packages/secureboot"
    if [[ -d "$pkg" ]]; then
        local f
        for f in fog-enroll-mok.sh fog-enroll-mok.desktop; do
            [[ -f "${pkg}/${f}" ]] && cp -f "${pkg}/${f}" "${KITDIR}/"
        done
    fi

    echo '<?php header("HTTP/1.1 404 Not Found");' > "${KITDIR}/index.php"
    chmod 0644 "${KITDIR}/MOK.der" "${KITDIR}/index.php" 2>/dev/null || true
    [[ -f "${KITDIR}/mmx64.efi" ]] && chmod 0644 "${KITDIR}/mmx64.efi"
    [[ -f "${KITDIR}/arm64-efi/mmaa64.efi" ]] && chmod 0644 "${KITDIR}/arm64-efi/mmaa64.efi"
    [[ -f "${KITDIR}/fog-enroll-mok.sh" ]] && chmod 0755 "${KITDIR}/fog-enroll-mok.sh"
    [[ -f "${KITDIR}/fog-enroll-mok.desktop" ]] && chmod 0644 "${KITDIR}/fog-enroll-mok.desktop"
    chown -R www-data:www-data "$KITDIR" 2>/dev/null || true
    log_info "Enrollment kit published (MOK.der + mmx64.efi)"
}

print_next_steps() {
    local web_host="${FOG_WEB_HOST:-your-fog-server}"
    local proto="${FOG_BOOT_PROTOCOL:-${FOG_HTTP_PROTOCOL:-https}}"
    echo ""
    echo "Secure Boot setup (FOG 1.6 network enrollment):"
    echo "  1. Point DHCP option 67 (UEFI x64) at: secureboot/snponly-shimx64.efi"
    echo "     (ARM64: secureboot/arm64-efi/snponly-shimaa64.efi)"
    echo "  2. PXE boot the client and choose: Enroll Secure Boot Key (MOK attended setup)"
    echo "  3. In MokManager: Enroll key from disk → select MOK.der (often under iPXE)"
    echo "  4. Reboot; capture/deploy works with Secure Boot left ON"
    echo ""
    echo "Verify enrollment files:"
    echo "  ${proto}://${web_host}/fog/service/secureboot/MOK.der"
    echo "  ${proto}://${web_host}/fog/service/secureboot/mmx64.efi"
    echo ""
    echo "If MOK.der does not appear in MokManager, use a FAT32 USB stick with MOK.der as fallback."
    echo ""
}

main() {
    check_pxe_chain
    if ! sign_fos_kernels; then
        log_warn "FOS kernel signing failed or was skipped — Secure Boot clients may fail after iPXE loads the kernel"
    fi
    publish_enrollment_kit
    print_next_steps
    log_info "Secure Boot setup completed"
}

main "$@"

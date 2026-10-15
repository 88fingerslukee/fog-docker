#!/bin/bash
# Resolve FOG_TLS_MODE into web/boot Apache and iPXE settings.
# Sourced from entrypoint.sh after FOG_WEB_HOST and SSL filename defaults are set.

_fog_tls_is_ipv4() {
    [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]
}

_fog_tls_is_true() {
    case "${1,,}" in
        true|1|yes|on) return 0 ;;
        *) return 1 ;;
    esac
}

_fog_tls_mounted_apache_certs_present() {
    local cert="/opt/fog/snapins/ssl/${FOG_APACHE_SSL_CERT_FILE:-server.crt}"
    local key="/opt/fog/snapins/ssl/${FOG_APACHE_SSL_KEY_FILE:-server.key}"
    [[ -f "$cert" && -f "$key" ]]
}

_fog_tls_infer_legacy_mode() {
    local internal="${FOG_INTERNAL_HTTPS_ENABLED:-}"
    local proto="${FOG_HTTP_PROTOCOL:-}"

    if [[ -z "$internal" && -z "$proto" ]]; then
        echo "standard"
        return
    fi

    echo "NOTE: FOG_TLS_MODE is unset; inferring from FOG_INTERNAL_HTTPS_ENABLED / FOG_HTTP_PROTOCOL (please set FOG_TLS_MODE explicitly)." >&2

    if _fog_tls_is_true "$internal"; then
        if [[ "${proto,,}" = "http" ]]; then
            echo "http-only"
        elif _fog_tls_mounted_apache_certs_present; then
            echo "mounted-certs"
        else
            echo "standard"
        fi
    else
        if [[ "${proto,,}" = "https" ]]; then
            echo "reverse-proxy"
        else
            echo "http-only"
        fi
    fi
}

_fog_tls_apply_preset() {
    local mode="$1"
    FOG_WEB_PROTOCOL=""
    FOG_BOOT_PROTOCOL=""
    FOG_INTERNAL_HTTPS_ENABLED=""
    FOG_APACHE_SETENV_HTTPS_ON_HTTP_VHOST="false"
    FOG_BOOT_REBUILD_IPXE="false"
    FOG_WEB_CERT_PUBLICLY_TRUSTED="false"

    case "$mode" in
        standard|self-signed)
            FOG_WEB_PROTOCOL="https"
            FOG_BOOT_PROTOCOL="http"
            FOG_INTERNAL_HTTPS_ENABLED="true"
            ;;
        http-only|http)
            FOG_WEB_PROTOCOL="http"
            FOG_BOOT_PROTOCOL="http"
            FOG_INTERNAL_HTTPS_ENABLED="false"
            ;;
        mounted-certs|external-certs)
            FOG_WEB_PROTOCOL="https"
            FOG_BOOT_PROTOCOL="http"
            FOG_INTERNAL_HTTPS_ENABLED="true"
            ;;
        public-cert)
            FOG_WEB_PROTOCOL="https"
            FOG_BOOT_PROTOCOL="https"
            FOG_INTERNAL_HTTPS_ENABLED="true"
            FOG_WEB_CERT_PUBLICLY_TRUSTED="true"
            ;;
        reverse-proxy|proxy)
            FOG_WEB_PROTOCOL="https"
            FOG_BOOT_PROTOCOL="https"
            FOG_INTERNAL_HTTPS_ENABLED="false"
            FOG_APACHE_SETENV_HTTPS_ON_HTTP_VHOST="true"
            FOG_WEB_CERT_PUBLICLY_TRUSTED="true"
            ;;
        embed-ca)
            FOG_WEB_PROTOCOL="https"
            FOG_BOOT_PROTOCOL="https"
            FOG_INTERNAL_HTTPS_ENABLED="true"
            FOG_BOOT_REBUILD_IPXE="true"
            ;;
        *)
            echo "ERROR: Unknown FOG_TLS_MODE='$mode'." >&2
            echo "Valid modes: standard, http-only, mounted-certs, public-cert, reverse-proxy, embed-ca" >&2
            return 1
            ;;
    esac
    return 0
}

_fog_tls_validate() {
    local mode="$1"

    if [[ "$FOG_BOOT_PROTOCOL" = "https" && "$FOG_BOOT_REBUILD_IPXE" != "true" && "$FOG_WEB_CERT_PUBLICLY_TRUSTED" != "true" ]]; then
        echo "ERROR: HTTPS netboot (FOG_BOOT_PROTOCOL=https) requires a publicly trusted certificate" >&2
        echo "       (FOG_TLS_MODE=public-cert or reverse-proxy) or FOG_TLS_MODE=embed-ca with iPXE rebuild." >&2
        echo "       For self-signed direct access use FOG_TLS_MODE=standard (HTTPS UI, HTTP netboot)." >&2
        return 1
    fi

    if [[ "$FOG_BOOT_PROTOCOL" = "https" ]] && _fog_tls_is_ipv4 "$FOG_WEB_HOST"; then
        echo "ERROR: HTTPS netboot requires FOG_WEB_HOST to be an FQDN (certificate name), not an IP address." >&2
        echo "       Set FOG_WEB_HOST=fog.example.com and use DNS, or use FOG_TLS_MODE=standard for HTTP netboot." >&2
        return 1
    fi

    if [[ "$mode" = "embed-ca" ]]; then
        echo "ERROR: FOG_TLS_MODE=embed-ca is not supported in this image yet (iPXE CA embed / rebuild)." >&2
        echo "       Use standard, mounted-certs, public-cert, reverse-proxy, or http-only." >&2
        return 1
    fi

    if [[ "$mode" = "mounted-certs" || "$mode" = "public-cert" ]]; then
        if ! _fog_tls_mounted_apache_certs_present; then
            echo "ERROR: FOG_TLS_MODE=$mode requires Apache certificate files mounted at /opt/fog/snapins/ssl/" >&2
            echo "       Expected: ${FOG_APACHE_SSL_CERT_FILE} and ${FOG_APACHE_SSL_KEY_FILE}" >&2
            return 1
        fi
    fi

    if [[ "$mode" = "reverse-proxy" ]]; then
        echo "NOTE: reverse-proxy mode — browse the UI only via your proxy (https://\$FOG_WEB_HOST/...)." >&2
        echo "      Plain HTTP to the container port is for the proxy backend, not for admin login." >&2
    fi

    if [[ "$FOG_WEB_PROTOCOL" = "https" && "$FOG_INTERNAL_HTTPS_ENABLED" != "true" && "$FOG_APACHE_SETENV_HTTPS_ON_HTTP_VHOST" != "true" ]]; then
        echo "ERROR: Internal configuration error: WEB=https but neither Apache SSL nor reverse-proxy SetEnv is enabled." >&2
        return 1
    fi

    return 0
}

resolve_fog_tls_mode() {
    local mode="${FOG_TLS_MODE:-}"
    local saved_internal="${FOG_INTERNAL_HTTPS_ENABLED:-}"
    local saved_http="${FOG_HTTP_PROTOCOL:-}"
    local saved_boot="${FOG_BOOT_PROTOCOL:-}"
    local saved_web="${FOG_WEB_PROTOCOL:-}"

    if [[ -z "$mode" ]]; then
        mode="$(_fog_tls_infer_legacy_mode)"
    else
        mode="${mode,,}"
    fi

    # Alias normalization
    case "$mode" in
        self-signed) mode="standard" ;;
        http) mode="http-only" ;;
        external-certs) mode="mounted-certs" ;;
        proxy) mode="reverse-proxy" ;;
    esac

    if ! _fog_tls_apply_preset "$mode"; then
        exit 1
    fi

    # Explicit overrides (advanced). When FOG_TLS_MODE is set, legacy booleans are ignored
    # so docker-compose defaults cannot clobber the preset.
    if [[ -n "$saved_web" ]]; then
        FOG_WEB_PROTOCOL="${saved_web,,}"
    fi
    if [[ -n "$saved_boot" ]]; then
        FOG_BOOT_PROTOCOL="${saved_boot,,}"
    fi

    if [[ -z "${FOG_TLS_MODE:-}" ]]; then
        if [[ -n "$saved_internal" ]]; then
            FOG_INTERNAL_HTTPS_ENABLED="$(_fog_tls_is_true "$saved_internal" && echo true || echo false)"
        fi
        if [[ -n "$saved_http" ]]; then
            FOG_WEB_PROTOCOL="${saved_http,,}"
        fi
    else
        if [[ -n "$saved_internal" ]]; then
            echo "NOTE: FOG_TLS_MODE is set; ignoring FOG_INTERNAL_HTTPS_ENABLED (use FOG_WEB_PROTOCOL / FOG_BOOT_PROTOCOL to override)." >&2
        fi
        if [[ -n "$saved_http" && "$saved_http" != "$FOG_WEB_PROTOCOL" ]]; then
            echo "NOTE: FOG_TLS_MODE is set; ignoring FOG_HTTP_PROTOCOL (use FOG_WEB_PROTOCOL to override)." >&2
        fi
    fi

    case "$FOG_WEB_PROTOCOL" in
        http|https) ;;
        *)
            echo "ERROR: FOG_WEB_PROTOCOL must be http or https (got '$FOG_WEB_PROTOCOL')" >&2
            exit 1
            ;;
    esac
    case "$FOG_BOOT_PROTOCOL" in
        http|https) ;;
        *)
            echo "ERROR: FOG_BOOT_PROTOCOL must be http or https (got '$FOG_BOOT_PROTOCOL')" >&2
            exit 1
            ;;
    esac

    if ! _fog_tls_validate "$mode"; then
        exit 1
    fi

    # Back-compat for templates and docs still reading FOG_HTTP_PROTOCOL
    FOG_HTTP_PROTOCOL="$FOG_WEB_PROTOCOL"

    export FOG_TLS_MODE="$mode"
    export FOG_WEB_PROTOCOL FOG_BOOT_PROTOCOL FOG_HTTP_PROTOCOL
    export FOG_INTERNAL_HTTPS_ENABLED
    export FOG_APACHE_SETENV_HTTPS_ON_HTTP_VHOST
    export FOG_BOOT_REBUILD_IPXE FOG_WEB_CERT_PUBLICLY_TRUSTED

    echo "FOG_TLS_MODE=$mode → WEB=$FOG_WEB_PROTOCOL BOOT=$FOG_BOOT_PROTOCOL INTERNAL_HTTPS=$FOG_INTERNAL_HTTPS_ENABLED SETENV_ON_HTTP_VHOST=$FOG_APACHE_SETENV_HTTPS_ON_HTTP_VHOST"
    if [[ "$FOG_WEB_PROTOCOL" = "https" && "$FOG_INTERNAL_HTTPS_ENABLED" = "true" ]]; then
        echo "  Browse: https://${FOG_WEB_HOST}${FOG_WEB_ROOT:-/fog}/management/"
    elif [[ "$FOG_WEB_PROTOCOL" = "https" ]]; then
        echo "  Browse: https://${FOG_WEB_HOST}${FOG_WEB_ROOT:-/fog}/management/ (via reverse proxy)"
    else
        echo "  Browse: http://${FOG_WEB_HOST}${FOG_WEB_ROOT:-/fog}/management/"
    fi
    if [[ "$FOG_BOOT_PROTOCOL" = "http" ]]; then
        echo "  Netboot: http://${FOG_WEB_HOST}${FOG_WEB_ROOT:-/fog}/service/ipxe/boot.php"
    else
        echo "  Netboot: https://${FOG_WEB_HOST}${FOG_WEB_ROOT:-/fog}/service/ipxe/boot.php"
    fi
}

resolve_fog_tls_mode

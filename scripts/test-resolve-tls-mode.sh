#!/bin/bash
# Quick matrix test for resolve-tls-mode.sh (run from repo root or in CI).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

_run_resolve() {
    bash -c "
        set -e
        export FOG_WEB_HOST=\"\${FOG_WEB_HOST:-192.168.1.100}\"
        export FOG_WEB_ROOT=\"\${FOG_WEB_ROOT:-/fog}\"
        export FOG_TLS_MODE=\"\${FOG_TLS_MODE:-}\"
        export FOG_INTERNAL_HTTPS_ENABLED=\"\${FOG_INTERNAL_HTTPS_ENABLED:-}\"
        export FOG_HTTP_PROTOCOL=\"\${FOG_HTTP_PROTOCOL:-}\"
        export FOG_WEB_PROTOCOL=\"\${FOG_WEB_PROTOCOL:-}\"
        export FOG_BOOT_PROTOCOL=\"\${FOG_BOOT_PROTOCOL:-}\"
        export FOG_APACHE_SSL_CERT_FILE=\"\${FOG_APACHE_SSL_CERT_FILE:-server.crt}\"
        export FOG_APACHE_SSL_KEY_FILE=\"\${FOG_APACHE_SSL_KEY_FILE:-server.key}\"
        source \"$SCRIPT_DIR/resolve-tls-mode.sh\" >/dev/null
        echo \"WEB=\$FOG_WEB_PROTOCOL BOOT=\$FOG_BOOT_PROTOCOL INTERNAL=\$FOG_INTERNAL_HTTPS_ENABLED SETENV=\$FOG_APACHE_SETENV_HTTPS_ON_HTTP_VHOST\"
    "
}

assert_contains() {
    local haystack="$1" needle="$2" label="$3"
    if [[ "$haystack" != *"$needle"* ]]; then
        echo "FAIL: $label — expected to contain '$needle', got: $haystack"
        exit 1
    fi
}

echo "=== FOG_TLS_MODE=standard ==="
out="$(FOG_TLS_MODE=standard _run_resolve)"
assert_contains "$out" "WEB=https" "standard"
assert_contains "$out" "BOOT=http" "standard"
assert_contains "$out" "INTERNAL=true" "standard"
assert_contains "$out" "SETENV=false" "standard"

echo "=== FOG_TLS_MODE=reverse-proxy ==="
out="$(FOG_TLS_MODE=reverse-proxy FOG_WEB_HOST=fog.example.com _run_resolve)"
assert_contains "$out" "WEB=https" "proxy"
assert_contains "$out" "BOOT=https" "proxy"
assert_contains "$out" "INTERNAL=false" "proxy"
assert_contains "$out" "SETENV=true" "proxy"

echo "=== FOG_TLS_MODE=http-only ==="
out="$(FOG_TLS_MODE=http-only _run_resolve)"
assert_contains "$out" "WEB=http" "http-only"
assert_contains "$out" "BOOT=http" "http-only"

echo "=== Legacy infer reverse-proxy ==="
out="$(FOG_INTERNAL_HTTPS_ENABLED=false FOG_HTTP_PROTOCOL=https FOG_WEB_HOST=fog.example.com _run_resolve)"
assert_contains "$out" "BOOT=https" "legacy proxy"
assert_contains "$out" "SETENV=true" "legacy proxy"

echo "=== FOG_TLS_MODE wins over legacy compose defaults ==="
out="$(FOG_TLS_MODE=standard FOG_INTERNAL_HTTPS_ENABLED=false FOG_HTTP_PROTOCOL=http _run_resolve)"
assert_contains "$out" "BOOT=http" "mode precedence"
assert_contains "$out" "INTERNAL=true" "mode precedence"

echo "All resolve-tls-mode tests passed."

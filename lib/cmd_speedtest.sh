#!/usr/bin/env bash

set -euo pipefail

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    source "${SCRIPT_DIR}/lib/common.sh"
    source "${SCRIPT_DIR}/lib/validation.sh"
    source "${SCRIPT_DIR}/lib/config.sh"
    source "${SCRIPT_DIR}/lib/security.sh"
fi

run_speedtest() {
    log_info "=== Install Ookla Speedtest CLI ==="

    install_speedtest

    local version="unknown"
    if command -v speedtest >/dev/null 2>&1; then
        version="$(speedtest --version 2>/dev/null | head -1 || echo "installed")"
    fi

    log_change "SPEEDTEST INSTALLED: version=${version}"

    echo ""
    echo "=== Speedtest CLI Installed ==="
    echo "  Version: ${version}"
    echo "  Usage:   speedtest"
    echo ""

    log_info "Speedtest CLI installation completed"
    return 0
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_speedtest
fi

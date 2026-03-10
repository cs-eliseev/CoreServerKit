#!/usr/bin/env bash

set -euo pipefail

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    source "${SCRIPT_DIR}/lib/common.sh"
    source "${SCRIPT_DIR}/lib/validation.sh"
    source "${SCRIPT_DIR}/lib/config.sh"
    source "${SCRIPT_DIR}/lib/security.sh"
fi

repair_dpkg() {
    if ! dpkg --audit >/dev/null 2>&1 || [[ -f /var/lib/dpkg/updates/0000 ]]; then
        log_warn "Detected interrupted dpkg state, attempting repair..."
        if ! dpkg --configure -a 2>&1 | tee -a "${LOG_FILE}"; then
            log_error "Failed to repair dpkg state"
            return 1
        fi
        log_info "dpkg state repaired successfully"
    fi
    return 0
}

update_package_repositories() {
    repair_dpkg || log_warn "dpkg repair failed, continuing anyway"
    wait_for_apt_lock || return 1
    log_info "Updating package repositories..."

    if ! apt-get update -qq 2>&1 | tee -a "${LOG_FILE}"; then
        log_error "Failed to update package repositories"
        return 1
    fi

    log_info "Package repositories updated successfully"
    return 0
}

upgrade_packages() {
    log_info "Upgrading installed packages..."

    if ! DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -qq 2>&1 | tee -a "${LOG_FILE}"; then
        log_error "Failed to upgrade packages"
        return 1
    fi

    log_info "Packages upgraded successfully"
    return 0
}

run_update() {
    log_info "=== System Update ==="

    update_package_repositories || log_warn "Package repository update failed"
    upgrade_packages || log_warn "Package upgrade failed (continuing anyway)"

    local reboot_status="not required"
    check_reboot_required && reboot_status="required"
    log_change "PACKAGES UPDATED: apt update + upgrade completed, reboot=${reboot_status}"

    echo ""
    echo "=== System Update Complete ==="

    if [[ "${reboot_status}" == "required" ]]; then
        echo "  Status: Reboot required"
        echo ""
        echo "  Please reboot the server when convenient:"
        echo "    sudo reboot"
    else
        echo "  Status: Up to date"
    fi

    echo ""
    log_info "System update completed"
    return 0
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_update
fi

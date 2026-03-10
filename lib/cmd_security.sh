#!/usr/bin/env bash

set -euo pipefail

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    source "${SCRIPT_DIR}/lib/common.sh"
    source "${SCRIPT_DIR}/lib/validation.sh"
    source "${SCRIPT_DIR}/lib/config.sh"
    source "${SCRIPT_DIR}/lib/security.sh"
fi

run_security() {
    log_info "=== Security Hardening ==="

    local ssh_port
    local default_port
    default_port="$(shuf -i 10000-65535 -n 1)"

    if [[ "${AUTO_MODE}" == true ]]; then
        ssh_port="${default_port}"
    else
        echo ""
        while true; do
            prompt_with_default "Enter SSH port" "${default_port}" ssh_port

            if validate_port "${ssh_port}"; then
                break
            else
                echo "Invalid port. Must be between 1024 and 65535."
                echo ""
            fi
        done

        echo ""
        echo "=== Security Configuration ==="
        echo "  SSH port:                ${ssh_port}"
        echo "  Root login:              Disabled"
        echo "  Password authentication: Disabled"
        echo "  Firewall:                UFW (deny incoming, allow SSH)"
        echo "  ICMP:                    DROP all"
        echo "  Intrusion prevention:    fail2ban (5 retries, 10min ban)"
        echo ""

    fi

    log_info "--- SSH Hardening ---"
    if is_ssh_hardened "${ssh_port}"; then
        log_info "SSH is already hardened on port ${ssh_port}, skipping"
    else
        configure_ssh_hardening "${ssh_port}"
        cleanup_old_backups "/etc/ssh/sshd_config" 10
        restart_ssh_service || die "Failed to restart SSH service"
        log_change "SSH HARDENED: port=${ssh_port}, root-login=disabled, password-auth=disabled"
    fi

    log_info "--- Firewall Configuration ---"
    if is_ufw_configured "${ssh_port}"; then
        log_info "UFW firewall is already configured, skipping"
    else
        configure_ufw_defaults
        allow_ssh_port "${ssh_port}"
        enable_ufw
        remove_default_ssh_port "${ssh_port}"
        log_change "UFW CONFIGURED: default=deny-incoming, allow=${ssh_port}/tcp"
    fi

    log_info "--- ICMP Filtering ---"
    configure_icmp_filtering
    ufw reload 2>/dev/null || log_warn "UFW reload failed, may need manual restart"
    log_change "ICMP FILTERED: INPUT+FORWARD set to DROP"

    log_info "--- Intrusion Prevention ---"
    if is_fail2ban_configured; then
        log_info "fail2ban is already configured, skipping"
    else
        install_fail2ban
        configure_ssh_jail "${ssh_port}"
        reload_fail2ban
        log_change "FAIL2BAN CONFIGURED: sshd jail, maxretry=5, bantime=10min"
    fi

    echo ""
    echo "=== Security Hardening Complete ==="
    echo "  SSH port:     ${ssh_port} (key-only auth, no root login)"
    echo "  Firewall:     UFW active (deny incoming, allow SSH)"
    echo "  ICMP:         All INPUT/FORWARD set to DROP"
    echo "  fail2ban:     Active (sshd jail: 5 retries, 10min ban)"
    echo ""
    echo "  CRITICAL: Test SSH connection in a NEW terminal before closing this one!"
    echo "    ssh -p ${ssh_port} username@your-server-ip"
    echo ""

    log_info "Security hardening completed"
    return 0
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_security
fi

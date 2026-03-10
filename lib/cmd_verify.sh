#!/usr/bin/env bash

set -euo pipefail

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    source "${SCRIPT_DIR}/lib/common.sh"
    source "${SCRIPT_DIR}/lib/validation.sh"
    source "${SCRIPT_DIR}/lib/config.sh"
    source "${SCRIPT_DIR}/lib/security.sh"
fi

verify_user() {
    echo "--- User Verification ---"

    local sudo_users
    sudo_users="$(getent group sudo 2>/dev/null | cut -d: -f4)"

    if [[ -n "${sudo_users}" ]]; then
        echo "  Sudo users: ${sudo_users}"
        log_info "Sudo users: ${sudo_users}"
    else
        echo "  Sudo users: none found"
        log_warn "No sudo users found"
    fi

    echo ""
}

verify_ssh_key_status() {
    echo "--- SSH Key Verification ---"

    local found=false
    local user_home

    for user_home in /home/*; do
        local username
        username="$(basename "${user_home}")"
        local auth_keys="${user_home}/.ssh/authorized_keys"

        if [[ -f "${auth_keys}" ]]; then
            local key_count
            key_count="$(wc -l < "${auth_keys}")"
            echo "  ${username}: ${key_count} key(s) in authorized_keys"
            found=true
        fi
    done

    if [[ "${found}" == false ]]; then
        echo "  No authorized_keys files found"
    fi

    echo ""
}

verify_security() {
    echo "--- Security Verification ---"

    echo "  SSH:"
    local sshd_config
    if sshd_config="$(sshd -T 2>/dev/null)"; then
        local ssh_port
        ssh_port="$(echo "${sshd_config}" | grep "^port " | awk '{print $2}')"
        local root_login
        root_login="$(echo "${sshd_config}" | grep "^permitrootlogin " | awk '{print $2}')"
        local pass_auth
        pass_auth="$(echo "${sshd_config}" | grep "^passwordauthentication " | awk '{print $2}')"

        echo "    Port:                    ${ssh_port}"
        echo "    PermitRootLogin:         ${root_login}"
        echo "    PasswordAuthentication:  ${pass_auth}"
    else
        echo "    Unable to read SSH configuration"
    fi

    echo "  UFW:"
    if command -v ufw >/dev/null 2>&1; then
        local ufw_status
        ufw_status="$(ufw status 2>/dev/null | head -1)"
        echo "    ${ufw_status}"

        ufw status 2>/dev/null | grep -E "^\[|ALLOW|DENY" | while IFS= read -r line; do
            echo "    ${line}"
        done
    else
        echo "    UFW not installed"
    fi

    echo "  ICMP filtering:"
    local before_rules="/etc/ufw/before.rules"
    if [[ -f "${before_rules}" ]]; then
        local icmp_drop_count
        icmp_drop_count="$(grep -c "icmp.*-j DROP" "${before_rules}" 2>/dev/null || echo "0")"
        local icmp_accept_count
        icmp_accept_count="$(grep -c "icmp.*-j ACCEPT" "${before_rules}" 2>/dev/null || echo "0")"
        echo "    DROP rules:   ${icmp_drop_count}"
        echo "    ACCEPT rules: ${icmp_accept_count}"
    else
        echo "    /etc/ufw/before.rules not found"
    fi

    echo "  fail2ban:"
    if command -v fail2ban-client >/dev/null 2>&1; then
        if systemctl is-active fail2ban >/dev/null 2>&1; then
            echo "    Status: active"
            if fail2ban-client status 2>/dev/null | grep -q "sshd"; then
                local jail_info
                jail_info="$(fail2ban-client status sshd 2>/dev/null)"
                local banned
                banned="$(echo "${jail_info}" | grep "Currently banned" | awk '{print $NF}')"
                local total
                total="$(echo "${jail_info}" | grep "Total banned" | awk '{print $NF}')"
                echo "    sshd jail: enabled (banned: ${banned:-0}, total: ${total:-0})"
            else
                echo "    sshd jail: not active"
            fi
        else
            echo "    Status: not running"
        fi
    else
        echo "    Not installed"
    fi

    echo ""
}

verify_speedtest_status() {
    echo "--- Speedtest Verification ---"

    if command -v speedtest >/dev/null 2>&1; then
        local version
        version="$(speedtest --version 2>/dev/null | head -1 || echo "installed")"
        echo "  Status:  installed"
        echo "  Version: ${version}"
    else
        echo "  Status: not installed"
    fi

    echo ""
}

verify_update_status() {
    echo "--- System Update Verification ---"

    if check_reboot_required; then
        echo "  Reboot: required"
    else
        echo "  Reboot: not required"
    fi

    local apt_stamp="/var/lib/apt/periodic/update-stamp"
    if [[ -f "${apt_stamp}" ]]; then
        local last_update
        last_update="$(stat -c '%y' "${apt_stamp}" 2>/dev/null | cut -d' ' -f1)"
        echo "  Last apt update: ${last_update}"
    fi

    echo ""
}

run_verify() {
    local scope="${1:-all}"

    log_info "=== Configuration Verification (scope: ${scope}) ==="
    echo ""
    echo "=== Configuration Verification ==="
    echo ""

    case "${scope}" in
        all)
            verify_user
            verify_ssh_key_status
            verify_security
            verify_speedtest_status
            verify_update_status
            ;;
        user)
            verify_user
            ;;
        ssh-key)
            verify_ssh_key_status
            ;;
        security)
            verify_security
            ;;
        speedtest)
            verify_speedtest_status
            ;;
        update)
            verify_update_status
            ;;
        *)
            log_warn "Unknown verification scope: ${scope}"
            echo "Unknown scope: ${scope}"
            return 1
            ;;
    esac

    log_info "Verification completed (scope: ${scope})"
    return 0
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_verify "${1:-all}"
fi

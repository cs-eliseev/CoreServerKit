#!/usr/bin/env bash

set -euo pipefail

modify_sshd_config() {
    local ssh_port="$1"
    local sshd_config="/etc/ssh/sshd_config"
    local temp_config
    temp_config="$(mktemp /etc/ssh/sshd_config.tmp.XXXXXX)"
    TEMP_FILES+=("${temp_config}")

    backup_file "${sshd_config}"
    cp "${sshd_config}" "${temp_config}"

    sed -i '/^Port /d' "${temp_config}"
    sed -i '/^#Port /d' "${temp_config}"
    sed -i '/^PermitRootLogin /d' "${temp_config}"
    sed -i '/^#PermitRootLogin /d' "${temp_config}"
    sed -i '/^PasswordAuthentication /d' "${temp_config}"
    sed -i '/^#PasswordAuthentication /d' "${temp_config}"
    sed -i '/^PubkeyAuthentication /d' "${temp_config}"
    sed -i '/^#PubkeyAuthentication /d' "${temp_config}"
    sed -i '/^ChallengeResponseAuthentication /d' "${temp_config}"
    sed -i '/^KbdInteractiveAuthentication /d' "${temp_config}"

    cat >> "${temp_config}" <<EOF

Port ${ssh_port}
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
KbdInteractiveAuthentication no
EOF

    if ! validate_sshd_config "${temp_config}"; then
        log_error "SSH config validation failed"
        return 1
    fi

    cp "${temp_config}" "${sshd_config}"
    chmod 644 "${sshd_config}"
    chown root:root "${sshd_config}"

    log_info "SSH configuration updated successfully"
    return 0
}

validate_sshd_config() {
    local config_file="$1"

    if ! sshd -t -f "${config_file}" 2>/dev/null; then
        log_error "Invalid SSH configuration: ${config_file}"
        return 1
    fi

    log_info "SSH configuration validated: ${config_file}"
    return 0
}

configure_ssh_hardening() {
    local ssh_port="$1"

    log_info "Starting SSH hardening (port: ${ssh_port})"

    if ! validate_port "${ssh_port}"; then
        die "Invalid SSH port: ${ssh_port}"
    fi

    if ! modify_sshd_config "${ssh_port}"; then
        die "Failed to modify SSH configuration"
    fi

    log_info "SSH hardening complete"
    return 0
}

restart_ssh_service() {
    log_info "Restarting SSH service..."

    local ssh_service
    if systemctl cat ssh.service >/dev/null 2>&1; then
        ssh_service="ssh"
    else
        ssh_service="sshd"
    fi

    systemctl daemon-reload 2>/dev/null || true

    if systemctl restart "${ssh_service}" 2>/dev/null; then
        log_info "SSH service restarted via systemctl"
    elif service "${ssh_service}" restart 2>/dev/null; then
        log_info "SSH service restarted via service"
    else
        local sshd_pid
        sshd_pid="$(pgrep -x sshd | head -1)"
        if [[ -n "${sshd_pid}" ]]; then
            log_warn "systemctl/service failed, sending SIGHUP to sshd (PID ${sshd_pid})"
            if ! kill -HUP "${sshd_pid}" 2>/dev/null; then
                log_error "Failed to restart SSH service"
                return 1
            fi
        else
            log_error "Failed to restart SSH service: no running sshd found"
            return 1
        fi
    fi

    sleep 1

    if ! pgrep -x sshd >/dev/null 2>&1; then
        log_error "SSH service not running after restart"
        return 1
    fi

    log_info "SSH service restarted successfully"
    return 0
}

configure_ufw_defaults() {
    log_info "Configuring UFW default policies"

    ufw default deny incoming
    ufw default allow outgoing

    log_info "UFW defaults configured (deny incoming, allow outgoing)"
    return 0
}

allow_ssh_port() {
    local ssh_port="$1"

    log_info "Allowing SSH port ${ssh_port} through firewall"
    ufw allow "${ssh_port}/tcp" comment 'SSH'
    log_info "SSH port ${ssh_port}/tcp allowed in firewall"
    return 0
}

configure_icmp_filtering() {
    local before_rules="/etc/ufw/before.rules"

    log_info "Configuring ICMP filtering (DROP all)"

    backup_file "${before_rules}"

    sed -i '/ok icmp codes for INPUT/,/^$/{
        s/-j ACCEPT/-j DROP/g
    }' "${before_rules}"

    sed -i '/ok icmp code.* for FORWARD/,/^$/{
        s/-j ACCEPT/-j DROP/g
    }' "${before_rules}"

    if ! grep -q "icmp.*source-quench.*DROP" "${before_rules}"; then
        sed -i '/ok icmp codes for INPUT/,/^$/{
            /^$/i \
-A ufw-before-input -p icmp --icmp-type source-quench -j DROP
        }' "${before_rules}"
        log_info "ICMP source-quench DROP rule added"
    fi

    log_info "ICMP filtering configured: all INPUT and FORWARD ICMP set to DROP"
    return 0
}

remove_default_ssh_port() {
    local new_port="$1"

    if [[ "${new_port}" == "22" ]]; then
        log_info "SSH port is 22, not removing default rule"
        return 0
    fi

    if ufw status | grep -q "22/tcp"; then
        log_info "Removing default SSH port 22 from firewall (migrated to ${new_port})"
        ufw delete allow 22/tcp 2>/dev/null || true
    fi

    return 0
}

enable_ufw() {
    log_info "Enabling UFW firewall"
    ufw --force enable
    log_info "UFW firewall enabled"
    return 0
}

check_user_exists() {
    local username="$1"

    if id "$username" >/dev/null 2>&1; then
        return 0
    fi

    return 1
}

create_admin_user() {
    local username="$1"
    local password="$2"

    log_info "Creating user: ${username}"

    if check_user_exists "${username}"; then
        log_warn "User ${username} already exists, skipping creation"
        return 0
    fi

    if ! useradd -m -s /bin/bash -c "Administrative user" "${username}"; then
        log_error "Failed to create user: ${username}"
        return 1
    fi

    echo "${username}:${password}" | chpasswd
    log_info "Password set for user: ${username}"

    log_info "User created successfully: ${username}"
    return 0
}

add_user_to_sudo() {
    local username="$1"

    log_info "Adding ${username} to sudo group"

    if ! usermod -aG sudo "${username}"; then
        log_error "Failed to add ${username} to sudo group"
        return 1
    fi

    log_info "${username} added to sudo group"
    return 0
}

setup_user_ssh_directory() {
    local username="$1"
    local user_home
    user_home="$(getent passwd "${username}" | cut -d: -f6)"
    if [[ -z "${user_home}" ]]; then
        log_error "Cannot resolve home directory for user: ${username}"
        return 1
    fi
    local ssh_dir="${user_home}/.ssh"

    log_info "Setting up SSH directory: ${ssh_dir}"

    mkdir -p "${ssh_dir}"
    chmod 700 "${ssh_dir}"
    chown "${username}:${username}" "${ssh_dir}"

    log_info "SSH directory configured: ${ssh_dir}"
    return 0
}

generate_ed25519_key() {
    local key_file="$1"
    local comment="$2"

    log_info "Generating Ed25519 SSH key pair: ${key_file}"

    mkdir -p "$(dirname "${key_file}")"

    if ! ssh-keygen -t ed25519 -a 100 -C "${comment}" -f "${key_file}" -N "" >/dev/null 2>&1; then
        log_error "Failed to generate SSH key pair"
        return 1
    fi

    chmod 600 "${key_file}"
    chmod 644 "${key_file}.pub"

    log_info "SSH key pair generated successfully"
    return 0
}

add_ssh_key_to_authorized_keys() {
    local username="$1"
    local ssh_key="$2"
    local user_home
    user_home="$(getent passwd "${username}" | cut -d: -f6)"
    if [[ -z "${user_home}" ]]; then
        log_error "Cannot resolve home directory for user: ${username}"
        return 1
    fi
    local ssh_dir="${user_home}/.ssh"
    local authorized_keys="${ssh_dir}/authorized_keys"

    log_info "Adding SSH key to ${authorized_keys}"

    setup_user_ssh_directory "${username}"

    echo "${ssh_key}" >> "${authorized_keys}"
    chmod 600 "${authorized_keys}"
    chown "${username}:${username}" "${authorized_keys}"

    if ! grep -qF "${ssh_key}" "${authorized_keys}" 2>/dev/null; then
        log_error "Failed to write SSH key to ${authorized_keys}"
        return 1
    fi

    log_info "SSH key added to ${authorized_keys}"
    return 0
}

install_fail2ban() {
    log_info "Installing fail2ban..."

    if command -v fail2ban-client >/dev/null 2>&1; then
        log_info "fail2ban already installed"
        return 0
    fi

    wait_for_apt_lock || return 1

    if ! DEBIAN_FRONTEND=noninteractive apt-get install -y -qq fail2ban 2>&1 | tee -a "${LOG_FILE}"; then
        log_error "Failed to install fail2ban"
        return 1
    fi

    log_info "fail2ban installed successfully"
    return 0
}

configure_ssh_jail() {
    local ssh_port="$1"
    local jail_local="/etc/fail2ban/jail.local"

    log_info "Configuring fail2ban SSH jail (port: ${ssh_port})"

    if [[ -f "${jail_local}" ]]; then
        backup_file "${jail_local}"
    fi

    cat > "${jail_local}" <<EOF
[DEFAULT]
bantime = 600
findtime = 600
banaction = ufw

[sshd]
enabled = true
port = ${ssh_port}
filter = sshd
logpath = /var/log/auth.log
maxretry = 5
bantime = 600
findtime = 600
EOF

    log_info "fail2ban SSH jail configured"
    return 0
}

reload_fail2ban() {
    log_info "Reloading fail2ban service..."

    if ! systemctl is-active fail2ban >/dev/null 2>&1 && ! service fail2ban status >/dev/null 2>&1; then
        log_info "Starting fail2ban service..."
        systemctl start fail2ban 2>/dev/null || service fail2ban start 2>/dev/null || true
    fi

    if ! fail2ban-client reload >/dev/null 2>&1; then
        log_warn "fail2ban-client reload failed, restarting service..."
        systemctl restart fail2ban 2>/dev/null || service fail2ban restart 2>/dev/null || true
    fi

    log_info "fail2ban service reloaded"
    return 0
}

install_speedtest() {
    log_info "Installing Ookla Speedtest CLI..."

    if command -v speedtest >/dev/null 2>&1; then
        log_info "Speedtest CLI already installed"
        return 0
    fi

    wait_for_apt_lock || return 1

    if ! DEBIAN_FRONTEND=noninteractive apt-get install -y -qq curl gnupg apt-transport-https 2>&1 | tee -a "${LOG_FILE}"; then
        log_error "Failed to install speedtest dependencies"
        return 1
    fi

    if ! curl -s https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.deb.sh | bash 2>&1 | tee -a "${LOG_FILE}"; then
        log_error "Failed to add Ookla repository"
        return 1
    fi

    local sources_list="/etc/apt/sources.list.d/ookla_speedtest-cli.list"
    if [[ -f "${sources_list}" ]]; then
        local codename
        codename="$(lsb_release -cs 2>/dev/null || echo "")"
        if [[ -n "${codename}" && "${codename}" != "jammy" ]]; then
            if ! apt-cache policy speedtest 2>/dev/null | grep -q "Candidate:.*[0-9]"; then
                log_warn "No speedtest package for '${codename}', switching repo to 'jammy'"
                sed -i "s/${codename}/jammy/g" "${sources_list}"
                apt-get update -qq 2>&1 | tee -a "${LOG_FILE}"
            fi
        fi
    fi

    if ! DEBIAN_FRONTEND=noninteractive apt-get install -y -qq speedtest 2>&1 | tee -a "${LOG_FILE}"; then
        if [[ -f "${sources_list}" ]]; then
            local codename_retry
            codename_retry="$(lsb_release -cs 2>/dev/null || echo "")"
            if [[ -n "${codename_retry}" && "${codename_retry}" != "jammy" ]]; then
                log_warn "Retrying with jammy repo..."
                sed -i "s/${codename_retry}/jammy/g" "${sources_list}"
                apt-get update -qq 2>&1 | tee -a "${LOG_FILE}"
                if ! DEBIAN_FRONTEND=noninteractive apt-get install -y -qq speedtest 2>&1 | tee -a "${LOG_FILE}"; then
                    log_error "Failed to install speedtest"
                    return 1
                fi
            else
                log_error "Failed to install speedtest"
                return 1
            fi
        else
            log_error "Failed to install speedtest"
            return 1
        fi
    fi

    log_info "Speedtest CLI installed successfully"
    return 0
}

is_ssh_hardened() {
    local expected_port="$1"

    local sshd_config
    sshd_config="$(sshd -T 2>/dev/null)" || return 1

    if ! echo "${sshd_config}" | grep -q "^permitrootlogin no"; then
        return 1
    fi

    if ! echo "${sshd_config}" | grep -q "^passwordauthentication no"; then
        return 1
    fi

    if ! echo "${sshd_config}" | grep -q "^port ${expected_port}"; then
        return 1
    fi

    return 0
}

is_ufw_configured() {
    local expected_port="$1"

    if ! ufw status | grep -q "Status: active"; then
        return 1
    fi

    if ! ufw status | grep -q "${expected_port}/tcp.*ALLOW"; then
        return 1
    fi

    return 0
}

is_fail2ban_configured() {
    if ! systemctl is-active fail2ban >/dev/null 2>&1; then
        return 1
    fi

    if ! fail2ban-client status 2>/dev/null | grep -q "sshd"; then
        return 1
    fi

    return 0
}

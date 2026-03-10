#!/usr/bin/env bash

set -euo pipefail

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    source "${SCRIPT_DIR}/lib/common.sh"
    source "${SCRIPT_DIR}/lib/validation.sh"
    source "${SCRIPT_DIR}/lib/config.sh"
    source "${SCRIPT_DIR}/lib/security.sh"
fi

run_ssh_key() {
    log_info "=== SSH Key Configuration ==="

    local username
    local ssh_key=""
    local key_file
    local generated=false

    if [[ "${AUTO_MODE}" == true ]]; then
        username="${_AUTO_CREATED_USERNAME}"
        if [[ -z "${username}" ]]; then
            log_warn "Auto mode: no user created, skipping SSH key setup"
            return 0
        fi
        key_file="/root/.ssh/${username}_ed25519"
        log_info "Generating Ed25519 key pair for ${username}"
        generate_ed25519_key "${key_file}" "${username}@$(hostname)"
        ssh_key="$(cat "${key_file}.pub")"
        generated=true
    else
        echo ""
        while true; do
            if [[ -n "${_AUTO_CREATED_USERNAME}" ]]; then
                read -r -p "Enter username to configure SSH key for [default: ${_AUTO_CREATED_USERNAME}]: " username
                if [[ -z "${username}" ]]; then
                    username="${_AUTO_CREATED_USERNAME}"
                fi
            else
                read -r -p "Enter username to configure SSH key for: " username
            fi

            if [[ -z "${username}" ]]; then
                echo "Username cannot be empty"
                continue
            fi

            if ! check_user_exists "${username}"; then
                echo "User '${username}' does not exist. Create the user first (--user)."
                continue
            fi

            break
        done

        key_file="/root/.ssh/${username}_ed25519"

        echo ""
        echo "SSH Public Key Configuration:"
        echo "  Option 1: Paste your existing SSH public key (ed25519 or RSA 4096+)"
        echo "  Option 2: Press Enter to auto-generate Ed25519 key pair"
        echo ""
        read -r -p "Paste SSH public key (or press Enter to generate): " ssh_key

        if [[ -z "${ssh_key}" ]]; then
            log_info "Generating Ed25519 key pair for ${username}"
            generate_ed25519_key "${key_file}" "${username}@$(hostname)"
            ssh_key="$(cat "${key_file}.pub")"
            generated=true
        else
            while true; do
                if validate_ssh_key "${ssh_key}"; then
                    log_info "SSH key accepted"
                    break
                else
                    echo ""
                    echo "Invalid SSH key. Requirements:"
                    echo "  - Must be Ed25519 or RSA 4096+ key"
                    echo "  - Format: ssh-ed25519 AAAA... comment"
                    echo ""
                    read -r -p "Paste valid SSH public key (or press Enter to generate): " ssh_key

                    if [[ -z "${ssh_key}" ]]; then
                        log_info "Generating Ed25519 key pair for ${username}"
                        generate_ed25519_key "${key_file}" "${username}@$(hostname)"
                        ssh_key="$(cat "${key_file}.pub")"
                        generated=true
                        break
                    fi
                fi
            done
        fi
    fi

    add_ssh_key_to_authorized_keys "${username}" "${ssh_key}"

    local fingerprint=""
    local temp_keyfile
    temp_keyfile="$(mktemp)"
    TEMP_FILES+=("${temp_keyfile}")
    echo "${ssh_key}" > "${temp_keyfile}"
    fingerprint="$(ssh-keygen -lf "${temp_keyfile}" 2>/dev/null || echo "unknown")"

    local user_home
    local key_source
    [[ "${generated}" == true ]] && key_source="generated" || key_source="provided"
    user_home="$(getent passwd "${username}" | cut -d: -f6)"
    log_change "SSH KEY ADDED: user=${username}, source=${key_source}, path=${user_home}/.ssh/authorized_keys, fingerprint=${fingerprint}"

    echo ""
    echo "=== SSH Key Configured ==="
    echo "  User:            ${username}"
    echo "  Fingerprint:     ${fingerprint}"
    echo "  authorized_keys: ${user_home}/.ssh/authorized_keys"

    if [[ "${generated}" == true ]]; then
        echo "  Private key: ${key_file}"
        echo ""
        echo "  IMPORTANT: Download the private key to your local machine:"
        echo "    scp root@your-server-ip:${key_file} ~/.ssh/"
        echo "    chmod 600 ~/.ssh/$(basename "${key_file}")"
    fi

    echo ""
    log_info "SSH key configured for ${username}"
    return 0
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_ssh_key
fi

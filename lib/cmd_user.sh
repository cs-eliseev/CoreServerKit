#!/usr/bin/env bash

set -euo pipefail

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    source "${SCRIPT_DIR}/lib/common.sh"
    source "${SCRIPT_DIR}/lib/validation.sh"
    source "${SCRIPT_DIR}/lib/config.sh"
    source "${SCRIPT_DIR}/lib/security.sh"
fi

generate_username() {
    local suffix
    suffix="$(tr -dc 'a-z0-9' < /dev/urandom | head -c 6)"
    echo "usr_${suffix}"
}

generate_password() {
    tr -dc 'A-Za-z0-9!@#$%&*' < /dev/urandom | head -c 16
    echo
}

run_create_user() {
    log_info "=== Create Administrative User ==="

    local default_username
    default_username="$(generate_username)"
    local default_password
    default_password="$(generate_password)"

    local username
    local password

    if [[ "${AUTO_MODE}" == true ]]; then
        username="${default_username}"
        password="${default_password}"
    else
        echo ""
        while true; do
            prompt_with_default "Enter username" "${default_username}" username

            if validate_username "${username}"; then
                break
            else
                echo "Invalid username. Requirements:"
                echo "  - Start with lowercase letter"
                echo "  - Only lowercase letters, numbers, dash, underscore"
                echo "  - Maximum 32 characters"
                echo "  - Cannot be 'root'"
                echo ""
            fi
        done

        if check_user_exists "${username}"; then
            log_warn "User ${username} already exists"
            echo ""
            echo "User ${username} already exists, skipping creation."
            return 0
        fi

        echo ""
        prompt_with_default "Enter password" "${default_password}" password

        echo ""
        echo "=== User Configuration ==="
        echo "  Username: ${username}"
        echo "  Password: ${password}"
        echo "  Groups:   sudo"
        echo ""

        if ! prompt_confirmation "Create user?"; then
            log_info "User creation cancelled"
            echo "Cancelled."
            return 0
        fi
    fi

    if check_user_exists "${username}"; then
        log_warn "User ${username} already exists, skipping creation."
        _AUTO_CREATED_USERNAME="${username}"
        return 0
    fi

    create_admin_user "${username}" "${password}"
    add_user_to_sudo "${username}"
    _AUTO_CREATED_USERNAME="${username}"
    log_change "USER CREATED: username=${username}, groups=sudo"

    echo ""
    echo "=== User Created ==="
    echo "  Username: ${username}"
    echo "  Password: ${password}"
    echo "  Sudo:     yes"
    echo ""
    echo "  IMPORTANT: Save these credentials securely!"
    echo ""

    log_info "User ${username} created with sudo privileges"
    return 0
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_create_user
fi

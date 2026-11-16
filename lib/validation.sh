#!/usr/bin/env bash

set -euo pipefail

validate_port() {
    local port="$1"

    if ! [[ "${port}" =~ ^[0-9]+$ ]]; then
        return 1
    fi

    if [[ "${port}" -lt 1024 || "${port}" -gt 65535 ]]; then
        return 1
    fi

    return 0
}

validate_username() {
    local username="$1"

    if ! [[ "${username}" =~ ^[a-z][a-z0-9_-]{0,31}$ ]]; then
        return 1
    fi

    if [[ "${username}" == "root" ]]; then
        return 1
    fi

    return 0
}

validate_ssh_key() {
    local ssh_key="$1"

    local temp_keyfile
    temp_keyfile="$(mktemp)"
    TEMP_FILES+=("${temp_keyfile}")

    echo "${ssh_key}" > "${temp_keyfile}"

    if ! ssh-keygen -lf "${temp_keyfile}" >/dev/null 2>&1; then
        return 1
    fi

    local key_info
    key_info="$(ssh-keygen -lf "${temp_keyfile}" 2>/dev/null)"

    if echo "${key_info}" | grep -q "ED25519"; then
        return 0
    fi

    if echo "${key_info}" | grep -q "RSA"; then
        local bits
        bits="$(echo "${key_info}" | awk '{print $1}')"
        if [[ "${bits}" -ge 4096 ]]; then
            return 0
        fi
    fi

    return 1
}

validate_domain() {
    local domain="$1"

    if [[ "${#domain}" -gt 253 ]]; then
        return 1
    fi

    if ! [[ "${domain}" =~ ^[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?\.[A-Za-z]{2,}$ ]]; then
        return 1
    fi

    if [[ "${domain}" == *..* ]]; then
        return 1
    fi

    return 0
}

validate_email() {
    local email="$1"

    if ! [[ "${email}" =~ ^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$ ]]; then
        return 1
    fi

    return 0
}

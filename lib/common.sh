#!/usr/bin/env bash
# shellcheck disable=SC2034

set -euo pipefail

readonly LOG_FILE="${LOG_FILE:-/var/log/server-init.log}"
readonly CHANGES_FILE="${CHANGES_FILE:-/var/log/server-init-changes.log}"

readonly COLOR_RESET='\033[0m'
readonly COLOR_RED='\033[0;31m'
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_YELLOW='\033[0;33m'
readonly COLOR_BLUE='\033[0;34m'

declare -a TEMP_FILES=()
AUTO_MODE=false
_AUTO_CREATED_USERNAME=""

log_message() {
    local severity="$1"
    local message="$2"
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"

    echo "[${timestamp}] [${severity}] ${message}" >> "${LOG_FILE}"

    local color="${COLOR_RESET}"
    case "${severity}" in
        INFO)  color="${COLOR_BLUE}" ;;
        ERROR) color="${COLOR_RED}" ;;
        WARN)  color="${COLOR_YELLOW}" ;;
    esac

    echo -e "${color}[${timestamp}] [${severity}] ${message}${COLOR_RESET}" >&2
}

log_change() {
    local message="$1"
    local timestamp
    timestamp="$(date '+%H:%M:%S')"
    echo "[${timestamp}] ${message}" >> "${CHANGES_FILE}"
}

begin_run_log() {
    local mode="${1:-interactive}"
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    local hostname
    hostname="$(hostname -f 2>/dev/null || hostname)"

    {
        echo ""
        printf '=%.0s' {1..80}
        echo ""
        echo "Run: ${timestamp} | Host: ${hostname} | PID: $$ | Mode: ${mode}"
        printf '=%.0s' {1..80}
        echo ""
    } >> "${CHANGES_FILE}"
}

log_info() {
    log_message "INFO" "$1"
}

log_error() {
    log_message "ERROR" "$1"
}

log_warn() {
    log_message "WARN" "$1"
}

die() {
    log_error "$1"
    exit 1
}

cleanup_temp_files() {
    local file
    for file in "${TEMP_FILES[@]}"; do
        if [[ -f "${file}" ]]; then
            rm -f "${file}"
        fi
    done
}

cleanup_on_exit() {
    cleanup_temp_files
    release_lock 2>/dev/null || true
}

trap cleanup_on_exit EXIT

wait_for_apt_lock() {
    local timeout=1200
    local timeout_min=$((timeout / 60))
    local waited=0
    local holder=""
    local proc_name=""
    local holder_pid=""

    while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 || fuser /var/lib/dpkg/lock >/dev/null 2>&1 || fuser /var/cache/apt/archives/lock 2>&1; do
        if [[ "${waited}" -ge "${timeout}" ]]; then
            log_error "Timed out waiting for apt lock after ${timeout}s (held by: ${holder} process: ${proc_name}, PID: ${holder_pid})"
            return 1
        fi
        if [[ "${waited}" -eq 0 ]]; then
            holder_pid=$(sudo fuser /var/lib/dpkg/lock-frontend 2>/dev/null | head -1)
            if [[ -z "$holder_pid" ]]; then
                holder_pid=$(sudo fuser /var/lib/dpkg/lock 2>/dev/null | head -1)
            fi
            if [[ -z "$holder_pid" ]]; then
                holder_pid=$(sudo fuser /var/cache/apt/archives/lock 2>/dev/null | head -1)
            fi
            proc_name=$(ps -p "${holder_pid}" -o comm= 2>/dev/null || echo "unknown")
            holder="$(fuser /var/lib/dpkg/lock-frontend 2>/dev/null | xargs -r ps -o comm= -p 2>/dev/null || echo "unknown")"
            holder_pid=$(sudo fuser /var/lib/dpkg/lock-frontend 2>/dev/null | head -1)
            proc_name=$(ps -p "${holder_pid}" -o comm= 2>/dev/null || echo "unknown")
            log_warn "Waiting for apt lock to be released. Will wait up to ${timeout_min} minutes. Lock held by: ${proc_name} (PID: ${holder_pid} held by: ${holder})"
        fi
        sleep 2
        waited=$((waited + 2))
    done

    return 0
}

check_root_privileges() {
    if [[ "${EUID}" -ne 0 ]]; then
        return 1
    fi
    return 0
}

check_distribution() {
    if [[ ! -f /etc/os-release ]]; then
        return 1
    fi

    # shellcheck source=/dev/null
    source /etc/os-release

    local os_id="${ID:-unknown}"

    case "${os_id}" in
        ubuntu|debian)
            DETECTED_OS="${os_id}"
            DETECTED_VERSION="${VERSION_ID:-unknown}"
            log_info "Detected: ${NAME} ${VERSION}"
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

check_network_connectivity() {
    if ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1; then
        return 0
    fi

    if ping -c 1 -W 2 1.1.1.1 >/dev/null 2>&1; then
        return 0
    fi

    return 1
}

check_required_commands() {
    local required_commands=(
        "sshd"
        "ssh-keygen"
        "useradd"
        "usermod"
        "apt-get"
    )

    local missing_commands=()
    local cmd

    for cmd in "${required_commands[@]}"; do
        if ! command -v "${cmd}" >/dev/null 2>&1; then
            missing_commands+=("${cmd}")
        fi
    done

    if [[ ${#missing_commands[@]} -gt 0 ]]; then
        log_error "Missing required commands: ${missing_commands[*]}"
        return 1
    fi

    log_info "All required commands found"
    return 0
}

readonly LOCK_FILE="/var/run/server-init.lock"

check_bash_version() {
    local major="${BASH_VERSINFO[0]:-0}"

    if [[ "${major}" -lt 4 ]]; then
        return 1
    fi

    log_info "Bash version: ${BASH_VERSION}"
    return 0
}

acquire_lock() {
    if [[ -f "${LOCK_FILE}" ]]; then
        local existing_pid
        existing_pid="$(cat "${LOCK_FILE}" 2>/dev/null)"

        if [[ -n "${existing_pid}" ]] && kill -0 "${existing_pid}" 2>/dev/null; then
            log_error "Another instance is running (PID: ${existing_pid})"
            return 1
        fi

        log_warn "Removing stale lock file (PID ${existing_pid} not running)"
        rm -f "${LOCK_FILE}"
    fi

    echo "$$" > "${LOCK_FILE}"
    return 0
}

release_lock() {
    rm -f "${LOCK_FILE}"
}

detect_selinux_apparmor() {
    if command -v getenforce >/dev/null 2>&1; then
        local selinux_status
        selinux_status="$(getenforce 2>/dev/null || echo "Unknown")"
        if [[ "${selinux_status}" == "Enforcing" ]]; then
            log_warn "SELinux is ENFORCING - custom SSH port may require semanage adjustments"
            log_warn "Run: semanage port -a -t ssh_port_t -p tcp <port>"
        elif [[ "${selinux_status}" == "Permissive" ]]; then
            log_warn "SELinux is PERMISSIVE - check audit logs for denials"
        fi
    fi

    if command -v aa-status >/dev/null 2>&1; then
        if aa-status --enabled 2>/dev/null; then
            log_info "AppArmor is active (should not affect SSH configuration)"
        fi
    fi

    return 0
}

prompt_with_default() {
    local prompt_msg="$1"
    local default_value="$2"
    local result_var="$3"
    local user_input

    read -r -p "${prompt_msg} [default: ${default_value}]: " user_input

    if [[ -z "${user_input}" ]]; then
        user_input="${default_value}"
    fi

    printf -v "${result_var}" '%s' "${user_input}"
    return 0
}

prompt_confirmation() {
    local message="${1:-Proceed?}"
    local response

    while true; do
        read -r -p "${message} [y/N]: " response

        case "${response}" in
            [yY]|[yY][eE][sS])
                return 0
                ;;
            [nN]|[nN][oO]|"")
                return 1
                ;;
            *)
                echo "Please answer yes or no"
                ;;
        esac
    done
}

check_reboot_required() {
    if [[ -f /var/run/reboot-required ]]; then
        return 0
    fi
    return 1
}

display_reboot_notification() {
    if check_reboot_required; then
        echo ""
        echo "WARNING: SYSTEM REBOOT REQUIRED"
        echo ""
        echo "Package updates require a system reboot."
        echo "Please reboot the server when convenient:"
        echo "  sudo reboot"
        echo ""
        log_warn "System reboot required after package updates"
    fi
    return 0
}

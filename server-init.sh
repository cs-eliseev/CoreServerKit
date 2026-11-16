#!/usr/bin/env bash

set -euo pipefail

readonly SCRIPT_VERSION="1.0.0"
readonly SCRIPT_NAME="CoreServerKit Server Initialization"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR

case "${1:-}" in
    -h|--help)
        cat <<'HELP'
CoreServerKit Server Initialization Script v1.0.0

USAGE:
    sudo ./server-init.sh [OPTION]

DESCRIPTION:
    Automated security hardening for Ubuntu/Debian servers.
    Without options runs full cycle: user -> ssh-key -> security -> speedtest -> update -> cert -> verify.

OPTIONS:
    -u, --user        Create administrative user with sudo privileges
    -k, --ssh-key     Add or generate SSH key for a user
    -s, --security    Security hardening (SSH, UFW firewall, fail2ban)
    -t, --speedtest   Install Ookla Speedtest CLI
    -U, --update      System update (apt update + upgrade)
    -c, --cert        Issue Let's Encrypt SSL certificate for a domain (nginx + certbot)
    -V, --verify      Verify current configuration
    -d, --defaults    Full cycle with all defaults, no prompts
    -h, --help        Display this help message
    -v, --version     Display version information

EXAMPLES:
    sudo ./server-init.sh              # Full cycle (interactive)
    sudo ./server-init.sh --defaults   # Full cycle, no prompts
    sudo ./server-init.sh --user       # Create user only
    sudo ./server-init.sh --security   # Security hardening only
    sudo ./server-init.sh --verify     # Verify current state
    sudo ./server-init.sh --cert       # Issue SSL certificate for a domain
    sudo CERT_DOMAIN=example.com CERT_EMAIL=admin@example.com ./server-init.sh --defaults

ENVIRONMENT:
    CERT_DOMAIN       Domain for the SSL certificate (required for cert step in --defaults)
    CERT_EMAIL        Email for Let's Encrypt expiry notices (optional)

LOG FILE:
    /var/log/server-init.log
HELP
        exit 0
        ;;
    -v|--version)
        echo "${SCRIPT_NAME} v${SCRIPT_VERSION}"
        exit 0
        ;;
esac

source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/validation.sh"
source "${SCRIPT_DIR}/lib/config.sh"
source "${SCRIPT_DIR}/lib/security.sh"
source "${SCRIPT_DIR}/lib/cert.sh"

source "${SCRIPT_DIR}/lib/cmd_user.sh"
source "${SCRIPT_DIR}/lib/cmd_ssh-key.sh"
source "${SCRIPT_DIR}/lib/cmd_security.sh"
source "${SCRIPT_DIR}/lib/cmd_speedtest.sh"
source "${SCRIPT_DIR}/lib/cmd_update.sh"
source "${SCRIPT_DIR}/lib/cmd_cert.sh"
source "${SCRIPT_DIR}/lib/cmd_verify.sh"

startup_checks() {
    check_bash_version || die "Bash 4.0+ required (current: ${BASH_VERSION})"
    acquire_lock || die "Another instance of server-init.sh is already running"

    log_info "Checking system requirements..."
    check_root_privileges || die "This script must be run as root"
    check_distribution || die "Unsupported operating system (requires Ubuntu or Debian)"
    check_network_connectivity || die "No internet connectivity"
    check_required_commands || die "Missing required commands"
    detect_selinux_apparmor
}

run_full_cycle() {
    log_info "${SCRIPT_NAME} v${SCRIPT_VERSION}"
    log_info "Starting full server initialization cycle..."

    echo ""
    echo "=== ${SCRIPT_NAME} v${SCRIPT_VERSION} ==="
    echo "Running full initialization cycle..."
    echo ""

    if [[ "${AUTO_MODE}" == true ]] || prompt_confirmation "Create sudo user?"; then
        run_create_user
    fi

    if [[ "${AUTO_MODE}" == true ]] || prompt_confirmation "Configure SSH key?"; then
        run_ssh_key
    fi

    if [[ "${AUTO_MODE}" == true ]] || prompt_confirmation "Apply security hardening?"; then
        run_security
    fi

    if [[ "${AUTO_MODE}" == true ]] || prompt_confirmation "Install Speedtest CLI?"; then
        run_speedtest
    fi

    if [[ "${AUTO_MODE}" == true ]] || prompt_confirmation "Update system packages?"; then
        run_update
    fi

    if [[ "${AUTO_MODE}" == true ]] || prompt_confirmation "Issue SSL certificate for a domain (nginx + Let's Encrypt)?"; then
        run_cert
    fi

    run_verify "all"

    display_reboot_notification

    log_info "Full server initialization completed!"
}

main() {
    case "${1:-}" in
        -u|--user)
            startup_checks
            begin_run_log "user"
            run_create_user
            run_verify "user"
            ;;
        -k|--ssh-key)
            startup_checks
            begin_run_log "ssh-key"
            run_ssh_key
            run_verify "ssh-key"
            ;;
        -s|--security)
            startup_checks
            begin_run_log "security"
            if ! prompt_confirmation "Apply security hardening?"; then
                echo "Cancelled."
                exit 0
            fi
            run_security
            run_verify "security"
            ;;
        -t|--speedtest)
            startup_checks
            begin_run_log "speedtest"
            run_speedtest
            run_verify "speedtest"
            ;;
        -U|--update)
            startup_checks
            begin_run_log "update"
            run_update
            run_verify "update"
            ;;
        -c|--cert)
            startup_checks
            begin_run_log "cert"
            run_cert
            run_verify "cert"
            ;;
        -V|--verify)
            startup_checks
            begin_run_log "verify"
            run_verify "all"
            ;;
        -d|--defaults)
            startup_checks
            AUTO_MODE=true
            begin_run_log "defaults"
            run_full_cycle
            ;;
        "")
            startup_checks
            begin_run_log "full-cycle"
            run_full_cycle
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information."
            exit 1
            ;;
    esac
}

main "$@"

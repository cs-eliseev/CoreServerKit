#!/usr/bin/env bats
#
# Integration tests for User Story 4: fail2ban Intrusion Prevention
#
# Test coverage:
# - fail2ban installation
# - SSH jail configuration
# - Service status verification
#
# WARNING: These tests modify system configuration!
# Only run in isolated test environments
#
# Run: sudo bats tests/integration/test_us4_fail2ban.bats

setup() {
    # Verify running as root
    if [[ "${EUID}" -ne 0 ]]; then
        skip "Integration tests require root privileges"
    fi

    # Load libraries
    source "${BATS_TEST_DIRNAME}/../../lib/common.sh"
    source "${BATS_TEST_DIRNAME}/../../lib/security.sh"

    export LOG_FILE="/tmp/test-server-init.log"
}

teardown() {
    rm -f /tmp/test-server-init.log
}

@test "US4: install_fail2ban installs package" {
    if ! type install_fail2ban >/dev/null 2>&1; then
        skip "install_fail2ban not yet implemented"
    fi

    install_fail2ban

    # Verify fail2ban installed
    command -v fail2ban-client
}

@test "US4: configure_ssh_jail creates jail.local" {
    if ! type configure_ssh_jail >/dev/null 2>&1; then
        skip "configure_ssh_jail not yet implemented"
    fi

    configure_ssh_jail 10122

    # Verify jail.local exists
    [ -f /etc/fail2ban/jail.local ]
}

@test "US4: SSH jail configured with correct settings" {
    if ! type configure_ssh_jail >/dev/null 2>&1; then
        skip "configure_ssh_jail not yet implemented"
    fi

    configure_ssh_jail 10122

    # Verify SSH jail section exists
    grep -q "\[sshd\]" /etc/fail2ban/jail.local

    # Verify key settings
    grep -q "enabled.*=.*true" /etc/fail2ban/jail.local
    grep -q "port.*=.*10122" /etc/fail2ban/jail.local
    grep -q "maxretry.*=.*5" /etc/fail2ban/jail.local
    grep -q "bantime.*=.*600" /etc/fail2ban/jail.local
}

@test "US4: fail2ban service is active" {
    if ! type install_fail2ban >/dev/null 2>&1 || ! type reload_fail2ban >/dev/null 2>&1; then
        skip "Functions not yet implemented"
    fi

    install_fail2ban
    reload_fail2ban

    # Verify service active
    systemctl is-active fail2ban
}

@test "US4: verify_fail2ban_status checks sshd jail" {
    if ! type verify_fail2ban_status >/dev/null 2>&1; then
        skip "verify_fail2ban_status not yet implemented"
    fi

    run verify_fail2ban_status
    [ "$status" -eq 0 ]
}

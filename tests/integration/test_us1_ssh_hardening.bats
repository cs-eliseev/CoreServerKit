#!/usr/bin/env bats
#
# Integration tests for User Story 1: Basic Server Hardening
#
# Test coverage:
# - Complete SSH hardening workflow (T028)
# - UFW firewall configuration (T029)
#
# WARNING: These tests modify system configuration!
# Only run in isolated test environments (containers, VMs)
#
# Run: sudo bats tests/integration/test_us1_ssh_hardening.bats

# Setup test environment
setup() {
    # Verify running as root
    if [[ "${EUID}" -ne 0 ]]; then
        skip "Integration tests require root privileges"
    fi

    # Load libraries
    source "${BATS_TEST_DIRNAME}/../../lib/common.sh"
    source "${BATS_TEST_DIRNAME}/../../lib/validation.sh"
    source "${BATS_TEST_DIRNAME}/../../lib/config.sh"
    source "${BATS_TEST_DIRNAME}/../../lib/security.sh"

    # Override LOG_FILE to prevent writing to system log during tests
    export LOG_FILE="/tmp/test-server-init.log"

    # Backup original SSH config
    if [[ -f /etc/ssh/sshd_config ]]; then
        cp /etc/ssh/sshd_config /etc/ssh/sshd_config.test_backup
    fi
}

# Cleanup after tests
teardown() {
    # Restore original SSH config
    if [[ -f /etc/ssh/sshd_config.test_backup ]]; then
        mv /etc/ssh/sshd_config.test_backup /etc/ssh/sshd_config
        systemctl restart sshd || true
    fi

    # Disable UFW if it was enabled by tests
    ufw --force disable || true

    rm -f /tmp/test-server-init.log
}

# ============================================================================
# SSH Hardening Integration Tests (T028)
# ============================================================================

@test "SSH hardening: configure_ssh_hardening creates backup before modification" {
    # Skip if configure_ssh_hardening not implemented
    if ! type configure_ssh_hardening >/dev/null 2>&1; then
        skip "configure_ssh_hardening not yet implemented"
    fi

    local backup_count_before
    backup_count_before=$(find /etc/ssh -name "sshd_config.*.bak" | wc -l)

    configure_ssh_hardening 10122

    local backup_count_after
    backup_count_after=$(find /etc/ssh -name "sshd_config.*.bak" | wc -l)

    [ "$backup_count_after" -gt "$backup_count_before" ]
}

@test "SSH hardening: validates SSH config syntax before applying" {
    # Skip if validate_sshd_config not implemented
    if ! type validate_sshd_config >/dev/null 2>&1; then
        skip "validate_sshd_config not yet implemented"
    fi

    # Current config should be valid
    run validate_sshd_config /etc/ssh/sshd_config
    [ "$status" -eq 0 ]
}

@test "SSH hardening: disables root login" {
    # Skip if configure_ssh_hardening not implemented
    if ! type configure_ssh_hardening >/dev/null 2>&1; then
        skip "configure_ssh_hardening not yet implemented"
    fi

    configure_ssh_hardening 10122

    # Check effective config
    local permit_root
    permit_root=$(sshd -T | grep "^permitrootlogin" | awk '{print $2}')
    [ "$permit_root" = "no" ]
}

@test "SSH hardening: disables password authentication" {
    # Skip if configure_ssh_hardening not implemented
    if ! type configure_ssh_hardening >/dev/null 2>&1; then
        skip "configure_ssh_hardening not yet implemented"
    fi

    configure_ssh_hardening 10122

    # Check effective config
    local password_auth
    password_auth=$(sshd -T | grep "^passwordauthentication" | awk '{print $2}')
    [ "$password_auth" = "no" ]
}

@test "SSH hardening: configures custom port" {
    # Skip if configure_ssh_hardening not implemented
    if ! type configure_ssh_hardening >/dev/null 2>&1; then
        skip "configure_ssh_hardening not yet implemented"
    fi

    configure_ssh_hardening 10122

    # Check effective config
    local ssh_port
    ssh_port=$(sshd -T | grep "^port" | awk '{print $2}')
    [ "$ssh_port" = "10122" ]
}

@test "SSH hardening: SSH service restarts successfully" {
    # Skip if restart_ssh_service not implemented
    if ! type restart_ssh_service >/dev/null 2>&1; then
        skip "restart_ssh_service not yet implemented"
    fi

    run restart_ssh_service
    [ "$status" -eq 0 ]

    # Verify service is active
    systemctl is-active sshd
}

@test "SSH hardening: SSH listens on configured port after restart" {
    # Skip if configure_ssh_hardening and verify_ssh_port not implemented
    if ! type configure_ssh_hardening >/dev/null 2>&1 || ! type verify_ssh_port >/dev/null 2>&1; then
        skip "configure_ssh_hardening or verify_ssh_port not yet implemented"
    fi

    configure_ssh_hardening 10122
    restart_ssh_service

    run verify_ssh_port 10122
    [ "$status" -eq 0 ]
}

# ============================================================================
# UFW Firewall Integration Tests (T029)
# ============================================================================

@test "UFW: configure_ufw_defaults sets deny incoming policy" {
    # Skip if configure_ufw_defaults not implemented
    if ! type configure_ufw_defaults >/dev/null 2>&1; then
        skip "configure_ufw_defaults not yet implemented"
    fi

    configure_ufw_defaults

    # Check default policy
    local incoming_policy
    incoming_policy=$(ufw status verbose | grep "Default:" | grep -o "deny (incoming)")
    [ -n "$incoming_policy" ]
}

@test "UFW: configure_ufw_defaults sets allow outgoing policy" {
    # Skip if configure_ufw_defaults not implemented
    if ! type configure_ufw_defaults >/dev/null 2>&1; then
        skip "configure_ufw_defaults not yet implemented"
    fi

    configure_ufw_defaults

    # Check default policy
    local outgoing_policy
    outgoing_policy=$(ufw status verbose | grep "Default:" | grep -o "allow (outgoing)")
    [ -n "$outgoing_policy" ]
}

@test "UFW: allow_ssh_port adds correct firewall rule" {
    # Skip if allow_ssh_port not implemented
    if ! type allow_ssh_port >/dev/null 2>&1; then
        skip "allow_ssh_port not yet implemented"
    fi

    allow_ssh_port 10122

    # Verify rule was added
    ufw status | grep "10122/tcp.*ALLOW"
}

@test "UFW: enable_ufw activates firewall" {
    # Skip if enable_ufw not implemented
    if ! type enable_ufw >/dev/null 2>&1; then
        skip "enable_ufw not yet implemented"
    fi

    # Ensure SSH is allowed before enabling
    ufw allow 22/tcp

    enable_ufw

    # Verify firewall is active
    local status
    status=$(ufw status | head -1 | grep -o "active")
    [ "$status" = "active" ]
}

@test "UFW: verify_ufw_status confirms firewall is active" {
    # Skip if verify_ufw_status not implemented
    if ! type verify_ufw_status >/dev/null 2>&1; then
        skip "verify_ufw_status not yet implemented"
    fi

    # Enable firewall first
    ufw allow 22/tcp
    ufw --force enable

    run verify_ufw_status
    [ "$status" -eq 0 ]
}

@test "UFW: complete workflow - defaults, allow SSH, enable, verify" {
    # Skip if any function not implemented
    if ! type configure_ufw_defaults >/dev/null 2>&1 || \
       ! type allow_ssh_port >/dev/null 2>&1 || \
       ! type enable_ufw >/dev/null 2>&1 || \
       ! type verify_ufw_status >/dev/null 2>&1; then
        skip "UFW functions not yet fully implemented"
    fi

    # Execute complete workflow
    configure_ufw_defaults
    allow_ssh_port 10122
    enable_ufw

    # Verify result
    run verify_ufw_status
    [ "$status" -eq 0 ]

    # Verify SSH port is allowed
    ufw status | grep "10122/tcp.*ALLOW"
}

# ============================================================================
# End-to-End User Story 1 Test
# ============================================================================

@test "US1 E2E: complete server hardening workflow" {
    # Skip if any required function not implemented
    if ! type configure_ssh_hardening >/dev/null 2>&1 || \
       ! type configure_ufw_defaults >/dev/null 2>&1 || \
       ! type allow_ssh_port >/dev/null 2>&1 || \
       ! type enable_ufw >/dev/null 2>&1; then
        skip "Server hardening functions not yet fully implemented"
    fi

    local test_port=10122

    # Step 1: Harden SSH
    configure_ssh_hardening "$test_port"
    restart_ssh_service

    # Step 2: Configure firewall
    configure_ufw_defaults
    allow_ssh_port "$test_port"
    enable_ufw

    # Verify outcomes
    # - SSH port changed
    local ssh_port
    ssh_port=$(sshd -T | grep "^port" | awk '{print $2}')
    [ "$ssh_port" = "$test_port" ]

    # - Root login disabled
    local permit_root
    permit_root=$(sshd -T | grep "^permitrootlogin" | awk '{print $2}')
    [ "$permit_root" = "no" ]

    # - Password auth disabled
    local password_auth
    password_auth=$(sshd -T | grep "^passwordauthentication" | awk '{print $2}')
    [ "$password_auth" = "no" ]

    # - Firewall active
    ufw status | grep -q "Status: active"

    # - SSH port allowed in firewall
    ufw status | grep "$test_port/tcp.*ALLOW"
}

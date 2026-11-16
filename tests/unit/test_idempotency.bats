#!/usr/bin/env bats
#
# Unit tests for idempotency detection functions
#
# Test coverage:
# - is_ssh_hardened()
# - is_ufw_configured()
# - is_fail2ban_configured()
# - check_port_in_use()
#
# Run: bats tests/unit/test_idempotency.bats

setup() {
    source "${BATS_TEST_DIRNAME}/../../lib/common.sh"
    source "${BATS_TEST_DIRNAME}/../../lib/validation.sh"
    source "${BATS_TEST_DIRNAME}/../../lib/security.sh"

    export LOG_FILE="/tmp/test-server-init.log"
}

teardown() {
    rm -f /tmp/test-server-init.log
}

# ============================================================================
# check_port_in_use() tests (T108)
# ============================================================================

@test "check_port_in_use: detects port 22 in use (SSH default)" {
    # Port 22 is typically in use on systems with SSH
    if ! ss -tlnp 2>/dev/null | grep -q ":22 "; then
        skip "Port 22 not in use on this system"
    fi

    run check_port_in_use "22"
    [ "$status" -eq 0 ]
}

@test "check_port_in_use: reports unused high port as free" {
    # Port 59999 should typically not be in use
    run check_port_in_use "59999"
    [ "$status" -eq 1 ]
}

# ============================================================================
# is_ssh_hardened() tests (T108)
# ============================================================================

@test "is_ssh_hardened: function exists" {
    type is_ssh_hardened
}

@test "is_ssh_hardened: returns 1 for default SSH config" {
    # Default SSH config has root login enabled and port 22
    # This test checks that our detection works on an unhardened system
    if ! command -v sshd >/dev/null 2>&1; then
        skip "sshd not installed"
    fi

    # Port 99999 is unlikely to be configured
    run is_ssh_hardened "99999"
    [ "$status" -eq 1 ]
}

# ============================================================================
# is_ufw_configured() tests (T108)
# ============================================================================

@test "is_ufw_configured: function exists" {
    type is_ufw_configured
}

# ============================================================================
# is_fail2ban_configured() tests (T108)
# ============================================================================

@test "is_fail2ban_configured: function exists" {
    type is_fail2ban_configured
}

# ============================================================================
# detect_selinux_apparmor() tests
# ============================================================================

@test "detect_selinux_apparmor: function exists and runs" {
    run detect_selinux_apparmor
    [ "$status" -eq 0 ]
}

# ============================================================================
# display_help() tests
# ============================================================================

@test "display_help: outputs help text" {
    run display_help
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "USAGE"
    echo "$output" | grep -q "DESCRIPTION"
}

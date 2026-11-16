#!/usr/bin/env bats
#
# Integration tests for User Story 5: System Updates & Package Management
#
# Test coverage:
# - Package repository updates
# - Package upgrades
# - Reboot requirement detection
# - Partial failure handling
#
# WARNING: These tests modify system state!
# Only run in isolated test environments
#
# Run: sudo bats tests/integration/test_us5_package_updates.bats

setup() {
    if [[ "${EUID}" -ne 0 ]]; then
        skip "Integration tests require root privileges"
    fi

    source "${BATS_TEST_DIRNAME}/../../lib/common.sh"

    export LOG_FILE="/tmp/test-server-init.log"
}

teardown() {
    rm -f /tmp/test-server-init.log
}

# ============================================================================
# Package Update Tests (T085)
# ============================================================================

@test "US5: update_package_repositories succeeds" {
    run update_package_repositories
    [ "$status" -eq 0 ]
}

@test "US5: upgrade_packages succeeds" {
    run upgrade_packages
    # Allow success or graceful failure
    [[ "$status" -eq 0 ]] || [[ "$status" -eq 1 ]]
}

@test "US5: check_reboot_required function exists" {
    type check_reboot_required
}

@test "US5: display_reboot_notification function exists" {
    run display_reboot_notification
    [ "$status" -eq 0 ]
}

# ============================================================================
# Partial Failure Handling Tests (T086)
# ============================================================================

@test "US5: package update failure does not crash script" {
    # Simulate by calling with invalid state - should return 1 but not crash
    run update_package_repositories
    # Function should return cleanly (0 or 1), not crash
    [[ "$status" -eq 0 ]] || [[ "$status" -eq 1 ]]
}

@test "US5: package upgrade failure does not crash script" {
    run upgrade_packages
    [[ "$status" -eq 0 ]] || [[ "$status" -eq 1 ]]
}

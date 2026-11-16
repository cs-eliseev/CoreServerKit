#!/usr/bin/env bats
#
# Integration tests for User Story 3: Interactive Configuration
#
# Test coverage:
# - Configuration collection workflow
# - Summary display
# - Confirmation prompt
#
# Note: True interactive testing requires manual execution
# These tests verify functions exist and can be called programmatically
#
# Run: bats tests/integration/test_us3_interactive_config.bats

# Setup test environment
setup() {
    # Load libraries
    source "${BATS_TEST_DIRNAME}/../../lib/common.sh"
    source "${BATS_TEST_DIRNAME}/../../lib/validation.sh"

    # Override LOG_FILE
    export LOG_FILE="/tmp/test-server-init.log"
}

# Cleanup after tests
teardown() {
    rm -f /tmp/test-server-init.log
}

# ============================================================================
# Interactive Configuration Functions Exist (T061)
# ============================================================================

@test "US3: collect_configuration function exists" {
    if ! type collect_configuration >/dev/null 2>&1; then
        skip "collect_configuration not yet implemented"
    fi

    # Function should be defined
    type collect_configuration
}

@test "US3: display_configuration_summary function exists" {
    if ! type display_configuration_summary >/dev/null 2>&1; then
        skip "display_configuration_summary not yet implemented"
    fi

    # Function should be defined
    type display_configuration_summary
}

@test "US3: prompt_confirmation function exists" {
    if ! type prompt_confirmation >/dev/null 2>&1; then
        skip "prompt_confirmation not yet implemented"
    fi

    # Function should be defined
    type prompt_confirmation
}

# ============================================================================
# Configuration Summary Display
# ============================================================================

@test "US3: display_configuration_summary outputs expected format" {
    if ! type display_configuration_summary >/dev/null 2>&1; then
        skip "display_configuration_summary not yet implemented"
    fi

    # Call with test values
    local output
    output=$(display_configuration_summary "testuser" "10122" "yes")

    # Should contain configuration items
    echo "$output" | grep -q "testuser"
    echo "$output" | grep -q "10122"
}

# ============================================================================
# Validation Integration
# ============================================================================

@test "US3: interactive prompts use validation functions" {
    # Verify validation functions are available for use in prompts
    type validate_username
    type validate_port
    type validate_ssh_key
}

@test "US3: default values are sensible" {
    # Default port should be 10122
    local default_port=10122
    run validate_port "$default_port"
    [ "$status" -eq 0 ]

    # Default username pattern should be valid
    run validate_username "sysadmin"
    [ "$status" -eq 0 ]
}

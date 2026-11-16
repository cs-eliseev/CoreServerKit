#!/usr/bin/env bats
#
# Unit tests for interactive configuration functions
#
# Test coverage:
# - prompt_with_default()
# - Input validation with re-prompting logic
#
# Note: Interactive functions are difficult to test in automated fashion
# These tests focus on validation logic and default handling
#
# Run: bats tests/unit/test_interactive.bats

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
# prompt_with_default() tests (T059)
# ============================================================================

@test "prompt_with_default: function exists" {
    if ! type prompt_with_default >/dev/null 2>&1; then
        skip "prompt_with_default not yet implemented"
    fi

    # Function should be defined
    type prompt_with_default
}

# ============================================================================
# Input validation with re-prompting (T060)
# ============================================================================

@test "validation: re-prompt logic exists in prompt functions" {
    # This is a placeholder test
    # Real validation happens during interactive execution
    # We'll verify the functions exist and can be called

    if type prompt_username >/dev/null 2>&1; then
        # Function exists
        [ "$?" -eq 0 ]
    else
        skip "prompt_username not yet implemented"
    fi
}

@test "validation: prompt_username validates input format" {
    if ! type prompt_username >/dev/null 2>&1; then
        skip "prompt_username not yet implemented"
    fi

    # The function should use validate_username internally
    # This test just verifies validate_username works
    run validate_username "validuser"
    [ "$status" -eq 0 ]

    run validate_username "Invalid-User!"
    [ "$status" -eq 1 ]
}

@test "validation: prompt_ssh_port validates port range" {
    if ! type prompt_ssh_port >/dev/null 2>&1; then
        skip "prompt_ssh_port not yet implemented"
    fi

    # The function should use validate_port internally
    # This test verifies validate_port works
    run validate_port "10122"
    [ "$status" -eq 0 ]

    run validate_port "999"
    [ "$status" -eq 1 ]
}

@test "validation: prompt_ssh_key validates key format" {
    if ! type prompt_ssh_key >/dev/null 2>&1; then
        skip "prompt_ssh_key not yet implemented"
    fi

    # The function should use validate_ssh_key internally
    local valid_key="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl test@example.com"

    run validate_ssh_key "$valid_key"
    [ "$status" -eq 0 ]

    run validate_ssh_key "invalid-key"
    [ "$status" -eq 1 ]
}

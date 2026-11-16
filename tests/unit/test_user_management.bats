#!/usr/bin/env bats
#
# Unit tests for user management functions
#
# Test coverage:
# - check_user_exists()
# - create_admin_user()
# - add_user_to_sudo()
# - setup_user_ssh_directory()
#
# Run: bats tests/unit/test_user_management.bats

# Setup test environment
setup() {
    # Load libraries
    source "${BATS_TEST_DIRNAME}/../../lib/common.sh"
    source "${BATS_TEST_DIRNAME}/../../lib/security.sh"

    # Override LOG_FILE
    export LOG_FILE="/tmp/test-server-init.log"

    # Create test directory
    export TEST_DIR="/tmp/test-user-mgmt-$$"
    mkdir -p "$TEST_DIR"
}

# Cleanup after tests
teardown() {
    rm -rf "$TEST_DIR"
    rm -f /tmp/test-server-init.log
}

# ============================================================================
# check_user_exists() tests (T046)
# ============================================================================

@test "check_user_exists: returns 0 for existing user (root)" {
    # Skip if check_user_exists not implemented
    if ! type check_user_exists >/dev/null 2>&1; then
        skip "check_user_exists not yet implemented"
    fi

    run check_user_exists "root"
    [ "$status" -eq 0 ]
}

@test "check_user_exists: returns 1 for non-existent user" {
    if ! type check_user_exists >/dev/null 2>&1; then
        skip "check_user_exists not yet implemented"
    fi

    run check_user_exists "nonexistentuser12345"
    [ "$status" -eq 1 ]
}

# ============================================================================
# setup_user_ssh_directory() tests (T046)
# ============================================================================

@test "setup_user_ssh_directory: creates .ssh directory" {
    if ! type setup_user_ssh_directory >/dev/null 2>&1; then
        skip "setup_user_ssh_directory not yet implemented"
    fi

    local test_home="${TEST_DIR}/test_home"
    mkdir -p "$test_home"

    # Mock the user home directory
    setup_user_ssh_directory "$test_home"

    # Verify .ssh directory created
    [ -d "${test_home}/.ssh" ]
}

@test "setup_user_ssh_directory: sets correct permissions (700)" {
    if ! type setup_user_ssh_directory >/dev/null 2>&1; then
        skip "setup_user_ssh_directory not yet implemented"
    fi

    local test_home="${TEST_DIR}/test_home"
    mkdir -p "$test_home"

    setup_user_ssh_directory "$test_home"

    # Check permissions are 700
    local perms
    perms=$(stat -c "%a" "${test_home}/.ssh")
    [ "$perms" = "700" ]
}

@test "setup_user_ssh_directory: idempotent (safe to run multiple times)" {
    if ! type setup_user_ssh_directory >/dev/null 2>&1; then
        skip "setup_user_ssh_directory not yet implemented"
    fi

    local test_home="${TEST_DIR}/test_home"
    mkdir -p "$test_home"

    # Run twice
    setup_user_ssh_directory "$test_home"
    run setup_user_ssh_directory "$test_home"

    # Should succeed both times
    [ "$status" -eq 0 ]
    [ -d "${test_home}/.ssh" ]
}

# ============================================================================
# generate_ed25519_key() tests (T046)
# ============================================================================

@test "generate_ed25519_key: creates key pair" {
    if ! type generate_ed25519_key >/dev/null 2>&1; then
        skip "generate_ed25519_key not yet implemented"
    fi

    local key_file="${TEST_DIR}/test_key"

    generate_ed25519_key "$key_file" "test@example.com"

    # Verify private and public keys exist
    [ -f "$key_file" ]
    [ -f "${key_file}.pub" ]
}

@test "generate_ed25519_key: creates Ed25519 key type" {
    if ! type generate_ed25519_key >/dev/null 2>&1; then
        skip "generate_ed25519_key not yet implemented"
    fi

    local key_file="${TEST_DIR}/test_key"

    generate_ed25519_key "$key_file" "test@example.com"

    # Verify key type
    local key_type
    key_type=$(ssh-keygen -lf "${key_file}.pub" | grep -o "ED25519")
    [ "$key_type" = "ED25519" ]
}

@test "generate_ed25519_key: sets correct private key permissions (600)" {
    if ! type generate_ed25519_key >/dev/null 2>&1; then
        skip "generate_ed25519_key not yet implemented"
    fi

    local key_file="${TEST_DIR}/test_key"

    generate_ed25519_key "$key_file" "test@example.com"

    # Check private key permissions
    local perms
    perms=$(stat -c "%a" "$key_file")
    [ "$perms" = "600" ]
}

@test "generate_ed25519_key: sets correct public key permissions (644)" {
    if ! type generate_ed25519_key >/dev/null 2>&1; then
        skip "generate_ed25519_key not yet implemented"
    fi

    local key_file="${TEST_DIR}/test_key"

    generate_ed25519_key "$key_file" "test@example.com"

    # Check public key permissions
    local perms
    perms=$(stat -c "%a" "${key_file}.pub")
    [ "$perms" = "644" ]
}

# ============================================================================
# add_ssh_key_to_authorized_keys() tests (T046)
# ============================================================================

@test "add_ssh_key_to_authorized_keys: creates authorized_keys file" {
    if ! type add_ssh_key_to_authorized_keys >/dev/null 2>&1; then
        skip "add_ssh_key_to_authorized_keys not yet implemented"
    fi

    local ssh_dir="${TEST_DIR}/.ssh"
    mkdir -p "$ssh_dir"

    local test_key="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl test@example.com"

    add_ssh_key_to_authorized_keys "$ssh_dir" "$test_key"

    # Verify authorized_keys created
    [ -f "${ssh_dir}/authorized_keys" ]
}

@test "add_ssh_key_to_authorized_keys: sets correct permissions (600)" {
    if ! type add_ssh_key_to_authorized_keys >/dev/null 2>&1; then
        skip "add_ssh_key_to_authorized_keys not yet implemented"
    fi

    local ssh_dir="${TEST_DIR}/.ssh"
    mkdir -p "$ssh_dir"

    local test_key="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl test@example.com"

    add_ssh_key_to_authorized_keys "$ssh_dir" "$test_key"

    # Check permissions
    local perms
    perms=$(stat -c "%a" "${ssh_dir}/authorized_keys")
    [ "$perms" = "600" ]
}

@test "add_ssh_key_to_authorized_keys: appends key to file" {
    if ! type add_ssh_key_to_authorized_keys >/dev/null 2>&1; then
        skip "add_ssh_key_to_authorized_keys not yet implemented"
    fi

    local ssh_dir="${TEST_DIR}/.ssh"
    mkdir -p "$ssh_dir"

    local test_key="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl test@example.com"

    add_ssh_key_to_authorized_keys "$ssh_dir" "$test_key"

    # Verify key is in file
    grep -q "$test_key" "${ssh_dir}/authorized_keys"
}

@test "add_ssh_key_to_authorized_keys: supports multiple keys" {
    if ! type add_ssh_key_to_authorized_keys >/dev/null 2>&1; then
        skip "add_ssh_key_to_authorized_keys not yet implemented"
    fi

    local ssh_dir="${TEST_DIR}/.ssh"
    mkdir -p "$ssh_dir"

    local key1="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl key1@example.com"
    local key2="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAnotherkeydatahere123456789012345678901234567890 key2@example.com"

    add_ssh_key_to_authorized_keys "$ssh_dir" "$key1"
    add_ssh_key_to_authorized_keys "$ssh_dir" "$key2"

    # Verify both keys present
    grep -q "key1@example.com" "${ssh_dir}/authorized_keys"
    grep -q "key2@example.com" "${ssh_dir}/authorized_keys"

    # Verify file has 2 lines
    local line_count
    line_count=$(wc -l < "${ssh_dir}/authorized_keys")
    [ "$line_count" -eq 2 ]
}

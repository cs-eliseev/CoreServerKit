#!/usr/bin/env bats
#
# Integration tests for User Story 2: User Management & Access Control
#
# Test coverage:
# - Complete user creation workflow
# - SSH key setup for user
# - Sudo access configuration
#
# WARNING: These tests modify system configuration!
# Only run in isolated test environments (containers, VMs)
#
# Run: sudo bats tests/integration/test_us2_user_management.bats

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

    # Override LOG_FILE
    export LOG_FILE="/tmp/test-server-init.log"

    # Test user name (unique to avoid conflicts)
    export TEST_USER="testuser_$$"
}

# Cleanup after tests
teardown() {
    # Remove test user if created
    if id "$TEST_USER" >/dev/null 2>&1; then
        userdel -r "$TEST_USER" 2>/dev/null || true
    fi

    rm -f /tmp/test-server-init.log
}

# ============================================================================
# User Creation Tests (T047)
# ============================================================================

@test "US2: check_user_exists returns false for non-existent user" {
    if ! type check_user_exists >/dev/null 2>&1; then
        skip "check_user_exists not yet implemented"
    fi

    run check_user_exists "$TEST_USER"
    [ "$status" -eq 1 ]
}

@test "US2: create_admin_user creates new user" {
    if ! type create_admin_user >/dev/null 2>&1; then
        skip "create_admin_user not yet implemented"
    fi

    create_admin_user "$TEST_USER"

    # Verify user exists
    id "$TEST_USER"
}

@test "US2: created user has home directory" {
    if ! type create_admin_user >/dev/null 2>&1; then
        skip "create_admin_user not yet implemented"
    fi

    create_admin_user "$TEST_USER"

    # Verify home directory exists
    [ -d "/home/$TEST_USER" ]
}

@test "US2: add_user_to_sudo adds user to sudo group" {
    if ! type create_admin_user >/dev/null 2>&1 || ! type add_user_to_sudo >/dev/null 2>&1; then
        skip "Functions not yet implemented"
    fi

    create_admin_user "$TEST_USER"
    add_user_to_sudo "$TEST_USER"

    # Verify user in sudo group
    groups "$TEST_USER" | grep -q sudo
}

# ============================================================================
# SSH Directory and Key Tests (T047)
# ============================================================================

@test "US2: setup_user_ssh_directory creates .ssh directory" {
    if ! type create_admin_user >/dev/null 2>&1 || ! type setup_user_ssh_directory >/dev/null 2>&1; then
        skip "Functions not yet implemented"
    fi

    create_admin_user "$TEST_USER"
    local user_home="/home/$TEST_USER"

    setup_user_ssh_directory "$user_home"

    # Verify .ssh directory exists
    [ -d "${user_home}/.ssh" ]
}

@test "US2: .ssh directory has correct permissions (700)" {
    if ! type create_admin_user >/dev/null 2>&1 || ! type setup_user_ssh_directory >/dev/null 2>&1; then
        skip "Functions not yet implemented"
    fi

    create_admin_user "$TEST_USER"
    local user_home="/home/$TEST_USER"

    setup_user_ssh_directory "$user_home"

    # Check permissions
    local perms
    perms=$(stat -c "%a" "${user_home}/.ssh")
    [ "$perms" = "700" ]
}

@test "US2: .ssh directory owned by user" {
    if ! type create_admin_user >/dev/null 2>&1 || ! type setup_user_ssh_directory >/dev/null 2>&1; then
        skip "Functions not yet implemented"
    fi

    create_admin_user "$TEST_USER"
    local user_home="/home/$TEST_USER"

    setup_user_ssh_directory "$user_home"

    # Check ownership
    local owner
    owner=$(stat -c "%U" "${user_home}/.ssh")
    [ "$owner" = "$TEST_USER" ]
}

@test "US2: generate_ed25519_key creates key pair" {
    if ! type generate_ed25519_key >/dev/null 2>&1; then
        skip "generate_ed25519_key not yet implemented"
    fi

    local key_file="/tmp/test_key_$$"

    generate_ed25519_key "$key_file" "$TEST_USER@testhost"

    # Verify keys exist
    [ -f "$key_file" ]
    [ -f "${key_file}.pub" ]

    # Cleanup
    rm -f "$key_file" "${key_file}.pub"
}

@test "US2: add_ssh_key_to_authorized_keys adds key to user" {
    if ! type create_admin_user >/dev/null 2>&1 || \
       ! type setup_user_ssh_directory >/dev/null 2>&1 || \
       ! type add_ssh_key_to_authorized_keys >/dev/null 2>&1; then
        skip "Functions not yet implemented"
    fi

    create_admin_user "$TEST_USER"
    local user_home="/home/$TEST_USER"

    setup_user_ssh_directory "$user_home"

    local test_key="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl test@example.com"
    add_ssh_key_to_authorized_keys "${user_home}/.ssh" "$test_key"

    # Verify authorized_keys exists and contains key
    [ -f "${user_home}/.ssh/authorized_keys" ]
    grep -q "test@example.com" "${user_home}/.ssh/authorized_keys"
}

@test "US2: authorized_keys has correct permissions (600)" {
    if ! type create_admin_user >/dev/null 2>&1 || \
       ! type setup_user_ssh_directory >/dev/null 2>&1 || \
       ! type add_ssh_key_to_authorized_keys >/dev/null 2>&1; then
        skip "Functions not yet implemented"
    fi

    create_admin_user "$TEST_USER"
    local user_home="/home/$TEST_USER"

    setup_user_ssh_directory "$user_home"

    local test_key="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl test@example.com"
    add_ssh_key_to_authorized_keys "${user_home}/.ssh" "$test_key"

    # Check permissions
    local perms
    perms=$(stat -c "%a" "${user_home}/.ssh/authorized_keys")
    [ "$perms" = "600" ]
}

@test "US2: authorized_keys owned by user" {
    if ! type create_admin_user >/dev/null 2>&1 || \
       ! type setup_user_ssh_directory >/dev/null 2>&1 || \
       ! type add_ssh_key_to_authorized_keys >/dev/null 2>&1; then
        skip "Functions not yet implemented"
    fi

    create_admin_user "$TEST_USER"
    local user_home="/home/$TEST_USER"

    setup_user_ssh_directory "$user_home"

    local test_key="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl test@example.com"
    add_ssh_key_to_authorized_keys "${user_home}/.ssh" "$test_key"

    # Check ownership
    local owner
    owner=$(stat -c "%U" "${user_home}/.ssh/authorized_keys")
    [ "$owner" = "$TEST_USER" ]
}

# ============================================================================
# End-to-End User Story 2 Test
# ============================================================================

@test "US2 E2E: complete user management workflow" {
    if ! type create_admin_user >/dev/null 2>&1 || \
       ! type add_user_to_sudo >/dev/null 2>&1 || \
       ! type configure_user_ssh_access >/dev/null 2>&1; then
        skip "User management functions not yet fully implemented"
    fi

    # Step 1: Create user
    create_admin_user "$TEST_USER"

    # Step 2: Add to sudo group
    add_user_to_sudo "$TEST_USER"

    # Step 3: Configure SSH access with generated key
    local key_file="/tmp/test_key_$$"
    configure_user_ssh_access "$TEST_USER" "" "$key_file"

    # Verify outcomes
    # - User exists
    id "$TEST_USER"

    # - User in sudo group
    groups "$TEST_USER" | grep -q sudo

    # - Home directory exists
    [ -d "/home/$TEST_USER" ]

    # - .ssh directory exists with correct permissions
    [ -d "/home/$TEST_USER/.ssh" ]
    local ssh_perms
    ssh_perms=$(stat -c "%a" "/home/$TEST_USER/.ssh")
    [ "$ssh_perms" = "700" ]

    # - authorized_keys exists with correct permissions
    [ -f "/home/$TEST_USER/.ssh/authorized_keys" ]
    local auth_perms
    auth_perms=$(stat -c "%a" "/home/$TEST_USER/.ssh/authorized_keys")
    [ "$auth_perms" = "600" ]

    # - Key pair generated
    [ -f "$key_file" ]
    [ -f "${key_file}.pub" ]

    # - Public key added to authorized_keys
    local pub_key
    pub_key=$(cat "${key_file}.pub")
    grep -qF "$pub_key" "/home/$TEST_USER/.ssh/authorized_keys"

    # Cleanup generated keys
    rm -f "$key_file" "${key_file}.pub"
}

@test "US2 E2E: user management with provided SSH key" {
    if ! type create_admin_user >/dev/null 2>&1 || \
       ! type add_user_to_sudo >/dev/null 2>&1 || \
       ! type configure_user_ssh_access >/dev/null 2>&1; then
        skip "User management functions not yet fully implemented"
    fi

    # Create user
    create_admin_user "$TEST_USER"
    add_user_to_sudo "$TEST_USER"

    # Use provided SSH key instead of generating
    local provided_key="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl provided@example.com"
    configure_user_ssh_access "$TEST_USER" "$provided_key" ""

    # Verify provided key in authorized_keys
    grep -q "provided@example.com" "/home/$TEST_USER/.ssh/authorized_keys"
}

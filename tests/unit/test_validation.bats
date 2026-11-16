#!/usr/bin/env bats
#
# Unit tests for lib/validation.sh
#
# Test coverage:
# - validate_port()
# - validate_username()
# - validate_not_root_username()
# - validate_ssh_key()
# - validate_domain()
# - validate_email()
#
# Run: bats tests/unit/test_validation.bats

# Setup test environment
setup() {
    # Load validation library
    source "${BATS_TEST_DIRNAME}/../../lib/common.sh"
    source "${BATS_TEST_DIRNAME}/../../lib/validation.sh"

    # Override LOG_FILE to prevent writing to system log during tests
    export LOG_FILE="/tmp/test-server-init.log"
}

# Cleanup after tests
teardown() {
    rm -f /tmp/test-server-init.log
}

# ============================================================================
# validate_port() tests (T024)
# ============================================================================

@test "validate_port: accepts valid port 10122" {
    run validate_port "10122"
    [ "$status" -eq 0 ]
}

@test "validate_port: accepts minimum port 1024" {
    run validate_port "1024"
    [ "$status" -eq 0 ]
}

@test "validate_port: accepts maximum port 65535" {
    run validate_port "65535"
    [ "$status" -eq 0 ]
}

@test "validate_port: rejects port below 1024" {
    run validate_port "1023"
    [ "$status" -eq 1 ]
}

@test "validate_port: rejects port 22 (below minimum)" {
    run validate_port "22"
    [ "$status" -eq 1 ]
}

@test "validate_port: rejects port above 65535" {
    run validate_port "65536"
    [ "$status" -eq 1 ]
}

@test "validate_port: rejects non-numeric input" {
    run validate_port "abc"
    [ "$status" -eq 1 ]
}

@test "validate_port: rejects empty string" {
    run validate_port ""
    [ "$status" -eq 1 ]
}

@test "validate_port: rejects negative number" {
    run validate_port "-1"
    [ "$status" -eq 1 ]
}

# ============================================================================
# validate_username() tests (T045)
# ============================================================================

@test "validate_username: accepts valid username 'devops'" {
    run validate_username "devops"
    [ "$status" -eq 0 ]
}

@test "validate_username: accepts single character 'a'" {
    run validate_username "a"
    [ "$status" -eq 0 ]
}

@test "validate_username: accepts username with underscore 'dev_ops'" {
    run validate_username "dev_ops"
    [ "$status" -eq 0 ]
}

@test "validate_username: accepts username with dash 'dev-ops'" {
    run validate_username "dev-ops"
    [ "$status" -eq 0 ]
}

@test "validate_username: accepts username with numbers 'admin123'" {
    run validate_username "admin123"
    [ "$status" -eq 0 ]
}

@test "validate_username: accepts 32 character username" {
    run validate_username "abcdefghijklmnopqrstuvwxyz123456"
    [ "$status" -eq 0 ]
}

@test "validate_username: rejects username starting with number '1admin'" {
    run validate_username "1admin"
    [ "$status" -eq 1 ]
}

@test "validate_username: rejects username starting with dash '-admin'" {
    run validate_username "-admin"
    [ "$status" -eq 1 ]
}

@test "validate_username: rejects username starting with underscore '_admin'" {
    run validate_username "_admin"
    [ "$status" -eq 1 ]
}

@test "validate_username: rejects uppercase characters 'Admin'" {
    run validate_username "Admin"
    [ "$status" -eq 1 ]
}

@test "validate_username: rejects special characters 'dev@ops'" {
    run validate_username "dev@ops"
    [ "$status" -eq 1 ]
}

@test "validate_username: rejects username 'root'" {
    run validate_username "root"
    [ "$status" -eq 1 ]
}

@test "validate_username: rejects empty string" {
    run validate_username ""
    [ "$status" -eq 1 ]
}

@test "validate_username: rejects username longer than 32 characters" {
    run validate_username "abcdefghijklmnopqrstuvwxyz1234567"
    [ "$status" -eq 1 ]
}

# ============================================================================
# validate_not_root_username() tests
# ============================================================================

@test "validate_not_root_username: accepts 'devops'" {
    run validate_not_root_username "devops"
    [ "$status" -eq 0 ]
}

@test "validate_not_root_username: rejects 'root'" {
    run validate_not_root_username "root"
    [ "$status" -eq 1 ]
}

# ============================================================================
# validate_ssh_key() tests (T025)
# ============================================================================

@test "validate_ssh_key: accepts valid Ed25519 key" {
    local test_key="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl test@example.com"
    run validate_ssh_key "$test_key"
    [ "$status" -eq 0 ]
}

@test "validate_ssh_key: accepts valid RSA 4096 key" {
    # Generate a real RSA 4096 key for testing
    local temp_key
    temp_key="$(mktemp)"
    ssh-keygen -t rsa -b 4096 -f "$temp_key" -N "" -C "test@example.com" >/dev/null 2>&1
    local test_key
    test_key="$(cat "${temp_key}.pub")"
    rm -f "$temp_key" "${temp_key}.pub"

    run validate_ssh_key "$test_key"
    [ "$status" -eq 0 ]
}

@test "validate_ssh_key: rejects RSA 2048 key (too weak)" {
    # Generate RSA 2048 key
    local temp_key
    temp_key="$(mktemp)"
    ssh-keygen -t rsa -b 2048 -f "$temp_key" -N "" -C "test@example.com" >/dev/null 2>&1
    local test_key
    test_key="$(cat "${temp_key}.pub")"
    rm -f "$temp_key" "${temp_key}.pub"

    run validate_ssh_key "$test_key"
    [ "$status" -eq 1 ]
}

@test "validate_ssh_key: rejects invalid key format" {
    run validate_ssh_key "not-a-valid-ssh-key"
    [ "$status" -eq 1 ]
}

@test "validate_ssh_key: rejects empty string" {
    run validate_ssh_key ""
    [ "$status" -eq 1 ]
}

# ============================================================================
# validate_domain() tests
# ============================================================================

@test "validate_domain: accepts 'example.com'" {
    run validate_domain "example.com"
    [ "$status" -eq 0 ]
}

@test "validate_domain: accepts subdomain 'hub.example.org'" {
    run validate_domain "hub.example.org"
    [ "$status" -eq 0 ]
}

@test "validate_domain: accepts domain with dash and digits 'my-site1.example.io'" {
    run validate_domain "my-site1.example.io"
    [ "$status" -eq 0 ]
}

@test "validate_domain: rejects domain without TLD 'localhost'" {
    run validate_domain "localhost"
    [ "$status" -eq 1 ]
}

@test "validate_domain: rejects wildcard '*.example.com'" {
    run validate_domain "*.example.com"
    [ "$status" -eq 1 ]
}

@test "validate_domain: rejects double dot 'example..com'" {
    run validate_domain "example..com"
    [ "$status" -eq 1 ]
}

@test "validate_domain: rejects leading dash '-example.com'" {
    run validate_domain "-example.com"
    [ "$status" -eq 1 ]
}

@test "validate_domain: rejects URL 'https://example.com'" {
    run validate_domain "https://example.com"
    [ "$status" -eq 1 ]
}

@test "validate_domain: rejects IP address '1.2.3.4'" {
    run validate_domain "1.2.3.4"
    [ "$status" -eq 1 ]
}

@test "validate_domain: rejects empty string" {
    run validate_domain ""
    [ "$status" -eq 1 ]
}

# ============================================================================
# validate_email() tests
# ============================================================================

@test "validate_email: accepts 'admin@example.com'" {
    run validate_email "admin@example.com"
    [ "$status" -eq 0 ]
}

@test "validate_email: accepts 'first.last+tag@sub.example.org'" {
    run validate_email "first.last+tag@sub.example.org"
    [ "$status" -eq 0 ]
}

@test "validate_email: rejects missing '@'" {
    run validate_email "admin.example.com"
    [ "$status" -eq 1 ]
}

@test "validate_email: rejects missing domain dot 'admin@localhost'" {
    run validate_email "admin@localhost"
    [ "$status" -eq 1 ]
}

@test "validate_email: rejects whitespace" {
    run validate_email "ad min@example.com"
    [ "$status" -eq 1 ]
}

@test "validate_email: rejects empty string" {
    run validate_email ""
    [ "$status" -eq 1 ]
}

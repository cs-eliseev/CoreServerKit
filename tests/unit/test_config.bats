#!/usr/bin/env bats
#
# Unit tests for lib/config.sh
#
# Test coverage:
# - backup_file()
# - cleanup_old_backups()
#
# Run: bats tests/unit/test_config.bats

# Setup test environment
setup() {
    # Load libraries
    source "${BATS_TEST_DIRNAME}/../../lib/common.sh"
    source "${BATS_TEST_DIRNAME}/../../lib/config.sh"

    # Override LOG_FILE to prevent writing to system log during tests
    export LOG_FILE="/tmp/test-server-init.log"

    # Create temporary test directory
    export TEST_DIR="/tmp/test-config-$$"
    mkdir -p "$TEST_DIR"
}

# Cleanup after tests
teardown() {
    rm -rf "$TEST_DIR"
    rm -f /tmp/test-server-init.log
}

# ============================================================================
# backup_file() tests (T026)
# ============================================================================

@test "backup_file: creates timestamped backup of existing file" {
    local test_file="${TEST_DIR}/test.conf"
    echo "original content" > "$test_file"

    run backup_file "$test_file"
    [ "$status" -eq 0 ]

    # Verify backup was created
    local backup_count
    backup_count=$(find "$TEST_DIR" -name "test.conf.*.bak" | wc -l)
    [ "$backup_count" -eq 1 ]
}

@test "backup_file: preserves file permissions in backup" {
    local test_file="${TEST_DIR}/test.conf"
    echo "original content" > "$test_file"
    chmod 600 "$test_file"

    run backup_file "$test_file"
    [ "$status" -eq 0 ]

    # Find the backup file
    local backup_file
    backup_file=$(find "$TEST_DIR" -name "test.conf.*.bak" | head -1)

    # Verify permissions match (600)
    local perms
    perms=$(stat -c "%a" "$backup_file")
    [ "$perms" = "600" ]
}

@test "backup_file: backup contains same content as original" {
    local test_file="${TEST_DIR}/test.conf"
    echo "original content" > "$test_file"

    run backup_file "$test_file"
    [ "$status" -eq 0 ]

    # Find the backup file
    local backup_file
    backup_file=$(find "$TEST_DIR" -name "test.conf.*.bak" | head -1)

    # Verify content matches
    local backup_content
    backup_content=$(cat "$backup_file")
    [ "$backup_content" = "original content" ]
}

@test "backup_file: fails when file does not exist" {
    local test_file="${TEST_DIR}/nonexistent.conf"

    run backup_file "$test_file"
    [ "$status" -eq 1 ]
}

@test "backup_file: creates unique backup names for multiple backups" {
    local test_file="${TEST_DIR}/test.conf"
    echo "original content" > "$test_file"

    # Create first backup
    backup_file "$test_file"
    sleep 1

    # Create second backup
    backup_file "$test_file"

    # Verify two backups exist
    local backup_count
    backup_count=$(find "$TEST_DIR" -name "test.conf.*.bak" | wc -l)
    [ "$backup_count" -eq 2 ]
}

# ============================================================================
# cleanup_old_backups() tests (T026)
# ============================================================================

@test "cleanup_old_backups: keeps last 10 backups by default" {
    local test_file="${TEST_DIR}/test.conf"
    echo "original content" > "$test_file"

    # Create 15 backups
    for i in {1..15}; do
        sleep 0.1  # Ensure different timestamps
        backup_file "$test_file"
    done

    run cleanup_old_backups "$test_file" 10
    [ "$status" -eq 0 ]

    # Verify only 10 backups remain
    local backup_count
    backup_count=$(find "$TEST_DIR" -name "test.conf.*.bak" | wc -l)
    [ "$backup_count" -eq 10 ]
}

@test "cleanup_old_backups: keeps newest backups, removes oldest" {
    local test_file="${TEST_DIR}/test.conf"
    echo "original content" > "$test_file"

    # Create 5 backups with identifiable content
    for i in {1..5}; do
        echo "version $i" > "$test_file"
        sleep 0.1
        backup_file "$test_file"
    done

    # Keep only 3 backups
    cleanup_old_backups "$test_file" 3

    # Verify 3 backups remain
    local backup_count
    backup_count=$(find "$TEST_DIR" -name "test.conf.*.bak" | wc -l)
    [ "$backup_count" -eq 3 ]

    # Verify oldest backups were removed (version 1 and 2 should be gone)
    local oldest_backup
    oldest_backup=$(find "$TEST_DIR" -name "test.conf.*.bak" -type f -printf '%T@ %p\n' | sort -n | head -1 | cut -d' ' -f2-)
    local oldest_content
    oldest_content=$(cat "$oldest_backup")
    [ "$oldest_content" = "version 3" ]
}

@test "cleanup_old_backups: does nothing when backup count is within limit" {
    local test_file="${TEST_DIR}/test.conf"
    echo "original content" > "$test_file"

    # Create 5 backups
    for i in {1..5}; do
        sleep 0.1
        backup_file "$test_file"
    done

    run cleanup_old_backups "$test_file" 10
    [ "$status" -eq 0 ]

    # Verify all 5 backups still exist
    local backup_count
    backup_count=$(find "$TEST_DIR" -name "test.conf.*.bak" | wc -l)
    [ "$backup_count" -eq 5 ]
}

@test "cleanup_old_backups: handles custom retention count" {
    local test_file="${TEST_DIR}/test.conf"
    echo "original content" > "$test_file"

    # Create 10 backups
    for i in {1..10}; do
        sleep 0.1
        backup_file "$test_file"
    done

    # Keep only 2 backups
    cleanup_old_backups "$test_file" 2

    # Verify only 2 backups remain
    local backup_count
    backup_count=$(find "$TEST_DIR" -name "test.conf.*.bak" | wc -l)
    [ "$backup_count" -eq 2 ]
}

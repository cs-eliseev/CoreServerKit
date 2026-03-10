#!/usr/bin/env bash

set -euo pipefail

backup_file() {
    local file_path="$1"

    if [[ ! -f "${file_path}" ]]; then
        log_error "Cannot backup: file not found: ${file_path}"
        return 1
    fi

    local timestamp
    timestamp="$(date '+%Y%m%d_%H%M%S')"
    local backup_path="${file_path}.${timestamp}.bak"

    cp -p "${file_path}" "${backup_path}"
    log_info "Created backup: ${backup_path}"

    return 0
}

cleanup_old_backups() {
    local file_pattern="$1"
    local keep_count="${2:-10}"

    local backup_files
    backup_files="$(find "$(dirname "${file_pattern}")" \
        -name "$(basename "${file_pattern}")*.bak" \
        -type f \
        -printf '%T@ %p\n' | sort -rn | cut -d' ' -f2-)"

    local backup_count
    backup_count="$(echo "${backup_files}" | grep -c . || echo "0")"

    if [[ "${backup_count}" -le "${keep_count}" ]]; then
        log_info "Backup count (${backup_count}) within limit (${keep_count})"
        return 0
    fi

    local to_remove
    to_remove="$(echo "${backup_files}" | tail -n +"$((keep_count + 1))")"

    local file
    while IFS= read -r file; do
        if [[ -n "${file}" ]]; then
            rm -f "${file}"
            log_info "Removed old backup: ${file}"
        fi
    done <<< "${to_remove}"

    return 0
}

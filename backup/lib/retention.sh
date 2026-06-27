#!/usr/bin/env bash

# Conservative local retention. Remote retention remains an explicit placeholder.

apply_local_retention() {
    local output_dir="$1"
    local -a archives=()
    local remove_count index archive

    mapfile -t archives < <(find "$output_dir" -maxdepth 1 -type f \
        -name "${BACKUP_NAME}_*.tar.zst.age" -printf '%f\n' | LC_ALL=C sort)

    remove_count=$(( ${#archives[@]} - KEEP_LOCAL_BACKUPS ))
    (( remove_count > 0 )) || return 0

    for ((index = 0; index < remove_count; index++)); do
        archive="${output_dir}/${archives[$index]}"
        run_command rm -- "$archive" "${archive}.sha256"
    done
}

apply_remote_retention() {
    # Remote deletion needs provider-specific validation and is intentionally
    # deferred. Keeping this call in the flow makes that future phase explicit.
    if [[ "$FTP_ENABLED" == "true" ]]; then
        info "Remote FTP retention is not enabled in Phase 1"
    fi
}

apply_retention() {
    local output_dir="$1"
    info "Applying retention policy (keep $KEEP_LOCAL_BACKUPS local archives)"
    apply_local_retention "$output_dir"
    apply_remote_retention
}


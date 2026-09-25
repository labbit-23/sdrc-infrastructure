#!/usr/bin/env bash

# Publish a completed archive and checksum to a remote configured in rclone,
# under a FIXED filename per backup job (not the timestamped local archive
# name). Each run overwrites that same remote file; the remote's own version
# history (e.g. Google Drive) is the off-site retention mechanism, not
# distinct dated filenames managed by this script.

push_to_rclone_remote() {
    local archive="$1"
    local archive_extension="$2"
    local checksum="${archive}.sha256"
    local remote_archive_name="${BACKUP_NAME}.${archive_extension}"
    local remote_checksum_name="${remote_archive_name}.sha256"
    local destination_archive="${RCLONE_REMOTE}/${remote_archive_name}"
    local destination_checksum="${RCLONE_REMOTE}/${remote_checksum_name}"

    [[ "$RCLONE_ENABLED" == "true" ]] || {
        info "Rclone remote publication is disabled"
        return 0
    }

    if [[ "$DRY_RUN" == "true" ]]; then
        info "DRY RUN: would publish archive and checksum to rclone remote as $destination_archive"
        return 0
    fi

    info "Publishing to rclone remote: $destination_archive"
    "$RCLONE_BINARY" copyto -- "$archive" "$destination_archive" \
        || fatal "Could not publish archive to rclone remote: $destination_archive"
    "$RCLONE_BINARY" copyto -- "$checksum" "$destination_checksum" \
        || fatal "Could not publish checksum to rclone remote: $destination_checksum"

    info "Published backup to rclone remote: $destination_archive"
}

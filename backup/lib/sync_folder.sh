#!/usr/bin/env bash

# Publish a completed archive and checksum into a desktop/cloud sync folder.
# The sync client (for example Google Drive for desktop) remains responsible
# for transferring files off the machine.

publish_to_sync_folder() {
    local archive="$1"
    local checksum="${archive}.sha256"
    local destination_archive destination_checksum

    [[ "$SYNC_FOLDER_ENABLED" == "true" ]] || {
        info "Sync-folder publication is disabled"
        return 0
    }

    destination_archive="${SYNC_FOLDER_DIR}/$(basename "$archive")"
    destination_checksum="${SYNC_FOLDER_DIR}/$(basename "$checksum")"

    if [[ "$DRY_RUN" == "true" ]]; then
        info "DRY RUN: would publish archive and checksum to $SYNC_FOLDER_DIR"
        return 0
    fi

    mkdir -p -- "$SYNC_FOLDER_DIR"
    [[ -d "$SYNC_FOLDER_DIR" && -w "$SYNC_FOLDER_DIR" ]] \
        || fatal "Sync folder is missing or not writable: $SYNC_FOLDER_DIR"

    if ! cp -- "$archive" "${destination_archive}.partial"; then
        rm -f -- "${destination_archive}.partial" "${destination_checksum}.partial"
        fatal "Could not copy archive to sync folder: $destination_archive"
    fi
    if ! cp -- "$checksum" "${destination_checksum}.partial"; then
        rm -f -- "${destination_archive}.partial" "${destination_checksum}.partial"
        fatal "Could not copy checksum to sync folder: $destination_checksum"
    fi
    mv -- "${destination_archive}.partial" "$destination_archive"
    mv -- "${destination_checksum}.partial" "$destination_checksum"

    (cd -- "$SYNC_FOLDER_DIR" && sha256sum --check "$(basename "$destination_checksum")") \
        || fatal "Sync-folder checksum verification failed: $destination_archive"
    info "Published backup to sync folder: $destination_archive"
}

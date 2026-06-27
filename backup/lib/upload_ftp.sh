#!/usr/bin/env bash

# Upload encrypted archives and checksums with lftp.

read_ftp_password() {
    if [[ -n "${FTP_PASSWORD:-}" ]]; then
        printf '%s' "$FTP_PASSWORD"
    elif [[ -n "${FTP_PASSWORD_FILE:-}" && -r "$FTP_PASSWORD_FILE" ]]; then
        < "$FTP_PASSWORD_FILE"
    else
        fatal "Set FTP_PASSWORD or a readable FTP_PASSWORD_FILE"
    fi
}

upload_backup() {
    local archive="$1"

    if [[ "$FTP_ENABLED" != "true" ]]; then
        info "FTP upload is disabled"
        return 0
    fi

    : "${FTP_URL:?FTP_URL must be set when FTP is enabled}"
    : "${FTP_USER:?FTP_USER must be set when FTP is enabled}"

    if [[ "$DRY_RUN" == "true" ]]; then
        info "DRY RUN: upload $(basename "$archive") and its checksum to ${FTP_URL}${FTP_REMOTE_DIR}"
        return 0
    fi

    local ftp_password
    ftp_password="$(read_ftp_password)"
    info "Uploading encrypted archive and checksum with lftp"

    LFTP_PASSWORD="$ftp_password" lftp <<LFTP_COMMANDS
set cmd:fail-exit yes
set ftp:ssl-force true
set ssl:verify-certificate true
open --env-password -u "$FTP_USER" "$FTP_URL"
mkdir -p "$FTP_REMOTE_DIR"
cd "$FTP_REMOTE_DIR"
put "$archive"
put "${archive}.sha256"
bye
LFTP_COMMANDS
    unset ftp_password
}


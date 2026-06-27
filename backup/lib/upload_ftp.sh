#!/usr/bin/env bash

# Hostinger FTP upload/download using lftp and environment-only credentials.

read_ftp_password_from_environment() {
    local ftp_password
    ftp_password="$(printenv "$FTP_PASSWORD_ENV" 2>/dev/null || true)"
    [[ -n "$ftp_password" ]] \
        || fatal "FTP password environment variable is unset or empty: $FTP_PASSWORD_ENV"
    printf '%s' "$ftp_password"
}

ftp_ssl_verify_setting() {
    if [[ "$FTP_SSL_VERIFY_CERT" == "false" ]]; then
        printf '%s' "set ssl:verify-certificate no"
    fi
}

upload_backup_ftp() {
    local artifact="$1"
    local checksum="${artifact}.sha256"
    local artifact_name checksum_name
    artifact_name="$(basename "$artifact")"
    checksum_name="$(basename "$checksum")"

    if [[ "$DRY_RUN" == "true" ]]; then
        info "DRY RUN: would create FTP directory ${FTP_REMOTE_DIR} on ${FTP_HOST}:${FTP_PORT}"
        info "DRY RUN: would upload ${artifact_name}.partial and ${checksum_name}.partial"
        info "DRY RUN: would rename checksum then artifact to their final remote names"
        return 0
    fi

    [[ -f "$artifact" ]] || fatal "FTP artifact not found: $artifact"
    [[ -f "$checksum" ]] || fatal "FTP checksum not found: $checksum"

    local ftp_password
    ftp_password="$(read_ftp_password_from_environment)"

    info "Uploading $artifact_name and its checksum to FTP ${FTP_HOST}:${FTP_PORT}${FTP_REMOTE_DIR}"

    local ssl_verify_setting
    ssl_verify_setting="$(ftp_ssl_verify_setting)"

    if LFTP_PASSWORD="$ftp_password" lftp --norc <<LFTP_COMMANDS
set cmd:fail-exit yes
set ftp:passive-mode true
set net:max-retries 2
set net:timeout 20
$ssl_verify_setting
open --env-password --user "$FTP_USER" -p "$FTP_PORT" "ftp://$FTP_HOST"
mkdir -p "$FTP_REMOTE_DIR"
cd "$FTP_REMOTE_DIR"
put "$artifact" -o "${artifact_name}.partial"
put "$checksum" -o "${checksum_name}.partial"
mv "${checksum_name}.partial" "$checksum_name"
mv "${artifact_name}.partial" "$artifact_name"
bye
LFTP_COMMANDS
    then
        unset ftp_password
        info "FTP upload completed successfully: ${FTP_REMOTE_DIR}/${artifact_name}"
    else
        local upload_status=$?
        unset ftp_password
        fatal "FTP upload failed with exit code $upload_status"
    fi
}

download_backup_ftp() {
    local remote_filename="$1"
    local destination_dir="$2"
    local remote_checksum="${remote_filename}.sha256"
    local local_archive="${destination_dir}/${remote_filename}"
    local local_checksum="${local_archive}.sha256"

    if [[ "$DRY_RUN" == "true" ]]; then
        info "DRY RUN: would download ${FTP_REMOTE_DIR}/${remote_filename}"
        info "DRY RUN: would download ${FTP_REMOTE_DIR}/${remote_checksum}"
        return 0
    fi

    local ftp_password ssl_verify_setting
    ftp_password="$(read_ftp_password_from_environment)"
    ssl_verify_setting="$(ftp_ssl_verify_setting)"

    info "Downloading $remote_filename and its checksum from FTP ${FTP_HOST}:${FTP_PORT}${FTP_REMOTE_DIR}"

    if LFTP_PASSWORD="$ftp_password" lftp --norc <<LFTP_COMMANDS
set cmd:fail-exit yes
set ftp:passive-mode true
set net:max-retries 2
set net:timeout 20
$ssl_verify_setting
open --env-password --user "$FTP_USER" -p "$FTP_PORT" "ftp://$FTP_HOST"
cd "$FTP_REMOTE_DIR"
get "$remote_filename" -o "${local_archive}.partial"
get "$remote_checksum" -o "${local_checksum}.partial"
bye
LFTP_COMMANDS
    then
        unset ftp_password
        mv -- "${local_archive}.partial" "$local_archive"
        mv -- "${local_checksum}.partial" "$local_checksum"
        info "FTP download completed successfully: $remote_filename"
    else
        local download_status=$?
        unset ftp_password
        rm -f -- "${local_archive}.partial" "${local_checksum}.partial" \
            "$local_archive" "$local_checksum"
        fatal "FTP download failed with exit code $download_status"
    fi
}

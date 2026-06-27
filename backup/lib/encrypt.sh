#!/usr/bin/env bash

# Compression, age encryption/decryption, and checksum helpers.

compress_backup() {
    local source_dir="$1"
    local output_file="$2"

    if [[ "$DRY_RUN" == "true" ]]; then
        info "DRY RUN: tar contents of $source_dir and compress with zstd to $output_file"
        return 0
    fi

    info "Compressing staged data with tar and zstd"
    tar -C "$source_dir" -cf - . | zstd -T0 -q -o "$output_file"
}

encrypt_backup() {
    local input_file="$1"
    local output_file="$2"

    [[ -n "${AGE_RECIPIENT:-}" ]] || fatal "AGE_RECIPIENT must be configured"
    run_command age --encrypt --recipient "$AGE_RECIPIENT" --output "$output_file" "$input_file"
}

generate_checksum() {
    local archive="$1"
    local archive_dir archive_name
    archive_dir="$(dirname "$archive")"
    archive_name="$(basename "$archive")"

    if [[ "$DRY_RUN" == "true" ]]; then
        info "DRY RUN: generate SHA-256 checksum at ${archive}.sha256"
        return 0
    fi

    (cd "$archive_dir" && sha256sum "$archive_name" > "${archive_name}.sha256")
}

verify_checksum() {
    local archive="$1"
    local checksum_file="${archive}.sha256"
    local archive_dir checksum_name

    archive_dir="$(dirname "$archive")"
    checksum_name="$(basename "$checksum_file")"

    if [[ "$DRY_RUN" == "true" ]]; then
        info "DRY RUN: verify checksum from $checksum_file"
        return 0
    fi

    [[ -f "$checksum_file" ]] || fatal "Checksum file not found: $checksum_file"
    (cd "$archive_dir" && sha256sum --check "$checksum_name")
}

decrypt_backup() {
    local input_file="$1"
    local output_file="$2"

    [[ -n "${AGE_IDENTITY_FILE:-}" ]] || fatal "AGE_IDENTITY_FILE must be configured or exported"
    [[ -f "$AGE_IDENTITY_FILE" ]] || fatal "age identity file not found: $AGE_IDENTITY_FILE"
    run_command age --decrypt --identity "$AGE_IDENTITY_FILE" --output "$output_file" "$input_file"
}

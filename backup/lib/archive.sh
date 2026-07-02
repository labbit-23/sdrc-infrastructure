#!/usr/bin/env bash

# tar/zstd archive and SHA-256 checksum helpers.

compress_archive() {
    local source_dir="$1"
    local output_file="$2"

    if [[ "$DRY_RUN" == "true" ]]; then
        info "DRY RUN: would tar $source_dir and compress with zstd to $output_file"
        return 0
    fi

    info "Compressing working directory with tar and zstd"
    tar -C "$source_dir" -cf - . | zstd -T0 -q -o "$output_file"
}

generate_checksum() {
    local archive="$1"
    local archive_dir archive_name checksum_partial
    archive_dir="$(dirname "$archive")"
    archive_name="$(basename "$archive")"
    checksum_partial="${archive}.sha256.partial"

    if [[ "$DRY_RUN" == "true" ]]; then
        info "DRY RUN: would generate SHA-256 checksum at ${archive}.sha256"
        return 0
    fi

    (cd "$archive_dir" && sha256sum "$archive_name" > "$(basename "$checksum_partial")")
    mv -- "$checksum_partial" "${archive}.sha256"
    info "Generated SHA-256 checksum: ${archive}.sha256"
}

verify_checksum() {
    local archive="$1"
    local checksum_file="${archive}.sha256"
    local archive_dir checksum_name
    archive_dir="$(dirname "$archive")"
    checksum_name="$(basename "$checksum_file")"

    if [[ "$DRY_RUN" == "true" ]]; then
        info "DRY RUN: would verify checksum from $checksum_file"
        return 0
    fi

    [[ -f "$checksum_file" ]] || fatal "Checksum file not found: $checksum_file"
    (cd "$archive_dir" && sha256sum --check "$checksum_name")
}

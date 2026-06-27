#!/usr/bin/env bash

# Phase 3 age encryption helper. Decryption remains a future-phase placeholder.

encrypt_archive() {
    local input_file="$1"
    local output_file="$2"
    local recipients_file="$3"

    if [[ "$DRY_RUN" == "true" ]]; then
        info "DRY RUN: would encrypt $input_file with age recipients from $recipients_file"
        info "DRY RUN: encrypted partial output would be $output_file"
        return 0
    fi

    info "Encrypting archive with age"
    "$AGE_BINARY" --encrypt --recipients-file "$recipients_file" \
        --output "$output_file" "$input_file"
}

decrypt_backup() {
    fatal "Decryption is not implemented in Phase 3"
}

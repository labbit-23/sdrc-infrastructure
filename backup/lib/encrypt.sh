#!/usr/bin/env bash

# age encryption and restore decryption helpers.

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

decrypt_archive() {
    local input_file="$1"
    local output_file="$2"
    local identity_file="$3"

    if [[ "$DRY_RUN" == "true" ]]; then
        info "DRY RUN: would decrypt $input_file with age identity $identity_file"
        return 0
    fi

    info "Decrypting archive with age"
    "$AGE_BINARY" --decrypt --identity "$identity_file" \
        --output "$output_file" "$input_file"
}

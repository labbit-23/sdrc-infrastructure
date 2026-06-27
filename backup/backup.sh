#!/usr/bin/env bash
set -euo pipefail

# Phase 1 backup orchestration. Configuration is the required first argument.

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_BASE_DIR="$SCRIPT_DIR"
BACKUP_LOG_DIR="${SCRIPT_DIR}/logs"

# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"
# shellcheck source=lib/encrypt.sh
source "${SCRIPT_DIR}/lib/encrypt.sh"
# shellcheck source=lib/upload_ftp.sh
source "${SCRIPT_DIR}/lib/upload_ftp.sh"
# shellcheck source=lib/retention.sh
source "${SCRIPT_DIR}/lib/retention.sh"

usage() {
    printf 'Usage: %s CONFIG_FILE [--dry-run]\n' "$0"
}

[[ $# -ge 1 ]] || { usage >&2; exit 2; }
CONFIG_FILE="$1"
shift
DRY_RUN=false

while (( $# > 0 )); do
    case "$1" in
        --dry-run) DRY_RUN=true ;;
        -h|--help) usage; exit 0 ;;
        *) usage >&2; fatal "Unknown argument: $1" ;;
    esac
    shift
done

RUN_TIMESTAMP="$(date -u +'%Y%m%dT%H%M%SZ')"
load_config "$CONFIG_FILE"
init_logging backup

WORK_DIR=""
cleanup() {
    local exit_code=$?
    if [[ -n "$WORK_DIR" && -d "$WORK_DIR" ]]; then
        if [[ "$KEEP_WORKDIR" == "true" ]]; then
            info "Keeping working directory: $WORK_DIR"
        else
            rm -rf -- "$WORK_DIR"
        fi
    fi
    if (( exit_code != 0 )); then
        warn "Backup failed with exit code $exit_code"
    fi
    exit "$exit_code"
}
trap cleanup EXIT

require_command tar
require_command zstd
require_command age
require_command sha256sum
require_command find
if [[ "$FTP_ENABLED" == "true" ]]; then
    require_command lftp
fi

mkdir -p "$BACKUP_WORK_ROOT" "$BACKUP_OUTPUT_DIR"
WORK_DIR="$(mktemp -d "${BACKUP_WORK_ROOT}/${BACKUP_NAME}_${RUN_TIMESTAMP}.XXXXXX")"
PAYLOAD_DIR="${WORK_DIR}/payload"
mkdir -p "${PAYLOAD_DIR}/paths" "${PAYLOAD_DIR}/commands" "${PAYLOAD_DIR}/databases"

info "Starting backup for $BACKUP_NAME"
info "Working directory: $WORK_DIR"

for source_path in "${BACKUP_PATHS[@]}"; do
    if [[ "$DRY_RUN" == "true" ]]; then
        info "DRY RUN: copy path $source_path into staged paths"
    elif [[ -e "$source_path" ]]; then
        info "Collecting path: $source_path"
        cp -a --parents -- "$source_path" "${PAYLOAD_DIR}/paths"
    else
        warn "Configured path does not exist, skipping: $source_path"
    fi
done

# Entries use output-name|command. Commands run only from the trusted config.
for capture in "${COMMAND_CAPTURES[@]}"; do
    IFS='|' read -r output_name capture_command <<< "$capture"
    [[ -n "$output_name" && "$output_name" =~ ^[A-Za-z0-9._-]+$ && -n "$capture_command" ]] \
        || fatal "Invalid COMMAND_CAPTURES entry: $capture"
    if [[ "$DRY_RUN" == "true" ]]; then
        info "DRY RUN: capture command output to commands/$output_name"
    else
        info "Capturing command output: $output_name"
        bash -o pipefail -c "$capture_command" > "${PAYLOAD_DIR}/commands/${output_name}"
    fi
done

# Database entries also use output-name|command (for example, pg_dumpall).
for dump in "${DATABASE_DUMPS[@]}"; do
    IFS='|' read -r output_name dump_command <<< "$dump"
    [[ -n "$output_name" && "$output_name" =~ ^[A-Za-z0-9._-]+$ && -n "$dump_command" ]] \
        || fatal "Invalid DATABASE_DUMPS entry: $dump"
    if [[ "$DRY_RUN" == "true" ]]; then
        info "DRY RUN: capture database dump to databases/$output_name"
    else
        info "Creating database dump: $output_name"
        bash -o pipefail -c "$dump_command" > "${PAYLOAD_DIR}/databases/${output_name}"
    fi
done

ARCHIVE_PREFIX="${BACKUP_OUTPUT_DIR}/${BACKUP_NAME}_${RUN_TIMESTAMP}.tar.zst"
ENCRYPTED_ARCHIVE="${ARCHIVE_PREFIX}.age"

compress_backup "$PAYLOAD_DIR" "$ARCHIVE_PREFIX"
encrypt_backup "$ARCHIVE_PREFIX" "$ENCRYPTED_ARCHIVE"
if [[ "$DRY_RUN" != "true" ]]; then
    rm -- "$ARCHIVE_PREFIX"
fi
generate_checksum "$ENCRYPTED_ARCHIVE"
upload_backup "$ENCRYPTED_ARCHIVE"
apply_retention "$BACKUP_OUTPUT_DIR"

info "Backup flow completed: $ENCRYPTED_ARCHIVE"


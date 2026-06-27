#!/usr/bin/env bash
set -euo pipefail

# Non-destructive restore: verify, decrypt, and extract to a chosen directory.

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_BASE_DIR="$SCRIPT_DIR"
BACKUP_LOG_DIR="${SCRIPT_DIR}/logs"

# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"
# shellcheck source=lib/encrypt.sh
source "${SCRIPT_DIR}/lib/encrypt.sh"

usage() {
    printf 'Usage: %s CONFIG_FILE ARCHIVE RESTORE_DIR [--dry-run]\n' "$0"
}

[[ $# -ge 3 ]] || { usage >&2; exit 2; }
CONFIG_FILE="$1"
ARCHIVE="$2"
RESTORE_DIR="$3"
shift 3
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
init_logging restore

require_command sha256sum
require_command age
require_command tar
require_command zstd

[[ -f "$ARCHIVE" ]] || {
    [[ "$DRY_RUN" == "true" ]] || fatal "Archive not found: $ARCHIVE"
    warn "DRY RUN: archive does not exist; continuing for flow validation"
}

if [[ -d "$RESTORE_DIR" && -n "$(find "$RESTORE_DIR" -mindepth 1 -maxdepth 1 -print -quit)" ]]; then
    fatal "Restore directory must be empty: $RESTORE_DIR"
fi

RESTORE_WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/${BACKUP_NAME}_restore_${RUN_TIMESTAMP}.XXXXXX")"
cleanup() {
    local exit_code=$?
    rm -rf -- "$RESTORE_WORK_DIR"
    if (( exit_code != 0 )); then
        warn "Restore failed with exit code $exit_code"
    fi
    exit "$exit_code"
}
trap cleanup EXIT

DECRYPTED_ARCHIVE="${RESTORE_WORK_DIR}/${BACKUP_NAME}.tar.zst"
info "Starting non-destructive restore verification"
verify_checksum "$ARCHIVE"

if [[ "$DRY_RUN" == "true" ]]; then
    info "DRY RUN: decrypt $ARCHIVE to temporary compressed archive"
    info "DRY RUN: create $RESTORE_DIR and extract with zstd and tar"
else
    decrypt_backup "$ARCHIVE" "$DECRYPTED_ARCHIVE"
    mkdir -p "$RESTORE_DIR"
    zstd -q -d -c "$DECRYPTED_ARCHIVE" | tar -C "$RESTORE_DIR" -xf -
fi

info "Restore extraction completed: $RESTORE_DIR"
info "No data was written back to any live system"


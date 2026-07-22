#!/usr/bin/env bash
set -euo pipefail
umask 077

# Restore from a local archive or an explicitly selected FTP backup.

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
BACKUP_BASE_DIR="$SCRIPT_DIR"
BACKUP_LOG_DIR="${SCRIPT_DIR}/logs"

# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"
# shellcheck source=lib/archive.sh
source "${SCRIPT_DIR}/lib/archive.sh"
# shellcheck source=lib/encrypt.sh
source "${SCRIPT_DIR}/lib/encrypt.sh"
# shellcheck source=lib/upload_ftp.sh
source "${SCRIPT_DIR}/lib/upload_ftp.sh"
# shellcheck source=lib/retention.sh
source "${SCRIPT_DIR}/lib/retention.sh"

PROGRAM_NAME="$(basename "$0")"
REPOSITORY_VERSION="$(repository_version)"

print_usage() {
    printf '%s\n' \
        "SDRC Infrastructure restore ${REPOSITORY_VERSION}" \
        "" \
        "Usage:" \
        "  ${PROGRAM_NAME} CONFIG_FILE ARCHIVE_OR_REMOTE_FILENAME RESTORE_DIR [OPTIONS]" \
        "" \
        "Options:" \
        "  --ftp           Download the archive and checksum from configured FTP storage." \
        "  --force         Allow extraction into an existing restore directory." \
        "  --dry-run       Validate and log planned actions without downloading or extracting." \
        "  -h, --help      Show this help message and exit." \
        "  -V, --version   Show the repository version and exit."
}

for argument in "$@"; do
    case "$argument" in
        -h|--help) print_usage; exit 0 ;;
        -V|--version) printf '%s %s\n' "$PROGRAM_NAME" "$REPOSITORY_VERSION"; exit 0 ;;
    esac
done

[[ $# -ge 3 ]] || { print_usage >&2; exit 2; }
CONFIG_FILE="$1"
SOURCE_ARCHIVE="$2"
RESTORE_DIR="$3"
shift 3

DRY_RUN=false
FORCE=false
FTP_SOURCE=false

while (( $# > 0 )); do
    case "$1" in
        --ftp) FTP_SOURCE=true ;;
        --force) FORCE=true ;;
        --dry-run) DRY_RUN=true ;;
        *) print_usage >&2; fatal "Unknown argument: $1" ;;
    esac
    shift
done

[[ -n "$RESTORE_DIR" && "$RESTORE_DIR" != "/" ]] \
    || fatal "RESTORE_DIR must not be empty or the filesystem root"

RUN_TIMESTAMP="$(date -u +'%Y%m%dT%H%M%SZ')"
RUN_ID="${RUN_TIMESTAMP}_$$"
load_config "$CONFIG_FILE"
init_logging restore

if [[ -e "$RESTORE_DIR" || -L "$RESTORE_DIR" ]]; then
    [[ "$FORCE" == "true" ]] || fatal "Restore directory already exists; use --force to overwrite: $RESTORE_DIR"
    [[ -d "$RESTORE_DIR" ]] || fatal "Restore destination exists and is not a directory: $RESTORE_DIR"
fi

ARCHIVE_NAME="$(basename "$SOURCE_ARCHIVE")"
case "$ARCHIVE_NAME" in
    *.tar.zst.age) ARCHIVE_ENCRYPTED=true ;;
    *.tar.zst) ARCHIVE_ENCRYPTED=false ;;
    *) fatal "Archive must end in .tar.zst or .tar.zst.age: $ARCHIVE_NAME" ;;
esac

require_command sha256sum
require_command tar
require_command zstd

if [[ "$ARCHIVE_ENCRYPTED" == "true" ]]; then
    command -v "$AGE_BINARY" >/dev/null 2>&1 \
        || fatal "Required age executable not found: $AGE_BINARY"
    [[ -n "$AGE_IDENTITY_FILE" ]] || fatal "AGE_IDENTITY_FILE is required for encrypted restore"
    [[ "$AGE_IDENTITY_FILE" == /* ]] || fatal "AGE_IDENTITY_FILE must be an absolute path"
    [[ -f "$AGE_IDENTITY_FILE" && -r "$AGE_IDENTITY_FILE" ]] \
        || fatal "Age identity file is missing or unreadable: $AGE_IDENTITY_FILE"
fi

if [[ "$FTP_SOURCE" == "true" ]]; then
    [[ "$SOURCE_ARCHIVE" == "$ARCHIVE_NAME" \
        && "$ARCHIVE_NAME" =~ ^[A-Za-z0-9._-]+$ ]] \
        || fatal "FTP source must be a remote filename without a path"
    validate_ftp_connection_config
    require_command lftp
fi

RESTORE_WORK_DIR="${TMPDIR:-/tmp}/${BACKUP_NAME}_restore_${RUN_ID}.dry-run"
if [[ "$DRY_RUN" != "true" ]]; then
    RESTORE_WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/${BACKUP_NAME}_restore_${RUN_ID}.XXXXXX")"
fi

cleanup() {
    local exit_code=$?
    if [[ "$DRY_RUN" != "true" && -d "$RESTORE_WORK_DIR" ]]; then
        rm -rf -- "$RESTORE_WORK_DIR"
    fi
    if (( exit_code != 0 )); then
        warn "Restore failed with exit code $exit_code"
    fi
}
trap cleanup EXIT

if [[ "$FTP_SOURCE" == "true" ]]; then
    ARCHIVE="${RESTORE_WORK_DIR}/${ARCHIVE_NAME}"
    download_backup_ftp "$ARCHIVE_NAME" "$RESTORE_WORK_DIR"
else
    ARCHIVE="$SOURCE_ARCHIVE"
    if [[ ! -f "$ARCHIVE" ]]; then
        [[ "$DRY_RUN" == "true" ]] \
            || fatal "Local archive not found: $ARCHIVE"
        warn "DRY RUN: local archive does not exist; continuing for flow validation"
    fi
fi

info "Verifying backup checksum before decryption or extraction"
verify_checksum "$ARCHIVE"

COMPRESSED_ARCHIVE="$ARCHIVE"
if [[ "$ARCHIVE_ENCRYPTED" == "true" ]]; then
    COMPRESSED_ARCHIVE="${RESTORE_WORK_DIR}/${ARCHIVE_NAME%.age}"
    decrypt_archive "$ARCHIVE" "$COMPRESSED_ARCHIVE" "$AGE_IDENTITY_FILE"
fi

if [[ "$DRY_RUN" == "true" ]]; then
    info "DRY RUN: would create or overwrite restore directory: $RESTORE_DIR"
    info "DRY RUN: would extract $COMPRESSED_ARCHIVE with zstd and tar"
else
    mkdir -p "$RESTORE_DIR"
    info "Extracting backup into: $RESTORE_DIR"
    zstd -q -d -c "$COMPRESSED_ARCHIVE" | tar -C "$RESTORE_DIR" -xf -
fi

info "Restore extraction completed: $RESTORE_DIR"
info "No data was written back outside the selected restore directory"

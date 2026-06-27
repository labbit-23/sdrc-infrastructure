#!/usr/bin/env bash
set -euo pipefail
umask 077

# Phase 2 local backup orchestration. The config file must be the first argument.

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_BASE_DIR="$SCRIPT_DIR"
BACKUP_LOG_DIR="${SCRIPT_DIR}/logs"

# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"
# shellcheck source=lib/archive.sh
source "${SCRIPT_DIR}/lib/archive.sh"

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
RUN_ID="${RUN_TIMESTAMP}_$$"
load_config "$CONFIG_FILE"
init_logging backup

WORK_DIR="${BACKUP_WORK_ROOT}/${BACKUP_NAME}_${RUN_ID}"
ARCHIVE="${BACKUP_OUTPUT_DIR}/${BACKUP_NAME}_${RUN_ID}.tar.zst"
ARCHIVE_PARTIAL="${ARCHIVE}.partial"
ARCHIVE_COMPLETE=false

cleanup() {
    local exit_code=$?

    if (( exit_code != 0 )) && [[ "$DRY_RUN" != "true" && "$ARCHIVE_COMPLETE" != "true" ]]; then
        rm -f -- "$ARCHIVE_PARTIAL" "$ARCHIVE" \
            "${ARCHIVE}.sha256.partial" "${ARCHIVE}.sha256"
        warn "Removed incomplete backup outputs"
    fi

    if [[ "$DRY_RUN" != "true" && -d "$WORK_DIR" ]]; then
        if [[ "$KEEP_WORKDIR" == "true" ]]; then
            info "Keeping working directory: $WORK_DIR"
        else
            rm -rf -- "$WORK_DIR"
            info "Removed temporary working directory"
        fi
    fi

    if (( exit_code != 0 )); then
        warn "Backup failed with exit code $exit_code"
    fi
}
trap cleanup EXIT

validate_source_path() {
    local source_path="$1"
    local normalized_source="${source_path%/}"
    [[ -n "$normalized_source" ]] || normalized_source="/"

    [[ "$source_path" == /* ]] || fatal "BACKUP_PATHS entries must be absolute: $source_path"

    if [[ "$normalized_source" == "/" \
        || "$BACKUP_WORK_ROOT" == "$normalized_source" \
        || "$BACKUP_WORK_ROOT" == "$normalized_source/"* \
        || "$BACKUP_OUTPUT_DIR" == "$normalized_source" \
        || "$BACKUP_OUTPUT_DIR" == "$normalized_source/"* ]]; then
        fatal "Backup work/output directories must not be inside source path: $source_path"
    fi
}

validate_command_output() {
    local entry="$1"
    local output_name output_command
    IFS='|' read -r output_name output_command <<< "$entry"
    [[ -n "$output_name" && "$output_name" =~ ^[A-Za-z0-9._-]+\.txt$ && -n "$output_command" ]] \
        || fatal "Invalid COMMAND_OUTPUTS entry (expected output-name|command): $entry"
}

require_command tar
require_command zstd
require_command sha256sum

for source_path in "${BACKUP_PATHS[@]}"; do
    validate_source_path "$source_path"
done
declare -A SEEN_OUTPUT_NAMES=()
for command_output in "${COMMAND_OUTPUTS[@]}"; do
    validate_command_output "$command_output"
    IFS='|' read -r output_name _ <<< "$command_output"
    [[ -z "${SEEN_OUTPUT_NAMES[$output_name]:-}" ]] \
        || fatal "Duplicate COMMAND_OUTPUTS filename: $output_name"
    SEEN_OUTPUT_NAMES["$output_name"]=1
done

info "Phase 2 local backup started"
info "Backup name: $BACKUP_NAME"
info "Configuration: $CONFIG_FILE"
info "Dry run: $DRY_RUN"
info "Working directory: $WORK_DIR"
info "Archive: $ARCHIVE"
info "Configured paths: ${#BACKUP_PATHS[@]}"
info "Configured command outputs: ${#COMMAND_OUTPUTS[@]}"

if [[ "$DRY_RUN" == "true" ]]; then
    info "DRY RUN: would create working and output directories"
else
    mkdir -p "$BACKUP_WORK_ROOT" "$BACKUP_OUTPUT_DIR"
    mkdir "$WORK_DIR"
    mkdir "${WORK_DIR}/paths" "${WORK_DIR}/command_outputs"
fi

for source_path in "${BACKUP_PATHS[@]}"; do
    if [[ "$DRY_RUN" == "true" ]]; then
        if [[ -e "$source_path" ]]; then
            info "DRY RUN: would copy path: $source_path"
        else
            warn "DRY RUN: configured path does not exist: $source_path"
        fi
    else
        [[ -e "$source_path" ]] || fatal "Configured path does not exist: $source_path"
        info "Copying path without modifying source: $source_path"
        cp -a --parents -- "$source_path" "${WORK_DIR}/paths"
    fi
done

# Each trusted config entry uses output-name|command. stdout and stderr are
# captured together so that the resulting text file is useful for diagnosis.
for command_output in "${COMMAND_OUTPUTS[@]}"; do
    IFS='|' read -r output_name output_command <<< "$command_output"
    if [[ "$DRY_RUN" == "true" ]]; then
        info "DRY RUN: would run command and write command_outputs/$output_name"
    else
        info "Capturing command output: $output_name"
        if ! bash -o pipefail -c "$output_command" \
            > "${WORK_DIR}/command_outputs/${output_name}" 2>&1; then
            fatal "Command failed while creating command_outputs/$output_name"
        fi
    fi
done

compress_archive "$WORK_DIR" "$ARCHIVE_PARTIAL"
if [[ "$DRY_RUN" == "true" ]]; then
    info "DRY RUN: would atomically publish archive as $ARCHIVE"
else
    mv -- "$ARCHIVE_PARTIAL" "$ARCHIVE"
fi
generate_checksum "$ARCHIVE"

if [[ "$DRY_RUN" == "true" ]]; then
    info "DRY RUN complete; no working directory, archive, or checksum was created"
else
    ARCHIVE_COMPLETE=true
    archive_size="$(stat -c '%s' "$ARCHIVE")"
    info "Archive size: ${archive_size} bytes"
    info "Local backup completed successfully: $ARCHIVE"
    info "Checksum: ${ARCHIVE}.sha256"
fi

info "Phase 2 flow stopped after compression and checksum generation"

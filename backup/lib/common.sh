#!/usr/bin/env bash

# Shared logging, configuration, validation, and dry-run helpers.

log() {
    local level="$1"
    shift
    local message
    message="$(date -u +'%Y-%m-%dT%H:%M:%SZ') [$level] $*"

    if [[ -n "${LOG_FILE:-}" ]]; then
        printf '%s\n' "$message" | tee -a "$LOG_FILE"
    else
        printf '%s\n' "$message"
    fi
}

info() {
    log INFO "$@"
}

warn() {
    log WARN "$@" >&2
}

fatal() {
    log ERROR "$@" >&2
    exit 1
}

format_command() {
    printf '%q ' "$@"
}

run_command() {
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        info "DRY RUN: $(format_command "$@")"
        return 0
    fi
    "$@"
}

require_command() {
    local command_name="$1"
    if [[ "${DRY_RUN:-false}" != "true" ]] && ! command -v "$command_name" >/dev/null 2>&1; then
        fatal "Required command not found: $command_name"
    fi
}

load_config() {
    local config_file="$1"
    [[ -f "$config_file" ]] || fatal "Configuration file not found: $config_file"
    [[ -r "$config_file" ]] || fatal "Configuration file is not readable: $config_file"

    # Configurations are trusted Bash files so that they can define arrays.
    # shellcheck disable=SC1090
    source "$config_file"

    : "${BACKUP_NAME:?BACKUP_NAME must be set in the configuration}"
    : "${BACKUP_WORK_ROOT:=${BACKUP_BASE_DIR}/work}"
    : "${BACKUP_OUTPUT_DIR:=${BACKUP_BASE_DIR}/archives}"
    : "${KEEP_WORKDIR:=false}"
    : "${KEEP_LOCAL_BACKUPS:=7}"
    : "${FTP_ENABLED:=false}"
    : "${FTP_REMOTE_DIR:=/backups}"

    declare -p BACKUP_PATHS >/dev/null 2>&1 || BACKUP_PATHS=()
    declare -p COMMAND_CAPTURES >/dev/null 2>&1 || COMMAND_CAPTURES=()
    declare -p DATABASE_DUMPS >/dev/null 2>&1 || DATABASE_DUMPS=()

    [[ "$BACKUP_NAME" =~ ^[A-Za-z0-9._-]+$ ]] || fatal "BACKUP_NAME contains unsafe characters"
    [[ "$KEEP_LOCAL_BACKUPS" =~ ^[0-9]+$ ]] || fatal "KEEP_LOCAL_BACKUPS must be a non-negative integer"
    [[ "$KEEP_WORKDIR" == "true" || "$KEEP_WORKDIR" == "false" ]] || fatal "KEEP_WORKDIR must be true or false"
    [[ "$FTP_ENABLED" == "true" || "$FTP_ENABLED" == "false" ]] || fatal "FTP_ENABLED must be true or false"
}

init_logging() {
    local action="$1"
    mkdir -p "$BACKUP_LOG_DIR"
    LOG_FILE="${BACKUP_LOG_DIR}/${BACKUP_NAME}_${action}_${RUN_TIMESTAMP}.log"
    : > "$LOG_FILE"
}


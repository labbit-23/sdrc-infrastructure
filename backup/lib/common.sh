#!/usr/bin/env bash

# Shared logging, configuration validation, and dry-run helpers.

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

    # Required values must come from the selected config, not the environment.
    unset BACKUP_NAME BACKUP_PATHS COMMAND_OUTPUTS COMMAND_OUTPUTS_FATAL ENCRYPTION_ENABLED \
        AGE_BINARY AGE_RECIPIENTS_FILE AGE_IDENTITY_FILE KEEP_UNENCRYPTED_ARCHIVE FTP_ENABLED \
        FTP_HOST FTP_PORT FTP_USER FTP_PASSWORD_ENV FTP_REMOTE_DIR FTP_SSL_VERIFY_CERT

    # Configurations are trusted Bash files so that they can define arrays.
    # shellcheck disable=SC1090
    source "$config_file"

    [[ -n "${BACKUP_NAME:-}" ]] || fatal "BACKUP_NAME must be set in the configuration"
    [[ "$(declare -p BACKUP_PATHS 2>/dev/null || true)" == "declare -a "* ]] \
        || fatal "BACKUP_PATHS must be an indexed Bash array"
    [[ "$(declare -p COMMAND_OUTPUTS 2>/dev/null || true)" == "declare -a "* ]] \
        || fatal "COMMAND_OUTPUTS must be an indexed Bash array"

    : "${BACKUP_WORK_ROOT:=${BACKUP_BASE_DIR}/work}"
    : "${BACKUP_OUTPUT_DIR:=${BACKUP_BASE_DIR}/archives}"
    : "${KEEP_WORKDIR:=false}"
    : "${COMMAND_OUTPUTS_FATAL:=false}"
    : "${ENCRYPTION_ENABLED:=false}"
    : "${AGE_BINARY:=age}"
    : "${AGE_RECIPIENTS_FILE:=}"
    : "${AGE_IDENTITY_FILE:=}"
    : "${KEEP_UNENCRYPTED_ARCHIVE:=false}"
    : "${FTP_ENABLED:=false}"
    : "${FTP_HOST:=}"
    : "${FTP_PORT:=21}"
    : "${FTP_USER:=}"
    : "${FTP_PASSWORD_ENV:=SDRC_BACKUP_FTP_PASSWORD}"
    : "${FTP_REMOTE_DIR:=/backups}"
    : "${FTP_SSL_VERIFY_CERT:=true}"

    [[ "$BACKUP_NAME" =~ ^[A-Za-z0-9._-]+$ ]] || fatal "BACKUP_NAME contains unsafe characters"
    [[ "$KEEP_WORKDIR" == "true" || "$KEEP_WORKDIR" == "false" ]] || fatal "KEEP_WORKDIR must be true or false"
    [[ "$COMMAND_OUTPUTS_FATAL" == "true" || "$COMMAND_OUTPUTS_FATAL" == "false" ]] \
        || fatal "COMMAND_OUTPUTS_FATAL must be true or false"
    [[ "$ENCRYPTION_ENABLED" == "true" || "$ENCRYPTION_ENABLED" == "false" ]] \
        || fatal "ENCRYPTION_ENABLED must be true or false"
    [[ -n "$AGE_BINARY" ]] || fatal "AGE_BINARY must not be empty"
    [[ "$KEEP_UNENCRYPTED_ARCHIVE" == "true" || "$KEEP_UNENCRYPTED_ARCHIVE" == "false" ]] \
        || fatal "KEEP_UNENCRYPTED_ARCHIVE must be true or false"
    [[ "$FTP_ENABLED" == "true" || "$FTP_ENABLED" == "false" ]] \
        || fatal "FTP_ENABLED must be true or false"
    [[ "$FTP_SSL_VERIFY_CERT" == "true" || "$FTP_SSL_VERIFY_CERT" == "false" ]] \
        || fatal "FTP_SSL_VERIFY_CERT must be true or false"
    [[ "$FTP_PORT" =~ ^[0-9]+$ ]] && (( 10#$FTP_PORT >= 1 && 10#$FTP_PORT <= 65535 )) \
        || fatal "FTP_PORT must be an integer from 1 to 65535"
    [[ "$FTP_PASSWORD_ENV" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] \
        || fatal "FTP_PASSWORD_ENV must be a valid environment variable name"
    [[ "$FTP_REMOTE_DIR" =~ ^/[A-Za-z0-9._/-]*$ \
        && "/$FTP_REMOTE_DIR/" != *"/../"* ]] \
        || fatal "FTP_REMOTE_DIR must be a safe absolute FTP path"
    if [[ "$FTP_ENABLED" == "true" ]]; then
        validate_ftp_connection_config
    fi
    [[ "$BACKUP_WORK_ROOT" == /* ]] || fatal "BACKUP_WORK_ROOT must be an absolute path"
    [[ "$BACKUP_OUTPUT_DIR" == /* ]] || fatal "BACKUP_OUTPUT_DIR must be an absolute path"
}

validate_ftp_connection_config() {
    [[ "$FTP_HOST" =~ ^[A-Za-z0-9.-]+$ ]] \
        || fatal "FTP_HOST is required and must be a hostname or IPv4 address"
    [[ "$FTP_USER" =~ ^[A-Za-z0-9._@+%-]+$ ]] \
        || fatal "FTP_USER is required and contains unsupported characters"
}

init_logging() {
    local action="$1"
    mkdir -p "$BACKUP_LOG_DIR"
    LOG_FILE="${BACKUP_LOG_DIR}/${BACKUP_NAME}_${action}_${RUN_ID:-$RUN_TIMESTAMP}.log"
    : > "$LOG_FILE"
}

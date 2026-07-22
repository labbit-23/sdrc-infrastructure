#!/usr/bin/env bash

# Optional local retention pruning: keeps daily archives for a short window
# and weekly archives (one designated day of week) for a longer window, then
# deletes the rest. Disabled by default; only runs after a successful backup.
#
# Archive filenames are always ${BACKUP_NAME}_${RUN_TIMESTAMP}_${PID}.tar.zst
# (RUN_TIMESTAMP is UTC, format %Y%m%dT%H%M%SZ, set by backup.sh). Pruning
# parses that timestamp back out of the filename; it never relies on mtime,
# so copying/restoring archives elsewhere does not confuse retention.

validate_retention_config() {
    [[ "$RETENTION_ENABLED" == "true" || "$RETENTION_ENABLED" == "false" ]] \
        || fatal "RETENTION_ENABLED must be true or false"
    if [[ "$RETENTION_ENABLED" == "true" ]]; then
        [[ "$RETENTION_DAILY_DAYS" =~ ^[0-9]+$ && "$RETENTION_DAILY_DAYS" -ge 1 ]] \
            || fatal "RETENTION_DAILY_DAYS must be a positive integer"
        [[ "$RETENTION_WEEKLY_DAYS" =~ ^[0-9]+$ && "$RETENTION_WEEKLY_DAYS" -ge 1 ]] \
            || fatal "RETENTION_WEEKLY_DAYS must be a positive integer"
        [[ "$RETENTION_WEEKLY_DOW" =~ ^[1-7]$ ]] \
            || fatal "RETENTION_WEEKLY_DOW must be an integer from 1 (Monday) to 7 (Sunday)"
        (( RETENTION_WEEKLY_DAYS >= RETENTION_DAILY_DAYS )) \
            || fatal "RETENTION_WEEKLY_DAYS must be >= RETENTION_DAILY_DAYS"
    fi
}

# Prints 1 (weekly) or 0 (daily) for a given RUN_TIMESTAMP-shaped string.
_retention_is_weekly() {
    local run_timestamp="$1"
    local iso dow
    iso="${run_timestamp:0:4}-${run_timestamp:4:2}-${run_timestamp:6:2}"
    dow="$(date -u -d "$iso" +%u)" || fatal "Could not parse archive timestamp: $run_timestamp"
    [[ "$dow" == "$RETENTION_WEEKLY_DOW" ]] && echo 1 || echo 0
}

prune_local_archives() {
    [[ "$RETENTION_ENABLED" == "true" ]] || { info "Retention pruning is disabled"; return 0; }

    if [[ "$DRY_RUN" == "true" ]]; then
        info "DRY RUN: would prune ${BACKUP_OUTPUT_DIR} keeping daily=${RETENTION_DAILY_DAYS}d weekly(dow=${RETENTION_WEEKLY_DOW})=${RETENTION_WEEKLY_DAYS}d"
        return 0
    fi

    [[ -d "$BACKUP_OUTPUT_DIR" ]] || { info "Retention: no output directory yet, nothing to prune"; return 0; }

    local now_epoch daily_cutoff weekly_cutoff
    now_epoch="$(date -u +%s)"
    daily_cutoff=$(( now_epoch - RETENTION_DAILY_DAYS * 86400 ))
    weekly_cutoff=$(( now_epoch - RETENTION_WEEKLY_DAYS * 86400 ))

    local base run_timestamp archive_epoch is_weekly cutoff pruned=0
    for base in "${BACKUP_OUTPUT_DIR}/${BACKUP_NAME}_"*.tar.zst; do
        [[ -e "$base" ]] || continue
        # Strip prefix/suffix to isolate RUN_TIMESTAMP_PID, then the timestamp.
        run_timestamp="$(basename "$base")"
        run_timestamp="${run_timestamp#"${BACKUP_NAME}"_}"
        run_timestamp="${run_timestamp%%_*}"
        [[ "$run_timestamp" =~ ^[0-9]{8}T[0-9]{6}Z$ ]] || {
            warn "Retention: skipping archive with unexpected name: $base"
            continue
        }

        archive_epoch="$(date -u -d "${run_timestamp:0:4}-${run_timestamp:4:2}-${run_timestamp:6:2}T${run_timestamp:9:2}:${run_timestamp:11:2}:${run_timestamp:13:2}Z" +%s)" \
            || { warn "Retention: could not parse timestamp, skipping: $base"; continue; }

        is_weekly="$(_retention_is_weekly "$run_timestamp")"
        if [[ "$is_weekly" == "1" ]]; then
            cutoff="$weekly_cutoff"
        else
            cutoff="$daily_cutoff"
        fi

        if (( archive_epoch < cutoff )); then
            info "Retention: pruning $(basename "$base") (weekly=${is_weekly})"
            rm -f -- "$base" "${base}.sha256" "${base}.age" "${base}.age.sha256"
            pruned=$(( pruned + 1 ))
        fi
    done
    info "Retention: pruned ${pruned} archive(s) from ${BACKUP_OUTPUT_DIR}"
}

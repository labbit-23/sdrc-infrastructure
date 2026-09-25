#!/usr/bin/env bash
# Prune labit_core.audit_log by table class.
#
#   TRANSACTIONAL tables : keep 6 months (TRANSACTIONAL_KEEP_MONTHS)
#   everything else      : keep indefinitely (masters, patient, and any table
#                          added later -- unclassified tables are never pruned)
#
# Policy set by the lab director 2026-09-25: "6 month retention on
# transactional audits and as long as possible on masters." This replaces the
# earlier 3-day (system actor) / 30-day (human actor) split.
#
# Classification is an explicit allowlist (below), not a denylist, so a new
# table's audit trail is retained by default until someone decides to add it.
# `patient` is deliberately NOT in the list: it is master data, and its audit
# rows are low volume in normal operation.
#
# KNOWN RISK: the 2026-09 bloat (6.6M rows, 2.5 GB) was system-actor churn on
# labit_core.patient from migration/seeding passes. Because patient is now kept
# indefinitely, a future bulk re-seed will bloat the table again and this script
# will not remove it. Do bulk re-seeds with audit disabled for the session or
# prune that churn by hand.
#
# Safe by default: without --execute it only reports what WOULD be deleted.
# Deletes in batches so it never holds a long lock on a table that every write
# touches via trigger. Safe to re-run.
#
# Usage: prune_audit_log.sh [--execute]
set -euo pipefail

TRANSACTIONAL_TABLES=(
    "labit_core.result"
    "labit_core.report"
    "labit_core.requisition"
    "labit_core.requisition_item"
    "labit_core.sample"
    "labit_core.sample_event"
    "labit_core.radiology_report"
)
TRANSACTIONAL_KEEP_MONTHS="${TRANSACTIONAL_KEEP_MONTHS:-6}"
BATCH="${BATCH:-50000}"
DB_HOST="${DB_HOST:-root@supabase.sdrc.in}"

EXECUTE=false
case "${1:-}" in
    --execute) EXECUTE=true ;;
    "") ;;
    *) echo "Usage: $0 [--execute]" >&2; exit 2 ;;
esac

log() { printf '%s [prune-audit] %s\n' "$(date -Is)" "$*"; }

run_sql() {
    ssh -o BatchMode=yes -o ConnectTimeout=10 "$DB_HOST" \
        "docker exec -i supabase-db psql -U postgres -d postgres -v ON_ERROR_STOP=1 -tAc \"$1\""
}

table_list=$(printf "'%s'," "${TRANSACTIONAL_TABLES[@]}")
table_list="${table_list%,}"
WHERE="table_name IN (${table_list}) AND changed_at < now() - interval '${TRANSACTIONAL_KEEP_MONTHS} months'"

log "policy: transactional=${TRANSACTIONAL_KEEP_MONTHS} months, all other tables kept; execute=${EXECUTE}"

before=$(run_sql "SELECT count(*) FROM labit_core.audit_log")
size_before=$(run_sql "SELECT pg_size_pretty(pg_total_relation_size('labit_core.audit_log'))")
eligible=$(run_sql "SELECT count(*) FROM labit_core.audit_log WHERE ${WHERE}")
log "before: ${before} rows, ${size_before}; eligible for deletion: ${eligible}"

if [ "$EXECUTE" != "true" ]; then
    log "dry run only; pass --execute to delete"
    exit 0
fi

total=0
while :; do
    n=$(run_sql "
        WITH doomed AS (
            SELECT id FROM labit_core.audit_log
            WHERE ${WHERE}
            LIMIT ${BATCH}
        )
        DELETE FROM labit_core.audit_log a USING doomed d WHERE a.id = d.id
        RETURNING 1" | wc -l)
    total=$((total + n))
    [ "$n" -eq 0 ] && break
    log "  deleted ${total} so far"
done

after=$(run_sql "SELECT count(*) FROM labit_core.audit_log")
log "after: ${after} rows (removed ${total}). Disk is not returned until a REINDEX/VACUUM FULL."

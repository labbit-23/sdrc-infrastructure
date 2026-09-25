#!/usr/bin/env bash
# One-shot restore of labit_core / public schema-dump archives into plain
# PostgreSQL 15 (no Supabase needed): verify -> decrypt -> extract -> create DB ->
# extensions/roles -> load -> re-run failed indexes -> role passwords + grants ->
# ANALYZE -> verdict. Standalone: needs only bash, tar, zstd, psql (and age for
# .age archives). Uses the standard PG* environment for the connection and must
# connect as a superuser.
#
# Usage:
#   restore-db.sh [options] ARCHIVE [ARCHIVE...]
#     --db NAME          target database (default: restore)
#     --create-db        create it (fails if it already exists)
#     --identity FILE    age identity (private key) for .age archives
#     --roles-file FILE  roles+grants file to use instead of the one inside the
#                        archive (older archives predate it)
#     --reindex          also REINDEX the whole database
#     --keep-work        keep the extracted files (contain real data; default: wipe)
#
# Give it the labit_core archive first, then optionally the public archive.
# Role passwords: an archive made with PG_INCLUDE_PASSWORD_HASHES=1 restores the
# ORIGINAL password hashes, so existing application DSNs work unchanged.
# Without that file it falls back to scripts/postgres-bootstrap/02-grants.sql and
# the roles have NO password (set them with ALTER ROLE).
set -euo pipefail
umask 077

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BOOT="${SCRIPT_DIR}/../scripts/postgres-bootstrap"
DB=restore; CREATE_DB=false; IDENTITY=""; ROLES_OVERRIDE=""; REINDEX=false; KEEP_WORK=false
ARCHIVES=()

while (( $# > 0 )); do
    case "$1" in
        --db) DB="$2"; shift ;;
        --create-db) CREATE_DB=true ;;
        --identity) IDENTITY="$2"; shift ;;
        --roles-file) ROLES_OVERRIDE="$2"; shift ;;
        --reindex) REINDEX=true ;;
        --keep-work) KEEP_WORK=true ;;
        -h|--help) sed -n '2,25p' "$0"; exit 0 ;;
        -*) echo "Unknown option: $1" >&2; exit 2 ;;
        *) ARCHIVES+=("$1") ;;
    esac
    shift
done
(( ${#ARCHIVES[@]} > 0 )) || { echo "Give at least one archive" >&2; exit 2; }
[[ "$DB" =~ ^[A-Za-z0-9_]+$ ]] || { echo "Unsafe database name" >&2; exit 2; }
[[ -d "$BOOT" ]] || { echo "Missing $BOOT (run from a full repo checkout)" >&2; exit 2; }
for c in tar zstd psql; do command -v "$c" >/dev/null || { echo "Missing command: $c" >&2; exit 2; }; done

log() { printf '%s [restore-db] %s\n' "$(date -u +%H:%M:%S)" "$*"; }
PSQL=(psql -X -q -v ON_ERROR_STOP=0)
WORK="$(mktemp -d "${TMPDIR:-/tmp}/restore-db.XXXXXX")"
cleanup() { [[ "$KEEP_WORK" == "true" ]] || rm -rf "$WORK"; }
trap cleanup EXIT
FAILS=0; WARNS=0
START=$(date +%s)

# 1. verify + decrypt + extract each archive
DUMPS=(); ROLES_FILE="$ROLES_OVERRIDE"; n=0
for A in "${ARCHIVES[@]}"; do
    n=$((n+1)); D="$WORK/a$n"; mkdir -p "$D"
    if [[ -f "$A.sha256" ]]; then
        (cd "$(dirname "$A")" && sha256sum -c "$(basename "$A").sha256" >/dev/null) \
            && log "checksum OK: $(basename "$A")" || { log "CHECKSUM FAILED: $A"; exit 1; }
    else
        log "WARN no .sha256 next to $(basename "$A"); integrity not verified"; WARNS=$((WARNS+1))
    fi
    if [[ "$A" == *.age ]]; then
        [[ -n "$IDENTITY" ]] || { log "encrypted archive needs --identity"; exit 2; }
        command -v age >/dev/null || { log "age not installed"; exit 2; }
        age -d -i "$IDENTITY" "$A" | zstd -dc | tar -xf - -C "$D"
    else
        zstd -dc "$A" | tar -xf - -C "$D"
    fi
    while IFS= read -r f; do DUMPS+=("$f"); done < <(find "$D/command_outputs" -name '*schema-dump.txt' 2>/dev/null | sort)
    if [[ -z "$ROLES_FILE" ]]; then
        r="$(find "$D/command_outputs" -name '*roles-and-grants.txt' 2>/dev/null | head -1)"; [[ -n "$r" ]] && ROLES_FILE="$r"
    fi
done
(( ${#DUMPS[@]} > 0 )) || { log "no *schema-dump.txt inside the archive(s)"; exit 1; }
log "extracted: ${#DUMPS[@]} dump file(s); roles file: ${ROLES_FILE:-none (fallback to repo grants, NO passwords)}"

# 2. database + extensions/roles
if [[ "$CREATE_DB" == "true" ]]; then
    "${PSQL[@]}" -d postgres -v ON_ERROR_STOP=1 -c "CREATE DATABASE \"$DB\"" || { log "cannot create $DB"; exit 1; }
fi
"${PSQL[@]}" -d "$DB" -v ON_ERROR_STOP=1 -v dbname="$DB" -f "$BOOT/01-roles-and-extensions.sql" >/dev/null 2>"$WORK/boot.err" \
    || { log "bootstrap failed: $(head -2 "$WORK/boot.err")"; exit 1; }
log "extensions and base roles ready"

# 3. roles (attributes, original password hashes) before the load
if [[ -n "$ROLES_FILE" ]]; then
    awk '/^-- privileges/{exit} {print}' "$ROLES_FILE" | grep -v '^CREATE ROLE' \
        | "${PSQL[@]}" -d "$DB" 2>"$WORK/roles.err" || true
    e=$(grep -c ERROR "$WORK/roles.err" || true); (( e == 0 )) && log "roles applied (attributes + password hashes if present)" \
        || { log "FAIL roles: $e errors, first: $(grep ERROR "$WORK/roles.err" | head -1)"; FAILS=$((FAILS+1)); }
fi

# 4. load dumps; retry failed single-line index statements once
for F in "${DUMPS[@]}"; do
    log "loading $(basename "$F") ($(du -h "$F" | cut -f1))"
    "${PSQL[@]}" -d "$DB" -f "$F" >/dev/null 2>"$WORK/load.err" || true
    e=$(grep -c ERROR "$WORK/load.err" || true)
    if (( e > 0 )); then
        log "  $e error(s) on first pass; retrying failed index statements"
        : > "$WORK/retry.sql"
        for ln in $(grep ERROR "$WORK/load.err" | sed -nE 's/^psql:[^:]*:([0-9]+):.*/\1/p'); do
            sed -n "${ln}p" "$F" | grep -E '^CREATE (UNIQUE )?INDEX .*;$' >> "$WORK/retry.sql" || true
        done
        "${PSQL[@]}" -d "$DB" -f "$WORK/retry.sql" >/dev/null 2>"$WORK/retry.err" || true
        left=$(( e - $(wc -l < "$WORK/retry.sql") + $(grep -c ERROR "$WORK/retry.err" || true) ))
        if (( left > 0 )); then
            log "  FAIL $left error(s) remain; distinct causes:"
            grep ERROR "$WORK/load.err" | sed -E 's/^psql:[^:]*:[0-9]+: //' | sort | uniq -c | sort -rn | head -5 | sed 's/^/    /'
            FAILS=$((FAILS+1))
        else log "  all retried indexes built"; fi
    fi
done

# 5. grants (from the archive's roles file, else the repo fallback)
if [[ -n "$ROLES_FILE" ]] && grep -q '^-- privileges' "$ROLES_FILE"; then
    awk 'f{print} /^-- privileges/{f=1}' "$ROLES_FILE" > "$WORK/grants.sql"; SRC="archive"
else
    grep -v '^--' "$BOOT/02-grants.sql" > "$WORK/grants.sql"; SRC="repo fallback (no passwords!)"; WARNS=$((WARNS+1))
fi
"${PSQL[@]}" -d "$DB" -f "$WORK/grants.sql" >/dev/null 2>"$WORK/grants.err" || true
total=$(grep -c . "$WORK/grants.sql")
# Only a missing table/function/column/sequence is expected (the object lives in a
# schema that was not restored, or is newer than the backup). A missing ROLE or
# any other error is a real problem.
missing=$(grep ERROR "$WORK/grants.err" | grep -cE '(relation|function|table|column|sequence|schema) .*does not exist' || true)
other=$(grep ERROR "$WORK/grants.err" | grep -vcE '(relation|function|table|column|sequence|schema) .*does not exist' || true)
log "grants from $SRC: $total statements, $missing skipped (object not in the restored schema(s)), $other other error(s)"
(( other > 0 )) && { grep ERROR "$WORK/grants.err" | grep -vE '(relation|function|table|column|sequence|schema) .*does not exist' | head -3 | sed 's/^/    /'; FAILS=$((FAILS+1)); }
(( missing > 0 )) && WARNS=$((WARNS+1))

# 6. statistics, optional reindex, checks
"${PSQL[@]}" -d "$DB" -c "ANALYZE" >/dev/null 2>&1 || true
if [[ "$REINDEX" == "true" ]]; then log "REINDEX DATABASE"; "${PSQL[@]}" -d "$DB" -c "REINDEX DATABASE \"$DB\"" >/dev/null 2>&1 || { log "reindex failed"; FAILS=$((FAILS+1)); }; fi
q() { psql -X -At -d "$DB" -c "$1"; }
INVALID=$(q "SELECT count(*) FROM pg_index WHERE NOT indisvalid")
TABLES=$(q "SELECT string_agg(schemaname||'='||c, ', ') FROM (SELECT schemaname, count(*) c FROM pg_tables WHERE schemaname IN ('labit_core','public') GROUP BY 1 ORDER BY 1) x")
IDX=$(q "SELECT count(*) FROM pg_indexes WHERE schemaname IN ('labit_core','public')")
PWROLES=$(q "SELECT count(*) FROM pg_authid WHERE rolname IN ('labit_core_rw','labit_app_api','labit_main_rw','shivam_archive_ro','cto_digest') AND rolpassword IS NOT NULL")
log "tables: ${TABLES:-none}; indexes: $IDX (invalid: $INVALID); app roles with a password: $PWROLES/5"
(( INVALID > 0 )) && FAILS=$((FAILS+1))

SECS=$(( $(date +%s) - START ))
if (( FAILS == 0 )); then log "RESULT: OK in ${SECS}s ($WARNS warning(s))"; exit 0
else log "RESULT: FAILED ($FAILS problem(s), $WARNS warning(s)) after ${SECS}s"; exit 1; fi

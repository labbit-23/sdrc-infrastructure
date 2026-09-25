#!/usr/bin/env bash
# Emit the roles and privileges that the schema dumps deliberately omit
# (pg_dump runs with --no-owner --no-privileges), so an archive is enough to
# rebuild a working database: CREATE ROLE statements (attributes only, NO
# password HASHES only when PG_INCLUDE_PASSWORD_HASHES=1) for the app roles, plus
# every GRANT/REVOKE/ALTER DEFAULT PRIVILEGES on schemas labit_core and public
# that involves an app role.
#
# PASSWORD HASHES: with PG_INCLUDE_PASSWORD_HASHES=1 the output contains the
# roles' SCRAM-SHA-256 verifiers (never plaintext), so a restored database
# accepts the apps' existing connection strings unchanged. Only enable this
# in a config whose archives are age-encrypted (ENCRYPTION_ENABLED=true and
# KEEP_UNENCRYPTED_ARCHIVE=false); the default omits them.
#
# Read-only. Runs `docker exec` as the in-container postgres superuser over SSH
# (the same access prune_audit_log.sh uses), so it needs no password.
# Meant to run FROM devserver as a COMMAND_OUTPUTS entry. stdout only.
#
# Optional environment override:
#   LABIT_PG_BACKUP_SSH_HOST  (default root@supabase.sdrc.in)
set -euo pipefail

SSH_HOST="${LABIT_PG_BACKUP_SSH_HOST:-root@supabase.sdrc.in}"
CONTAINER="${LABIT_PG_BACKUP_CONTAINER:-supabase-db}"
ROLE_RE='labit_|cto_|shivam|main'

run() { ssh -o BatchMode=yes -o ConnectTimeout=10 "$SSH_HOST" "docker exec -i $CONTAINER $*"; }

NOPW=(--no-role-passwords)
[[ "${PG_INCLUDE_PASSWORD_HASHES:-0}" == "1" ]] && NOPW=()
echo "-- roles; password hashes included: ${PG_INCLUDE_PASSWORD_HASHES:-0}; captured $(date -u +%FT%TZ)"
run pg_dumpall -U postgres --roles-only "${NOPW[@]}" \
    | grep -E "^(CREATE ROLE|ALTER ROLE|GRANT .* TO)" | grep -E "$ROLE_RE" \
    | grep -v -E "labit_deliver" || true
echo "-- privileges"
run pg_dump -U postgres -d postgres -s -n labit_core -n public --no-owner \
    | grep -E "^(GRANT|REVOKE|ALTER DEFAULT PRIVILEGES)" | grep -E "$ROLE_RE" \
    | grep -v -E "labit_deliver"

#!/usr/bin/env bash
# Stream a plain-SQL pg_dump of the labit_core schema from the shared
# supabase-db Postgres container on VPS2, over SSH, to stdout.
#
# Meant to be run from a machine OTHER than VPS2 (the devserver, or any LAN
# host with SSH access to root@supabase.sdrc.in) — this is the pull side of
# backup/config/vps2-labit-core.example.conf's COMMAND_OUTPUTS entry. The
# generic backup engine (backup/backup.sh) captures this script's stdout into
# a .txt file inside the archive it builds, then zstd-compresses the whole
# archive — plain SQL compresses far better than pg_dump's own custom (-Fc)
# binary format would after already being zstd'd, so this intentionally uses
# -Fp (plain SQL) rather than a binary dump format.
#
# Schema-scoped on purpose (-n labit_core), matching this codebase's "iron
# rule" (labit-core writes/owns only the labit_core schema). The much larger
# diagnotech/ots1/admin/... legacy archive schemas already have their own
# dedicated backup path: ~/projects/sdrc/shivam-archive/deploy/backup_archive.sh
# and backup_archive_stream.sh. Do not duplicate that here.
#
# Required environment:
#   LABIT_PG_BACKUP_PASSWORD  - supabase-db postgres role password. Never put
#     this in a config file or this script. Fetch it once per shell:
#       export LABIT_PG_BACKUP_PASSWORD=$(ssh root@supabase.sdrc.in \
#         "grep '^POSTGRES_PASSWORD=' /opt/supabase/docker/.env | cut -d= -f2-")
#
# Optional environment overrides:
#   LABIT_PG_BACKUP_SSH_HOST   (default root@supabase.sdrc.in)
#   LABIT_PG_BACKUP_CONTAINER  (default supabase-db)
#   LABIT_PG_BACKUP_PG_USER    (default postgres)
#   LABIT_PG_BACKUP_PG_DB      (default postgres)
#   LABIT_PG_BACKUP_SCHEMA     (default labit_core)

set -euo pipefail

SSH_HOST="${LABIT_PG_BACKUP_SSH_HOST:-root@supabase.sdrc.in}"
CONTAINER="${LABIT_PG_BACKUP_CONTAINER:-supabase-db}"
PG_USER="${LABIT_PG_BACKUP_PG_USER:-postgres}"
PG_DB="${LABIT_PG_BACKUP_PG_DB:-postgres}"
SCHEMA="${LABIT_PG_BACKUP_SCHEMA:-labit_core}"

[[ -n "${LABIT_PG_BACKUP_PASSWORD:-}" ]] \
    || { echo "LABIT_PG_BACKUP_PASSWORD is not set; see this script's header." >&2; exit 1; }

# Password travels over the SSH-encrypted stdin channel only, never as a
# `docker exec -e KEY=VALUE` argv -- `docker exec -e` puts the value in
# plaintext in `ps aux` output on the container host (found live,
# 2026-09-03: visible to any local shell user, and briefly surfaced in an
# agent's own tool output/transcript capturing that `ps aux`). The remote
# side reads one line from its own stdin into PGPASSWORD before exec'ing
# pg_dump, so the value never appears in any process listing anywhere.
remote_cmd=$(printf 'docker exec -i %q sh -c '\''read -r PGPASSWORD && export PGPASSWORD && exec pg_dump -U %q -d %q -n %q --no-owner --no-privileges -Fp'\''' \
    "$CONTAINER" "$PG_USER" "$PG_DB" "$SCHEMA")

ssh -o BatchMode=yes -o ConnectTimeout=10 "$SSH_HOST" "$remote_cmd" <<< "$LABIT_PG_BACKUP_PASSWORD"

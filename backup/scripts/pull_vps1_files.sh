#!/usr/bin/env bash

# Stream a tar of specific files/directories from VPS1 over SSH, to stdout,
# for backup.sh (run FROM devserver) to capture as a COMMAND_OUTPUTS entry.
# Mirrors pg_dump_labit_core.sh's pattern: VPS1 is a pure data source and
# needs nothing installed, holds no Drive/age credential, and runs no cron
# job of its own -- devserver stays the single backup pipeline.
#
# Paths discovered 2026-09-25 (see inventory/vps1.md): nginx config/certs,
# PM2's saved process definitions, active application .env files, and the
# Jasper report templates (in git, but observed with server-only drift).
# Excludes /opt/supabase and /opt/supabase-template: dormant ~3.1GB clones
# with no running containers, not backup-worthy.
#
# stdout carries ONLY the tar stream -- nothing else may be written there.
# Diagnostics go to stderr, which backup.sh routes to its own log for a
# .tar COMMAND_OUTPUTS entry (never merged into the captured bytes).
#
# Optional environment override:
#   VPS1_BACKUP_SSH_HOST  (default root@api.sdrc.in)

set -euo pipefail

SSH_HOST="${VPS1_BACKUP_SSH_HOST:-root@api.sdrc.in}"

PATHS=(
    "/etc/nginx"
    "/etc/letsencrypt"
    "/root/.pm2/dump.pm2"
    "/opt/labbit-ops/cto-collector/.env"
    "/opt/labbit-py/.env"
    "/opt/shivam-archive/.env"
    "/opt/labit/labit-app/api/.env"
    "/opt/labit/labit-core/.env"
    "/opt/labit/labit-patient/.env.local"
    "/opt/labit/labit-deliver/.env"
    "/opt/labit/labit-ui/.env.local"
    "/opt/labbit-frontend/.env.production"
    "/opt/labbit-frontend/.env.local"
    "/opt/labit/labit-jasper/templates"
)

# tar -C / with paths with the leading slash stripped avoids the
# "Removing leading `/'" warning that plain absolute paths would print to
# stderr on every run -- harmless where it goes, but avoidable noise.
relative_paths=()
for path in "${PATHS[@]}"; do
    relative_paths+=("${path#/}")
done

remote_cmd=$(printf 'tar -cf - -C / --ignore-failed-read %s' \
    "$(printf '%q ' "${relative_paths[@]}")")

ssh -T -o BatchMode=yes -o ConnectTimeout=10 "$SSH_HOST" "$remote_cmd"

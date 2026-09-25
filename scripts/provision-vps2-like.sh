#!/usr/bin/env bash
set -euo pipefail

# Bring a bare Ubuntu 24.04 LTS machine up to the same RUNTIME as VPS2
# (ubuntu-4gb-hel1-2) -- Docker/Compose, Node.js, PM2 -- so it can receive a
# restored Supabase config + database dump, either for a restore test or to
# actually rebuild VPS2's role on new hardware/a new provider.
#
# VPS2 itself still runs Ubuntu 22.04.5 (see inventory/vps2.md), but
# INFRASTRUCTURE.md already documents a planned staged upgrade to 24.04 for
# both VPS1 and VPS2, and devserver itself already runs 24.04.5. Since this
# targets fresh hardware with no existing OS to match, there's no reason to
# provision something already slated for replacement -- this targets 24.04
# directly. Everything Supabase-relevant runs in Docker regardless of host
# OS; Docker's official repo and NodeSource both support 24.04 (noble)
# identically to 22.04 (jammy).
#
# Versions/packages otherwise match inventory/vps2.md (last confirmed
# 2026-09-25): Docker 29.8.1 / Compose 5.5.1, Node.js 20.x (NodeSource).
# Exact Docker/Compose patch versions are not pinned -- this installs current
# stable from Docker's official repo, which is what VPS2 itself tracks.
#
# Usage:
#   ./provision-vps2-like.sh [--dry-run] [--sync-config]
#
#   --dry-run       Print what would run; change nothing.
#   --sync-config   Additionally pull the REAL docker-compose.yml,
#                   docker-compose.labit-db.yml, and volumes/db/*.sql
#                   (non-data config, no secrets) from the live VPS2 host
#                   over SSH, so this machine's config matches production
#                   instead of being hand-guessed. Does NOT pull .env
#                   (secrets) or volumes/db/data (live database files) --
#                   .env must come from a separate, deliberate secret
#                   restore step; data comes from a decrypted backup dump,
#                   not a raw copy of the live data directory.
#
# Requires: run as a user with sudo, on a fresh Ubuntu 24.04 LTS host with
# outbound internet access and (for --sync-config) SSH access to
# root@supabase.sdrc.in.

DRY_RUN=false
SYNC_CONFIG=false
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=true ;;
        --sync-config) SYNC_CONFIG=true ;;
        -h|--help)
            printf '%s\n' "Usage: $0 [--dry-run] [--sync-config]"
            exit 0
            ;;
        *) echo "Unknown argument: $arg" >&2; exit 2 ;;
    esac
done

run() {
    if [[ "$DRY_RUN" == "true" ]]; then
        printf 'DRY RUN: %s\n' "$*"
    else
        "$@"
    fi
}

echo "== VPS2-like provisioning (dry-run: $DRY_RUN, sync-config: $SYNC_CONFIG) =="

if [[ "$DRY_RUN" != "true" ]]; then
    . /etc/os-release
    if [[ "${VERSION_ID:-}" != "24.04" ]]; then
        echo "WARNING: this host reports Ubuntu ${VERSION_ID:-unknown}, not the targeted 24.04." >&2
        echo "Continuing, but package availability/behavior may differ." >&2
    fi
fi

echo "-- Base packages --"
run sudo apt-get update
run sudo apt-get install -y ca-certificates curl gnupg

echo "-- Docker CE (official repo, matches VPS2's install method) --"
if [[ "$DRY_RUN" == "true" ]] || ! command -v docker >/dev/null 2>&1; then
    run sudo install -m 0755 -d /etc/apt/keyrings
    run bash -c 'curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg'
    run sudo chmod a+r /etc/apt/keyrings/docker.gpg
    run bash -c '
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
            | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    '
    run sudo apt-get update
    run sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
else
    echo "docker already installed, skipping: $(docker --version)"
fi

echo "-- Node.js 20.x (NodeSource, matches VPS2) --"
if [[ "$DRY_RUN" == "true" ]] || ! command -v node >/dev/null 2>&1; then
    run bash -c 'curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -'
    run sudo apt-get install -y nodejs
else
    echo "node already installed, skipping: $(node --version)"
fi

echo "-- PM2 --"
run sudo npm install -g pm2

echo "-- Directory structure (empty; config/data populated by restore) --"
run sudo mkdir -p /opt/supabase/docker/volumes/db

if [[ "$SYNC_CONFIG" == "true" ]]; then
    echo "-- Pulling real config from root@supabase.sdrc.in (compose files + non-data SQL only, no .env, no data) --"
    run bash -c '
        set -euo pipefail
        ssh -o BatchMode=yes -o ConnectTimeout=10 root@supabase.sdrc.in \
            "tar -cf - -C /opt/supabase/docker docker-compose.yml docker-compose.labit-db.yml volumes/db/jwt.sql volumes/db/logs.sql volumes/db/pooler.sql volumes/db/realtime.sql volumes/db/roles.sql volumes/db/_supabase.sql volumes/db/webhooks.sql" \
            | sudo tar -xf - -C /opt/supabase/docker
    '
    echo "Synced. NOTE: VPS2 also has docker-compose.caddy.yml/.nginx.yml/.rustfs.yml/.s3.yml present but"
    echo "not documented as in-use in inventory/vps2.md -- verify with the team whether those are live"
    echo "before assuming docker-compose.yml + docker-compose.labit-db.yml is the complete picture."
fi

echo
echo "== Done =="
echo "This machine now has VPS2's runtime, but no Supabase config/secrets/data yet."
echo "Next steps (not done by this script):"
echo "  1. Restore /opt/supabase/docker/.env from a secret store (never from git, never logged)."
echo "  2. Decrypt a backup archive and import the schema dump(s) per runbooks/postgres-restore.md."
echo "  3. docker compose -f docker-compose.yml -f docker-compose.labit-db.yml up -d"

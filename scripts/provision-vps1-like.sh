#!/usr/bin/env bash
set -euo pipefail

# Bring a bare Ubuntu 24.04 LTS machine up to the same RUNTIME as VPS1
# (ubuntu-4gb-hel1-1) -- Node.js, PM2, nginx, OpenJDK, Python, Docker -- so
# it can receive redeployed application code + a restored .env/PM2 dump/
# nginx config, either for a restore test or to actually rebuild VPS1's
# role on new hardware/a new provider.
#
# VPS1 itself still runs Ubuntu 22.04.5 (see inventory/vps1.md), but
# INFRASTRUCTURE.md documents a planned staged upgrade to 24.04, and this
# targets fresh hardware with no existing OS to match -- see
# provision-vps2-like.sh's header for the same reasoning in more detail.
#
# Deliberately does NOT: clone/deploy any application repo, restore .env
# files, restore the PM2 dump, or start nginx/PM2 with real config. Those
# are separate restore steps using an actual backup archive (see
# backup/config/vps1.conf and backup/scripts/pull_vps1_files.sh for what a
# VPS1 backup actually contains) -- kept separate so this script stays
# reusable for disaster recovery, not just restore-testing.
#
# Versions/packages match inventory/vps1.md (last confirmed 2026-09-25):
#   Node.js 22.x (NodeSource), PM2, nginx, OpenJDK 21, Python 3 (24.04 ships
#   3.12 by default -- VPS1's 3.10 was Ubuntu 22.04's default, not a
#   deliberately pinned version; no known VPS1 app requires exactly 3.10).
#
# Usage:
#   ./provision-vps1-like.sh [--dry-run]
#
# Requires: run as a user with sudo, on a fresh Ubuntu 24.04 LTS host with
# outbound internet access.

DRY_RUN=false
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=true ;;
        -h|--help)
            printf '%s\n' "Usage: $0 [--dry-run]"
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

echo "== VPS1-like provisioning (dry-run: $DRY_RUN) =="

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

echo "-- Node.js 22.x (NodeSource, matches VPS1) --"
if [[ "$DRY_RUN" == "true" ]] || ! command -v node >/dev/null 2>&1; then
    run bash -c 'curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -'
    run sudo apt-get install -y nodejs
else
    echo "node already installed, skipping: $(node --version)"
fi

echo "-- PM2 --"
run sudo npm install -g pm2

echo "-- nginx --"
run sudo apt-get install -y nginx

echo "-- OpenJDK 21 (for Jasper reports) --"
run sudo apt-get install -y openjdk-21-jdk

echo "-- Python 3 + pip + venv --"
run sudo apt-get install -y python3 python3-pip python3-venv

echo "-- Docker CE (present on VPS1; same official-repo method as VPS2) --"
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

echo "-- Directory structure (empty; app code/config populated by restore) --"
run sudo mkdir -p /opt/labit /opt/labbit-py /opt/labbit-ops /opt/labbit-frontend /opt/py_utils /opt/shivam-archive

echo
echo "== Done =="
echo "This machine now has VPS1's runtime, but no application code, .env files,"
echo "PM2 process definitions, or nginx site config yet."
echo "Next steps (not done by this script):"
echo "  1. git clone each application repo into its /opt/... path (see"
echo "     inventory/vps1.md for the PM2 process -> working-directory map)."
echo "  2. Restore .env files and /root/.pm2/dump.pm2 from a decrypted vps1"
echo "     backup archive (backup/config/vps1.conf) -- never from git."
echo "  3. Restore nginx site configs and Let's Encrypt certs from the same"
echo "     archive (or reissue certs fresh if rebuilding under a new IP/DNS)."
echo "  4. pm2 resurrect   # after dump.pm2 is in place"
echo "  5. sudo nginx -t && sudo systemctl reload nginx"

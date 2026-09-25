# Scripts

Supported backup and restore commands live under `backup/`.

## Disaster-recovery / restore-test provisioning

- `provision-vps2-like.sh` -- brings a bare Ubuntu 24.04 machine up to
  VPS2's runtime (Docker/Compose, Node.js, PM2). Optional `--sync-config`
  pulls VPS2's real docker-compose files and non-data SQL config over SSH
  (never `.env`, never live data).
- `provision-vps1-like.sh` -- brings a bare Ubuntu 24.04 machine up to
  VPS1's runtime (Node.js, PM2, nginx, OpenJDK, Python, Docker).

Both support `--dry-run` and target fresh hardware (2026-09-25: intended
for a restore-test machine, doubling as disaster-recovery rebuild scripts
per `INFRASTRUCTURE.md`'s Recovery standard). Neither deploys application
code, secrets, or data -- that's a separate restore step from an actual
backup archive, kept separate so these stay reusable for a real rebuild,
not just restore-testing. Untested against real hardware as of writing
(the target spare machine doesn't exist yet) -- syntax-checked and
dry-run-verified only; validate for real the first time they're actually used.

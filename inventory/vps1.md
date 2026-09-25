# VPS1 — Labit application server

Last reviewed: 25 September 2026

- Hostname: `ubuntu-4gb-hel1-1`
- Reachable as `root@api.sdrc.in` (not previously recorded here)
- Provider: Hetzner
- OS: Ubuntu 22.04.5 LTS, kernel 5.15.0-191-generic, x86_64
- Role: primary application/frontend server
- Runtimes: Node.js 22.23.2, npm 10.9.8, PM2 6.0.14, nginx 1.18.0,
  OpenJDK 21.0.12, Python 3.10.12, Docker 29.1.3
- Extra APT repository: NodeSource Node.js 22.x

## Services

PM2 inventory observed during the September review:

```text
labbit-api                 labbit-cto-collector
labbit-cto-digest          labbit-frontend
labbit-monitoring-vps      labbit-ops-cleanup
labit-app-api              labit-core
labit-jasper               labit-patient
labit-ui                   report-enqueue-watch
report-sender              shivam-archive
```

`labbit-cto-digest` and `labbit-ops-cleanup` may be scheduled rather than
continuous. Verify their invocation before treating a stopped state as failure.

Known application roots: `/opt/labbit-py`, `/opt/labit`, `/opt/py_utils`,
`/opt/shivam-archive`, and `/opt/labbit`. Known Python environments exist below
those roots and at `/opt/.venv`; collect exact ownership and interpreter versions
with the configuration collector before an OS upgrade.

PM2 process working directories (2026-09-25):

```text
labbit-frontend        /opt/labbit-frontend
labbit-monitoring-vps  /opt/labbit-py
labbit-api             /opt/labbit-py
report-enqueue-watch   /opt/py_utils/workers/report_sender
report-sender          /opt/py_utils/workers/report_sender
labit-ui               /opt/labit/labit-ui
labbit-cto-collector   /opt/labbit-ops
labbit-cto-digest      /opt/labbit-ops  (stopped; likely scheduled)
labbit-ops-cleanup     /opt/labbit-ops  (stopped; likely scheduled)
shivam-archive         /opt/shivam-archive
labit-patient          /opt/labit/labit-patient
labit-jasper           /opt/labit/labit-jasper
labit-app-api          /opt/labit/labit-app/api
labit-core             /opt/labit/labit-core
```

PM2 process definitions are saved (`pm2 save`) at `/root/.pm2/dump.pm2`,
current as of 2026-09-25 — no separate `ecosystem.config.js` files exist.

nginx `sites-enabled` (5 sites): `app.labit.online`, `app.sdrc.in`, `labbit`,
`labit-ui`, `lab.sdrc.in`. Let's Encrypt `live/` certs cover 6 domains,
including `api.sdrc.in` and `supabase.sdrc.in`.

`/opt/supabase` and `/opt/supabase-template` (~3.1GB each, dormant leftover
clones, no running containers) were deleted 2026-09-25 after confirming no
systemd unit, nginx config, PM2 process, or Docker container referenced
either path.

Active `.env` locations (used to populate `backup/config/vps1.conf`'s
`BACKUP_PATHS`, 2026-09-25): `/opt/labbit-ops/cto-collector/.env`,
`/opt/labbit-py/.env`, `/opt/shivam-archive/.env`,
`/opt/labit/labit-app/api/.env`, `/opt/labit/labit-core/.env`,
`/opt/labit/labit-patient/.env.local`, `/opt/labit/labit-deliver/.env`,
`/opt/labit/labit-ui/.env.local`, `/opt/labbit-frontend/.env.production`,
`/opt/labbit-frontend/.env.local`. Values were not read — locations only.

`/opt/labit/labit-jasper/templates` (44 `.jrxml` files) is a git repo
(`labbit-23/labit-jasper`) but had live drift on 2026-09-25: 2 modified and
2 untracked files present only on the server. Templates are read from disk
at report-generation time, not rebuilt from bytes stored in the database.

## Operations and recovery gaps

- TODO: VERIFY CPU, RAM, disk layout, IPs, DNS, firewall.
- TODO: VERIFY repositories/deploy revisions, log rotation, monitoring and
  alert owners.
- Backup coverage: `backup/config/vps1.conf` now targets the paths above,
  but this config must run ON VPS1 itself (its `BACKUP_PATHS` are local
  absolute paths, unlike the VPS2 configs which pull remotely over SSH).
  Not yet deployed/scheduled there — no cron entry exists on VPS1, and
  `ENCRYPTION_ENABLED` is deliberately left `false` until the age
  recipients file and `age`/`rclone` are installed on VPS1 itself.
- `labbit-api` is known to start through `/opt/labbit-py/start.sh`.

After maintenance validate `systemctl --failed`, `pm2 status`, nginx config and
external health/user journeys for every continuously running application.

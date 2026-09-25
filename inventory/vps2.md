# VPS2 — Supabase, PostgreSQL, and host applications

Last reviewed: 25 September 2026

- Hostname: `ubuntu-4gb-hel1-2`
- Provider: Hetzner
- OS: Ubuntu 22.04.5 LTS, kernel 5.15.0-191-generic, x86_64
- Role: self-hosted Supabase/database plus host-level PM2 services
- Docker: 29.8.1; Compose 5.5.1
- Extra APT repositories: Docker Ubuntu repository; NodeSource Node.js 20.x

## Supabase

Working directory: `/opt/supabase/docker`. Compose files in active use:
`docker-compose.yml` and `docker-compose.labit-db.yml`.

Also present but not confirmed live (found 2026-09-25 while building
`scripts/provision-vps2-like.sh`): `docker-compose.caddy.yml`,
`docker-compose.nginx.yml`, `docker-compose.rustfs.yml`,
`docker-compose.s3.yml`, plus `docker-compose.yml.bak` and
`docker-compose.yml.lean-working` (stale variants) and `.env.old`/
`.env.working` alongside the real `.env`. TODO: VERIFY which of the extra
compose files are actually used vs leftover from earlier iteration.

Observed images on 21 September 2026:

```text
supabase-db       supabase/postgres:15.8.1.085
supabase-studio   supabase/studio:2026.03.16-sha-5528817
supabase-kong     kong/kong:3.9.1
supabase-storage  supabase/storage-api:v1.44.2
supabase-meta     supabase/postgres-meta:v0.95.2
supabase-pooler   supabase/supavisor:2.7.4
supabase-auth     supabase/gotrue:v2.186.0
supabase-rest     postgrest/postgrest:v14.6
```

Critical: PostgreSQL uses the host bind mount
`/opt/supabase/docker/volumes/db/data` -> `/var/lib/postgresql/data`, not a
normal named volume. SQL/config files including `webhooks.sql`, `jwt.sql`,
`roles.sql`, `_supabase.sql`, `logs.sql`, `pooler.sql`, and `realtime.sql` are
under `/opt/supabase/docker/volumes/db`. Named volume `supabase_db-config` is
mounted at `/etc/postgresql-custom`.

## Host PM2 services

| Service | Observed state | Note |
| --- | --- | --- |
| `labbit-cto-collector` | online | collector/monitoring |
| `labbit-cto-digest` | stopped | likely scheduled; verify |
| `labbit-ops-cleanup` | stopped | likely scheduled; verify |
| `labit-core` | online | application service |
| `shivam-archive` | online | archive service |

VPS2 is not database-only. Maintenance and recovery must validate Docker and
PM2 independently. Run `systemctl --failed`, `pm2 status`, and
`docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}'`.

## Gaps

- TODO: VERIFY each PM2 process executable, cwd, runtime/venv, environment-file
  location, repository/revision, startup behavior, logs, dependencies and owner.
- TODO: VERIFY all Supabase schemas, Storage object backing path, roles/global
  objects, extensions, auth dependencies, secrets recovery, and complete backup.
- TODO: record addressing, DNS/firewall, monitoring and alerts.
- A host snapshot is supplementary only; keep logical dumps and test restores.

## Database maintenance notes (2026-09-25)

- **`labit_core.audit_log`**: had ~1.3 GB of index bloat left over from the
  earlier multi-million-row deletes (heap only 150 MB, indexes 1,149 MB for
  183k rows). `VACUUM FULL` reduced the table from 1,322 MB to 164 MB with all
  rows intact. Retention is now table-class based
  (`backup/scripts/prune_audit_log.sh`): transactional tables (`result`,
  `report`, `requisition`, `requisition_item`, `sample`, `sample_event`,
  `radiology_report`) keep 6 months; masters, `patient`, and any unclassified
  table are kept indefinitely. Scheduled monthly (05:00 IST on the 1st) from
  devserver's crontab; dry-run by default, the cron passes `--execute`.
  Nothing is eligible before about March 2027. NABL retention for clinical
  audit rows is still a human decision.
- **`public.cto_service_logs` / `cto_service_daily_digest`**: PostgREST is
  capped at `PGRST_DB_MAX_ROWS=1000`, which made the old API-based digest
  cover only the first ~22 minutes of each day. Daily digests for 2026-09-18
  to 09-24 were recomputed correctly; earlier digests remain sampled (their
  healthy raw rows are already pruned). Do not raise the global cap; fix
  consumers instead.
- New role `cto_digest` (LOGIN, no superuser) for the VPS1 digest job:
  `SELECT, DELETE` on `cto_service_logs` and `SELECT, INSERT, UPDATE` on
  `cto_service_daily_digest`, with matching RLS policies (`cto_digest_*`),
  because both tables are RLS-enabled with no other policies.

## Capacity and PostgreSQL memory (checked 2026-09-25)

The host was resized in September (hostname still says `4gb`): **4 cores, 7.6 GiB
RAM, 4 GB swap, 150 GB disk (42% used)**. The host rebooted and PostgreSQL
restarted on 2026-09-21 03:38.

- PostgreSQL scaled itself to the new RAM at start-up; there is no manual
  tuning in the compose files or `/etc/postgresql-custom` (only `supautils` and
  replication files): `shared_buffers` 1.9 GB (25%), `effective_cache_size`
  5 GB, `maintenance_work_mem` 256 MB, `work_mem` 16 MB, `wal_buffers` 20 MB,
  `max_connections` 100 (35 in use), `max_wal_size` 1 GB. Buffer cache hit rate
  99.2%. Containers have no memory limits; `shm_size` is Docker's 64 MB default.
- Sorts and hash joins were spilling to disk: 9,864 temp files / 198 GB
  (roughly six months of statistics; `pg_stat_statements` reset 2026-03-26).
  Top writers: `labit_core_rw` 48%, `service_role` (PostgREST) 32%,
  `supabase_admin` 18%.
- **Change 2026-09-25:** `ALTER ROLE labit_core_rw SET work_mem = '64MB'`
  (alongside its existing `idle_in_transaction_session_timeout=5min`; 11
  connections at the time). Applies to new sessions only, so labit-core's pooled
  connections pick it up when they recycle or the service restarts. Same
  pattern as `shivam_archive_ro`, which already had `work_mem=32MB`. Revert with
  `ALTER ROLE labit_core_rw RESET work_mem`.
- Not changed, optional: the same setting for `service_role` (32% of spills);
  `shm_size` to ~1 GB at the next container recreation (no `shm` errors in 7
  days); `log_temp_files` to identify the spilling queries.


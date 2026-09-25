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
- **Change 2026-09-25:** `ALTER ROLE service_role SET work_mem = '64MB'`. The
  `service_role` spills (about 12 GB) are two paged reads of
  `public.whatsapp_messages` (filter and sort on `created_at`, `LIMIT/OFFSET`)
  issued through PostgREST by the API layer (`labbit-frontend`, `report_sender`
  and enqueue workers use the service key). PostgREST applies per-role settings
  to the impersonated role, the same mechanism Supabase's `anon`/`authenticated`
  statement timeouts rely on. Baseline before the change: 12 GB of temp
  writes; re-check `pg_stat_statements` later to confirm it slowed. Revert with
  `ALTER ROLE service_role RESET work_mem`.
- **Indexes added 2026-09-25** (`CREATE INDEX CONCURRENTLY`, no write blocking),
  found from `pg_stat_user_tables` sequential-scan counts and `pg_stat_statements`:
  - `idx_report_auto_dispatch_jobs_reqno_status` on
    `public.report_auto_dispatch_jobs (reqno, status)` (664 kB). The queue
    worker's lookup `WHERE reqno = $1 AND status = $2 AND report_label ILIKE $3`
    had no index: 4.5 million sequential scans reading 51 GB and 1.39M calls
    (about 5 hours of cumulative time). Measured 33.5 ms to 0.033 ms.
  - `idx_whatsapp_messages_created_at` on `public.whatsapp_messages (created_at)`
    (9.4 MB). The paged `created_at` reads that caused the `service_role` temp
    spills had no index (all existing ones lead with `lab_id` or `phone`).
    Measured 1,096 ms to 0.92 ms.
  Both are in the `public` schema, so they are rebuilt by the `vps2-public` dump.
  Revert with `DROP INDEX CONCURRENTLY public.<name>`.
- **Slow requisition-item / sample-tube screens (investigated 2026-09-25).**
  The System Health slow-query panel in `labit-ui` (`app/api/proxy/system/backend-status`)
  shows the top 5 statements by cumulative `total_exec_time` since 2026-03-26,
  so it includes the bulk-migration period and overstates today's cost. The
  tables are small (`requisition_item` 10k rows / 4.7 MB, the whole table only 30
  days old, about 470 items a day) and the joined tables are well indexed. Plans
  today: worklist query (`ri.id ... ORDER BY req.created_at DESC LIMIT`) 54 ms
  with a real user id and limit 1000, 1.6 to 3.3 ms without the doctor filter;
  barcode lookup (`ri.id = ANY($1)`) reads under 1,000 buffers for 200 items.
  No missing index found; `parameter (specimen_type_id)` has none but the table
  is 1,142 rows. Suspects that need live evidence: per-row calls to the SQL
  function `labit_core.doctor_department_access()` (about 9,900 rows evaluated
  per call; fine now, grows with data), the barcode lookup being called
  ~107k times (an N+1 pattern in the app), lock waits, and large windows/limits.
  **Logging enabled for the next lab day:** `ALTER ROLE labit_core_rw SET
  log_min_duration_statement = '250ms'` and `log_lock_waits = on` (applies to
  new sessions, so labit-core's pooled connections pick it up as they recycle).
  Read it with: `docker logs supabase-db --since 24h 2>&1 | grep -E 'duration:|still waiting'`.
  Revert with `ALTER ROLE labit_core_rw RESET log_min_duration_statement, RESET log_lock_waits`.
- Not changed, optional: `shm_size` to ~1 GB at the next container recreation (no `shm` errors in 7
  days); `log_temp_files` to identify the spilling queries.

## pg_cron jobs and the audit-log retention job (checked 2026-09-25)

`cron.job` on the `postgres` database:

| Job | Schedule (UTC) | State | What |
| --- | --- | --- | --- |
| 1 `system_stats_snapshot_daily` | `30 18 * * *` | active | inserts into `labit_core.system_stats_snapshot` (from labit-core `schema/326`) |
| 2 (unnamed) | `45 18 * * *` | **unscheduled 2026-09-25** | `DELETE FROM labit_core.audit_log WHERE changed_at < now() - interval '14 days'` (from labit-core `schema/393_audit_log_retention.sql`) |

Job 2 ran nightly from 2026-09-03 and deleted 7,130,332 rows in 22 recorded
runs: 287k to 1.4M a day while migration churn was being cleaned up, then about
13k a day (7,940 to 61,287) from 09-15. Everything it removed predates about
09-10. It was unscheduled before its 09-25 18:45 UTC run, which would have begun
deleting the first production audit rows (from 2026-09-11), because it conflicts
with the retention policy set on 2026-09-25 (transactional tables 6 months,
masters and everything else kept). It applies one rule to every table's audit
rows, including masters.

- Replacement: `backup/scripts/prune_audit_log.sh` (table-class policy, monthly
  from devserver's crontab).
- Restore the old behaviour: `SELECT cron.schedule('45 18 * * *', $$DELETE FROM
  labit_core.audit_log WHERE changed_at < now() - interval '14 days'$$);`
- **Open:** `schema/393_audit_log_retention.sql` in the labit-core repo will
  recreate the job if that migration is ever re-applied; it should be changed to
  match the new policy. The 09-2026 bloat came from system-actor churn on
  `labit_core.patient` (millions of rows during seeding); with the nightly
  delete off, a future bulk re-seed will grow `audit_log` until the monthly
  prune (which does not touch `patient`) or a manual clean-up. Backups keep
  audit rows for 30 daily archives, so anything deleted in the last 30 days is
  recoverable from an archive.

## Slow labit-ui screens: live evidence (2026-09-25 14:01 to 14:07 UTC)

Method: snapshot `pg_stat_statements` before and after a user session, then diff.
295 statements ran, 71.8 s of database time in about 6 minutes. The heaviest
touched 0.3 to 2.1 million buffers per call (my isolated test of the same
queries touched under 1,000), so the live cost is not explained by table size.
Of the 12 statements averaging over 200,000 buffers per call, **8 have no date
bound**, so their cost grows with all history:

- pending-tube queue (`WITH required_tubes ...`, 88,790 calls): computes tube
  counts for every requisition ever, then filters `tube_count > collected_tube_count`
  afterwards (compute everything, filter last);
- rejected-sample queue (`WITH item_latest ...`, 12,089 calls, one call
  returned 0 rows after 2.1M buffers), ready-to-dispatch list (`latest_ready_at`,
  7,141 calls), and the department pending-count badges (1,902 calls each);
- a one-off group-by on `diagnotech.newtestresult` (19.5M rows).

Ruled out: generic vs custom plan for the barcode lookup (23 ms vs 7 ms),
missing indexes on the joined tables, memory. Not yet reproduced: why the live
per-call buffer counts are so far above the isolated ones.
Logging: the server has `log_min_messages = fatal`, which hides slow-query
lines, so `labit_core_rw` now also has `log_min_messages = log`
(with `log_min_duration_statement = 250ms`, `log_lock_waits = on`). These apply
only to connections opened after 2026-09-25 ~14:12 UTC; restarting labit-core
(when the lab is closed) makes the whole pool pick them up. Read with
`docker logs supabase-db --since 24h 2>&1 | grep -E 'duration:|still waiting'`.


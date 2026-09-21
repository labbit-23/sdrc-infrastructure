# VPS2 — Supabase, PostgreSQL, and host applications

Last reviewed: 21 September 2026

- Hostname: `ubuntu-4gb-hel1-2`
- Provider: Hetzner
- OS: Ubuntu 22.04.5 LTS, kernel 5.15.0-191-generic, x86_64
- Role: self-hosted Supabase/database plus host-level PM2 services
- Docker: 29.8.1; Compose 5.5.1
- Extra APT repositories: Docker Ubuntu repository; NodeSource Node.js 20.x

## Supabase

Working directory: `/opt/supabase/docker`. Compose files:
`docker-compose.yml` and `docker-compose.labit-db.yml`.

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
- TODO: record CPU/RAM/disk, addressing, DNS/firewall, monitoring and alerts.
- A host snapshot is supplementary only; keep logical dumps and test restores.

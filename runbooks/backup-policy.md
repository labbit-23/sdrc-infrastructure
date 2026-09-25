# Backup policy and coverage

Last reviewed: 21 September 2026

## Required standard

Use a 3-2-1 approach: at least three copies, on two storage types, with one
off-site. Encrypt off-site/cloud artifacts with age, retain the private identity
outside the source and sync machines, monitor job freshness/failure and capacity,
and test restores quarterly and before risky upgrades. Checksums detect damage;
they do not establish restore correctness.

Suggested starting retention (confirm business/legal requirements): 14 daily,
12 weekly, and 12 monthly recovery points. The current engine supports daily and
weekly local tiers only; monthly/off-site retention remains TODO.

## Coverage matrix

| Asset | Current evidence | Required action |
| --- | --- | --- |
| PostgreSQL `labit_core` schema | Daily full logical dump through 2026-09-20; SHA-256; local; unencrypted | Enable age + sync folder; isolated restore test |
| PostgreSQL `public` schema | Daily full logical dump through 2026-09-20; SHA-256; local; unencrypted | Enable age + sync folder; isolated restore test |
| Full Supabase database | Not evidenced | Add database-wide dump plus roles/globals; inventory extensions/schemas |
| Supabase Storage objects | Location/backup not verified | Discover backing storage; back up and restore with metadata |
| VPS2 Compose/config | One dated archive is present locally; schedule not evidenced | Secret-safe scheduled configuration backup |
| VPS1 app/config | Framework exists; current scheduled backup not evidenced | Inventory sources and schedule encrypted backup |
| Orthanc objects + index | Unknown | Discover; consistency-safe backup and test restore |
| Mirth channels/config (sdrc-integrations) | Confirmed NOT backed up (2026-09-25) | Export configuration/channels; extend devserver pipeline (pull over SSH, same model as VPS1) |
| ERPNext/MariaDB (sdrc-integrations) | Local-only: `bench` cron every 6h, no retention/off-site confirmed | Extend devserver pipeline to pull+encrypt+push existing local dumps off-site |
| Sysmex/ZK/DICOM/DEXA integration configs (sdrc-integrations) | Confirmed NOT backed up (2026-09-25) | Define scope, extend devserver pipeline |
| Legacy Oracle/LIMS | Unknown | Define native backup, retention and restore test |
| Firewall/network config | Unknown | Secret-safe exports after changes and on schedule |

## Daily operational check

Confirm each expected job produced a non-zero artifact and checksum within its
RPO, inspect its terminal success line, verify the checksum, confirm the sync
client reports upload complete, check free space, and alert on absence/failure.
Do not use repository presence or a `.sha256` file as proof of off-site upload.

## Restore-test record

Every test must record date, backup identifier, isolated target, exact commands,
duration, errors, row/object counts or other integrity checks, application-level
validation, tester, and outcome. Never test by overwriting production.

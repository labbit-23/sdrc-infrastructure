# Labit / SDRC Infrastructure

This is the entry point for the private, living infrastructure record. Read it
and the relevant inventory/runbook before changing production. Update both in
the same work session when infrastructure is discovered, deployed, changed, or
decommissioned. Never commit credentials, private keys, tokens, or secret
environment files. Mark facts that have not been observed directly as
`TODO: VERIFY`.

Last major review: 21 September 2026

## Service map

```text
Users -> DNS/HTTPS -> VPS1 (web, APIs, workers, Jasper)
                           |
                           +-> VPS2 (Supabase/PostgreSQL + host PM2 services)
                           |
                           +-> local SDRC systems (Mirth, LIMS, analysers,
                               Orthanc/DICOM)  [links/topology TODO: VERIFY]
```

Detailed inventories:

- [VPS1 application server](inventory/vps1.md)
- [VPS2 Supabase/database and applications](inventory/vps2.md)
- [Orthanc/DICOM discovery record](inventory/orthanc-dicom.md)
- [Inventory coverage and unknown systems](inventory/README.md)
- [Service relationships](architecture/services.md)
- [Network discovery record](architecture/network.md)

## Backup status

Evidence on the devserver on 21 September 2026 shows successful daily logical
dumps for the PostgreSQL `labit_core` and `public` schemas through 20 September.
Those archives have SHA-256 sidecars and local retention enabled. They are
currently **unencrypted** and the logs say FTP/off-site upload is disabled.
This is not yet a complete or independently recoverable Supabase backup:
roles/global objects, other schemas, Storage objects, database configuration,
and a current tested restore are not evidenced.

Use the [backup policy and coverage matrix](runbooks/backup-policy.md), the
[Google Drive sync-folder procedure](runbooks/google-drive-backups.md), and the
[PostgreSQL restore runbook](runbooks/postgres-restore.md). A backup is not
accepted as recoverable until an isolated restore test and application-level
validation have succeeded.

## Current cloud systems

| System | Role | OS | Primary paths | Detail |
| --- | --- | --- | --- | --- |
| VPS1 `ubuntu-4gb-hel1-1` | Labit applications/frontend | Ubuntu 22.04.5 LTS | `/opt/labit`, `/opt/labbit-py`, `/opt/py_utils`, `/opt/shivam-archive` | [inventory](inventory/vps1.md) |
| VPS2 `ubuntu-4gb-hel1-2` | Supabase/PostgreSQL and PM2 applications | Ubuntu 22.04.5 LTS | `/opt/supabase/docker`; DB data at `/opt/supabase/docker/volumes/db/data` | [inventory](inventory/vps2.md) |

Both hosts are planned for a staged upgrade to Ubuntu 24.04. VPS1 must be
upgraded and observed first. The VPS2 host OS upgrade must be separate from any
Supabase/PostgreSQL image upgrade. See [Ubuntu upgrade runbook](runbooks/ubuntu-upgrade.md).

## Recovery standard

For every critical system the repository must identify its owner, dependencies,
configuration and data paths, startup mechanism, secrets recovery location,
backup schedule/retention/off-site copy, monitoring, restore steps, validation,
and rollback. The target is that an engineer unfamiliar with the original
deployment can rebuild it from this repository plus encrypted secrets and data
backups.

## Change log

### 2026-09-21

- Added cloud host inventories and architecture/runbook structure.
- Recorded the VPS2 PostgreSQL bind mount and host-level PM2 workload.
- Recorded evidence and gaps in the existing daily schema dumps.
- Added atomic, checksum-verified publication to a user-supplied sync folder.
- Added an Orthanc/DICOM discovery questionnaire and install/restore runbook.

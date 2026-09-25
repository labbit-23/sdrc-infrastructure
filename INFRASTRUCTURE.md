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
- [Local devserver/application server](inventory/devserver.md)
- [sdrc-integrations workstation](inventory/sdrc-integrations.md) (Mirth, ERPNext, Sysmex, ZK attendance, DICOM/MWL, DEXA)
- [Ctrl-S legacy Shivam server](inventory/ctrls-legacy-shivam.md)
- [Orthanc/DICOM discovery record](inventory/orthanc-dicom.md)
- [Inventory coverage and unknown systems](inventory/README.md)
- [Service relationships](architecture/services.md)
- [Network discovery record](architecture/network.md)
- [Attendance migration and ERPNext retirement](runbooks/attendance-erpnext-migration.md)

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
- Audited the Ctrl-S Windows/Oracle/Tomcat server and recorded its residual
  Patient App, MD app and automated API dependencies as decommissioning gates.
- Inventoried the local `sdrc-report-delivery` host, its four Next.js listeners,
  database tunnel, backup schedules, remote access and current operational gaps.
- Recorded the decision path for native attendance and eventual ERPNext
  retirement, including parallel reconciliation and archival gates.

### 2026-09-22

- Diagnosed the ERPNext `ModuleNotFoundError`: the deprecated Frappe
  `labit_core` package was removed from disk/configuration but remains registered
  in `tabInstalled Applications`; documented the maintenance-window cleanup
  prerequisites without changing production.
- Recorded the 49-row employee source inventory (33 biometric IDs, 16 missing),
  the ZK check-in gap since 16 September, and the target native Core attendance
  boundary. The PII-bearing CSV remains off-repository.

### 2026-09-25

- Renamed the local host to `devserver` in all inventory documents.
- Enabled age encryption on all backup jobs and added an rclone push to Google
  Drive (fixed filename per job, Drive version history as off-site retention).
  Added a pull-based VPS1 backup (`pull_vps1_files.sh`); all three jobs run
  nightly from devserver (02:00 / 03:30 / 04:00 IST). VPS1 needs nothing
  installed. A restore/decrypt test with the age key is still outstanding.
- Inventoried `sdrc-integrations` (Mirth, ERPNext, Sysmex, ZK, DICOM/MWL, DEXA)
  and `lab-mirth` (formerly `sdrc-h81`). Resolved a swap-exhaustion incident on
  `sdrc-integrations` (added a second 12 GB swap file).
- Deleted dormant `/opt/supabase*` clones from VPS1 (6.2 GB).
- Added `scripts/provision-vps1-like.sh` and `provision-vps2-like.sh` (Ubuntu
  24.04 runtime bootstrap; dry-run tested only, no spare machine yet).
- Database maintenance: `audit_log` `VACUUM FULL` (1.3 GB to 164 MB), new
  audit retention policy, and the CTO digest fix; details in
  `inventory/vps2.md` and `inventory/vps1.md`.


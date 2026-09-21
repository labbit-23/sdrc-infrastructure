# Orthanc / DICOM install, operation, and recovery

This is a framework until the local agent supplies the observed deployment.
Do not invent paths, images, plugins, AE Titles, ports or peer topology.

## Build record required

Pin and document OS, Orthanc and plugin/database versions. Commit a redacted
package list or Compose/systemd definition, configuration template with secret
references, storage/index mount ownership, firewall intent, log rotation,
monitoring and synthetic health checks. Keep deployed secret values outside Git.

An installation is complete only when it survives reboot and passes HTTP/API
health, DICOM C-ECHO, synthetic C-STORE, query/retrieve, UI authentication,
configured peer routes and downstream Labit/Mirth workflows.

## Backup and restore

Identify whether the index is SQLite or PostgreSQL and follow the matching
consistent-backup procedure. Capture both DICOM object storage and the index;
an object-only or index-only copy is incomplete. Prefer an application-consistent
snapshot or documented stop/quiesce sequence. Encrypt off-site copies.

Restore to an isolated host with the same pinned versions, restore index and
objects to documented paths/ownership, start Orthanc, then validate counts,
random study retrieval, C-ECHO/C-STORE/query/retrieve and all configured routes.
Record RPO/RTO and test results. Never use patient data for ad-hoc testing.

## Operations

The final machine-specific procedure must include exact install/start/stop/
restart/upgrade/rollback commands, configuration and log paths, disk-capacity
thresholds, backup freshness alert, certificate expiry and owner/escalation.

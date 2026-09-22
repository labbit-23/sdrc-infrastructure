# Attendance migration and ERPNext retirement

Last reviewed: 22 September 2026
Status: discovery complete; Core schema/API and ingestion implementation pending

ERPNext is reported to be used only for attendance. Replace that dependency
with the native Labit employee/attendance model, then decommission ERPNext
after data and device parity have been demonstrated.

## Minimum employee mapping

The current PostgreSQL Core has staff login identities in
`labit_core.app_user`, but no general employee master or attendance ledger.
Do not turn every employee into an application login merely to store attendance.

Add an employee record with one nullable, unique device mapping field:

```text
biometric_employee_code
```

Keep it separate from the Labit employee primary key. Store the exact stable
identifier emitted by the biometric device/collector; do not overload names,
phone numbers or mutable payroll identifiers. An employee may optionally link
to `labit_core.app_user` when that person also needs a Labit login.

## Confirmed source inventory

Read-only ERPNext discovery on 22 September 2026 found 49 employee records:

- 33 have `attendance_device_id` populated;
- 16 have no biometric mapping and cannot be matched to device punches until
  corrected;
- a local CSV export containing employee names and other PII was produced for
  migration, but must not be committed to this repository.

The ZK device had not produced a new ERPNext Employee Checkin since 16
September 2026. Diagnose the collector/device path before using ERPNext data as
proof of current attendance completeness.

## Target data boundary

Core should own at least:

- employee identity and active/inactive status;
- unique biometric employee code;
- optional link to an `app_user` login;
- immutable raw punch time, received time, source device and source event ID;
- derived attendance status separately from raw punches;
- correction/audit history rather than destructive edits.

Ingestion must be idempotent. Use a source-event identifier when the device
provides one; otherwise enforce a documented composite uniqueness key such as
device, biometric employee code and exact event timestamp. Store timestamps
with an explicit source timezone and normalize them to `timestamptz`.

Do not implement a general unauthenticated `/machine-api/employees` writer.
Employee-master import is an administrative operation. Punch ingestion should
use a dedicated least-privilege machine credential, request validation, an
audit trail and a batch endpoint so queued events can recover after outages.

Recommended flow:

```text
ZK device -> local collector/outbox -> Core attendance ingestion API
                                      -> raw biometric punch ledger
                                      -> attendance derivation/review
```

ERPNext should not remain in this runtime path after cutover.

## ERPNext `labit_core` orphaned registration

The old Frappe custom app `labit_core` was deliberately deprecated on 10
September 2026. Its directory was renamed and it was removed from
`sites/apps.txt`, but its row in ERPNext's `tabInstalled Applications` was not
removed. This causes `bench console` and `bench list-apps` to report/import the
missing module.

From 10 September 20:36 until 11 September 12:40, stale cached app metadata also
caused background-job failures and approximately 230,000 error-log lines. The
worker failures stopped after the cached app list expired; jobs have run since,
but the orphaned database registration remains and should be cleaned during a
maintenance window.

Before changing that registration:

1. Take a fresh database backup and a configuration/files backup.
2. Copy both off the ERPNext host and verify the archives.
3. Preserve sanitized evidence of the installed-app mismatch.
4. Use the Frappe-supported uninstall/cleanup path if it can operate with the
   missing package; otherwise prepare and peer-review the narrow database-row
   correction.
5. Validate `bench list-apps`, scheduler/worker health, attendance and backups.

Do not reintroduce the deprecated Python app merely to silence the import.

## Discovery before implementation

- Record the ERPNext host, version, database and backup mechanism in a dedicated
  inventory (exact host details remain TODO: VERIFY in this repository).
- Identify the attendance device model, address, protocol and timezone.
- Inventory the current collector (`zk-attendance` is a discovery lead), its
  repository state, schedule, logs and credentials location.
- Export employee-code mappings and enough historical attendance for audit and
  reconciliation.
- Define duplicate-punch, overnight-shift, correction, leave, timezone and
  device-offline behaviour.
- Identify every report or payroll process consuming ERPNext attendance.

Current backups were reported healthy with a latest successful database backup
at 06:00 on 22 September, but they are database-only, retained locally for only
about 18 hours, and have no restore-test evidence. This is not adequate for
ERPNext decommissioning or attendance migration.

## Migration gate

1. Back up and restore-test the ERPNext database and attendance exports.
2. Implement the employee mapping with uniqueness and format validation.
3. Ingest raw punches idempotently, preserving device event time and source.
4. Run native and ERPNext attendance in parallel for at least one complete
   payroll/attendance cycle.
5. Reconcile employee mappings, daily status, late/early rules and missing or
   duplicate punches; obtain operational sign-off.
6. Disable ingestion into ERPNext while retaining it read-only for an agreed
   observation period.
7. Archive the final encrypted export, configuration and restore instructions,
   then remove the ERPNext workload.

Do not cancel or erase ERPNext merely because the visible UI appears unused.
Retirement requires proof that no biometric collector, scheduled job, report,
payroll export or integration still depends on it.

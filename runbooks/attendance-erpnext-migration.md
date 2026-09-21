# Attendance migration and ERPNext retirement

Last reviewed: 21 September 2026
Status: approved direction; discovery and implementation pending

ERPNext is reported to be used only for attendance. Replace that dependency
with the native Labit employee/attendance model, then decommission ERPNext
after data and device parity have been demonstrated.

## Minimum employee mapping

Add one nullable, unique field to the employee record:

```text
biometric_employee_code
```

Keep it separate from the Labit employee primary key. Store the exact stable
identifier emitted by the biometric device/collector; do not overload names,
phone numbers or mutable payroll identifiers.

## Discovery before implementation

- Locate the ERPNext host, version, database and backup mechanism.
- Identify the attendance device model, address, protocol and timezone.
- Inventory the current collector (`zk-attendance` is a discovery lead), its
  repository state, schedule, logs and credentials location.
- Export employee-code mappings and enough historical attendance for audit and
  reconciliation.
- Define duplicate-punch, overnight-shift, correction, leave, timezone and
  device-offline behaviour.
- Identify every report or payroll process consuming ERPNext attendance.

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

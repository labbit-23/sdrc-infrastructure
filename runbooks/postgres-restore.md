# PostgreSQL restore validation

The current scheduled dumps cover individual schemas in plain SQL inside the
compressed backup archive. They are not proven full-Supabase recovery points.

1. Select an archive and verify its adjacent SHA-256 file.
2. If encrypted, decrypt only on the protected restore host.
3. Extract into a new staging directory with `backup/restore.sh`.
4. Provision an isolated PostgreSQL version compatible with production.
5. Create required roles/extensions separately, then import the SQL while
   capturing all output and failing on SQL errors.
6. Compare expected schemas/tables, row counts, constraints, functions, triggers,
   RLS policies and representative application queries.
7. Validate Auth/REST/application behavior where the dump scope supports it.
8. Record the restore-test result per `backup-policy.md`; destroy test data safely.

Before claiming full disaster recovery, add and test database-wide logical
backup, roles/globals, Supabase Storage objects/configuration and secret recovery.
Never restore a schema dump directly over production as a test.

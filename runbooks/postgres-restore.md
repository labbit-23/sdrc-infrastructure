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

## One-command restore (added 2026-09-25)

`backup/restore-db.sh` performs steps 1 to 6 above and the role/grant/index work:

```bash
export PGHOST=... PGUSER=<superuser>          # standard PG* variables
backup/restore-db.sh --create-db --db restore \
    --identity /path/to/age-key.txt \
    vps2-labit-core_<ts>.tar.zst.age [vps2-public_<ts>.tar.zst.age]
```

It verifies the checksum, decrypts, extracts, creates the database, sets up
extensions and roles, loads the dump, re-runs failed index statements, restores
the original role password hashes and grants from the archive's
`labit-core-roles-and-grants.txt`, runs `ANALYZE`, and prints `RESULT: OK` or
`FAILED`. Add `--reindex` for a full reindex and `--keep-work` to keep the
extracted (plaintext) files. Archives made before 2026-09-26 have no roles file:
pass `--roles-file` or accept the repo fallback (roles then have no password).
Postgres must be 15 to match production.

### Restore-test record

| Date | Archive | Target | Result |
| --- | --- | --- | --- |
| 2026-09-25 | `vps2-labit-core_20260924T203003Z` (plaintext, pre-encryption) | PostgreSQL 15.19 on `sdrc-orthanc` (user-owned cluster in `~/restore-test`, socket only) | OK in 88 s. 1.4 GB dump loaded with 0 errors; 192 tables, 573 indexes, 0 invalid; all 5 app-role password hashes identical to production; `labit_core_rw` table grants 777 of 781 (the 4 missing are one table created after the backup); default privileges for `labit_core` identical; masters row counts exact, transactional tables consistent with the 02:00 IST snapshot. The encrypted-archive path (age decrypt) is not yet exercised end to end. |


# Postgres bootstrap for restores (non-Supabase)

Used by `backup/restore-db.sh`, which runs everything in order; you normally
don't run these by hand.

- `01-roles-and-extensions.sql` — `postgres` role, base app roles (no
  passwords), extensions placed as in production (`pg_trgm`/`btree_gist` in
  `public`, `pgcrypto`/`uuid-ossp` in `extensions`), database `search_path`.
- `02-grants.sql` — FALLBACK privileges captured from production on
  2026-09-25, used only when an archive has no `*-roles-and-grants.txt`.
  It carries no passwords; roles restored this way have none.

Since the labit_core backup now includes `labit-core-roles-and-grants.txt`
(roles with their original SCRAM password hashes, grants, default privileges,
captured nightly by `backup/scripts/pg_dump_grants.sh`), the archive itself is
enough and this fallback is rarely needed. Hashes are only ever written into
age-encrypted archives.

Re-capture the fallback after production grant changes:

    ./backup/scripts/pg_dump_grants.sh | sed -n '/^-- privileges/,$p' | tail -n +2

Not covered: `labbit-frontend` (uses supabase-js/PostgREST), the archive schemas
(`shivam-archive`, separate backup path), Supabase Auth/Storage.

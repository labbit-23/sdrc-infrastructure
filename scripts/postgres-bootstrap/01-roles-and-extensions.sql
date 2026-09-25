-- Prepare an empty PostgreSQL 15 database so a labit_core / public schema dump
-- restores and the apps can use it WITHOUT Supabase. Run BEFORE loading the dump.
--
--   psql -v dbname=restore -d restore -f 01-roles-and-extensions.sql
--   psql -d restore -f <schema dump>                (from a backup archive)
--   psql -d restore -f 02-grants.sql                (AFTER the dump)
--
-- Why this exists: the nightly dumps use --no-privileges/--no-owner, so roles,
-- grants and extension placement are NOT in the backup archives.
-- Layout mirrors production (checked 2026-09-25): pg_trgm and btree_gist live in
-- `public`; pgcrypto and uuid-ossp in `extensions`.
-- Roles are created with LOGIN and NO password here. restore-db.sh then applies the
-- original password hashes from the archive's roles file; if you restore without
-- it, set passwords yourself: ALTER ROLE labit_core_rw PASSWORD '...';
-- Deliberately not created: Supabase's anon/authenticated/service_role
-- (no labit_core policy uses auth.*), and the deprecated labit_deliver.

-- Production's grants and role memberships are recorded as owned/granted by the
-- `postgres` superuser (GRANTED BY postgres, ALTER DEFAULT PRIVILEGES FOR ROLE
-- postgres). Ensure that role exists so they replay unchanged. NOLOGIN: use your
-- own admin login for maintenance.
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'postgres') THEN
    CREATE ROLE postgres SUPERUSER NOLOGIN;
  END IF;
END $$;

DO $$
DECLARE r text;
BEGIN
  FOREACH r IN ARRAY ARRAY['labit_core_rw','labit_app_api','labit_main_rw','shivam_archive_ro','cto_digest'] LOOP
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = r) THEN
      EXECUTE format('CREATE ROLE %I LOGIN', r);
    END IF;
  END LOOP;
END $$;

GRANT pg_read_all_stats TO labit_core_rw;

CREATE SCHEMA IF NOT EXISTS extensions;
CREATE EXTENSION IF NOT EXISTS pgcrypto    WITH SCHEMA extensions;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA extensions;
CREATE EXTENSION IF NOT EXISTS pg_trgm     WITH SCHEMA public;
CREATE EXTENSION IF NOT EXISTS btree_gist  WITH SCHEMA public;

ALTER DATABASE :"dbname" SET search_path = "$user", public, extensions;

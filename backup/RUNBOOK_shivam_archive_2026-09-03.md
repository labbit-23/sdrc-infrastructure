# Shivam archive backup — pre-Hetzner-resize runbook (2026-09-03)

Not a config file on purpose: `backup_archive_stream.sh` (unlike `backup.sh`'s
config-driven schemas) takes its settings as environment variables only, and
the two secrets it needs must **never** be written to disk anywhere in this
repo or that one. Run this from the devserver.

## 1. Fetch the Postgres password (per-shell, not persisted)

```bash
export ARCHIVE_BACKUP_PG_PASSWORD=$(ssh root@supabase.sdrc.in \
  "grep '^POSTGRES_PASSWORD=' /opt/supabase/docker/.env | cut -d= -f2-")
```

## 2. Supply the Hostinger FTP password (per-shell, not persisted)

```bash
export SDRC_BACKUP_FTP_PASSWORD='paste-the-real-password-here'
```

## 3. Dry-run first (prints the plan, touches nothing)

```bash
cd ~/projects/sdrc/shivam-archive/deploy
./backup_archive_stream.sh --dry-run
```

## 4. Real run — streams straight to Hostinger FTP, never touches disk on

VPS2 (only ~16GB free there right now) or on this devserver either:

```bash
./backup_archive_stream.sh
```

Uploads under `.partial`, renamed only after the full transfer completes —
safe to re-run if it fails partway. Every run gets its own UTC timestamp, so
re-running never collides with a prior attempt.

## 5. Clean up the shell

```bash
unset ARCHIVE_BACKUP_PG_PASSWORD SDRC_BACKUP_FTP_PASSWORD
```

---

**Do this before the Hetzner VPS2 resize tonight**, alongside the
`labit_core`/`public` schema backups already run via
`backup/config/vps2-labit-core.conf` and `backup/config/vps2-public.conf`.

# Backup

Phase 2 creates local, unencrypted backups. It copies configured paths into an
isolated working directory, captures configured command output, compresses the
result as `.tar.zst`, and writes a `.sha256` checksum.

Archives and checksums are published only after their write completes. Failed
runs remove `.partial` files and any incomplete archive/checksum output.

Configuration files are trusted Bash files. The required settings are
`BACKUP_NAME`, the indexed `BACKUP_PATHS` array, and the indexed
`COMMAND_OUTPUTS` array. Copy an example to an ignored `*.conf` file before
adapting it for a server.

## Dry run

From the repository root:

```bash
./backup/backup.sh backup/config/vps1.example.conf --dry-run
```

A dry run validates configuration and reports planned actions. It does not copy
paths, execute configured commands, create a working directory or archive, or
generate a checksum. It writes only a log under `backup/logs/`.

## Local backup

Install `tar`, `zstd`, and `sha256sum`, then run:

```bash
cp backup/config/vps1.example.conf backup/config/vps1.conf
# Edit backup/config/vps1.conf for the host.
./backup/backup.sh backup/config/vps1.conf
```

Archives are written to `backup/archives/` by default. Encryption, FTP upload,
retention, database capture/import, and writes back to source systems are not
performed in Phase 2. Their libraries are placeholders only.

The restore script remains a future-phase scaffold and is not part of the Phase
2 local backup flow.

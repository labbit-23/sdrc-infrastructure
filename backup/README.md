# Backup

Phase 1 provides a Bash framework for collecting files, capturing command output,
dumping databases, compressing and encrypting the result, generating a checksum,
uploading it to FTP, and applying retention rules.

The configuration files are trusted Bash files. Copy an example outside version
control, replace its placeholders, and keep credentials in environment variables
or protected files rather than committing them.

## Backup

Preview all steps without collecting, encrypting, uploading, or deleting data:

```bash
./backup/backup.sh backup/config/vps1.example.conf --dry-run
```

Run a backup after supplying a valid age recipient and FTP credentials:

```bash
export FTP_PASSWORD='replace-at-runtime'
./backup/backup.sh /secure/path/vps1.conf
```

Logs are written to `backup/logs/`. Generated archives are written to
`backup/archives/` by default and are ignored by Git.

## Restore

Preview a restore:

```bash
./backup/restore.sh /secure/path/vps1.conf \
  backup/archives/vps1_20260101T000000Z.tar.zst.age \
  /tmp/sdrc-restore --dry-run
```

Verify the checksum, decrypt, and extract into a new or empty directory:

```bash
export AGE_IDENTITY_FILE='/secure/path/backup-identity.txt'
./backup/restore.sh /secure/path/vps1.conf \
  backup/archives/vps1_20260101T000000Z.tar.zst.age \
  /tmp/sdrc-restore
```

Restore does not copy data back to a live system, import databases, or execute
captured commands. Those destructive operations are intentionally out of scope.


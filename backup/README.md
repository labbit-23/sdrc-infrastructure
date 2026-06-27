# Backup

Phase 3 creates local backups with optional age encryption. It copies configured paths into an
isolated working directory, captures configured command output, compresses the
result as `.tar.zst`, optionally encrypts it as `.tar.zst.age`, and writes a
`.sha256` checksum for the final archive.

Archives and checksums are published only after their write completes. Failed
runs remove `.partial` files and any incomplete archive/checksum output.

Configuration files are trusted Bash files. The required settings are
`BACKUP_NAME`, the indexed `BACKUP_PATHS` array, and the indexed
`COMMAND_OUTPUTS` array. Copy an example to an ignored `*.conf` file before
adapting it for a server.

Encryption is controlled by `ENCRYPTION_ENABLED`, `AGE_BINARY`,
`AGE_RECIPIENTS_FILE`, and `KEEP_UNENCRYPTED_ARCHIVE`. `AGE_BINARY` defaults to
`age` and may be set to an explicit test executable path. With encryption
disabled, Phase 2 behavior is unchanged.

## Dry run

From the repository root:

```bash
./backup/backup.sh backup/config/vps1.example.conf --dry-run
```

A dry run validates configuration and reports planned actions. It does not copy
paths, execute configured commands, create a working directory or archive, or
generate a checksum. It writes only a log under `backup/logs/`.

## Generate an age keypair

Production validation requires the upstream `age` package:

```bash
sudo apt update
sudo apt install -y age
```

On a secure administrative or restore system, create the protected directory
and generate the identity and public recipient file:

```bash
mkdir -p ~/.config/sdrc-backup/age
chmod 700 ~/.config/sdrc-backup/age
age-keygen -o ~/.config/sdrc-backup/age/sdrc-backup-key.txt
age-keygen -y ~/.config/sdrc-backup/age/sdrc-backup-key.txt > ~/.config/sdrc-backup/age/recipients.txt
```

Keep `sdrc-backup-key.txt` offline or on a protected restore system. Never copy
it into this repository or onto the source VPS. Copy only `recipients.txt` to
the source server, for example:

```text
/etc/sdrc-backup/recipients/vps1.txt
```

Restrict the directory from accidental modification. The recipient file is
public and may contain multiple recipients, one per line.

## Local backup

Install `tar`, `zstd`, `sha256sum`, and `age` when encryption is enabled, then
run:

```bash
cp backup/config/vps1.example.conf backup/config/vps1.conf
# Edit backup/config/vps1.conf for the host.
./backup/backup.sh backup/config/vps1.conf
```

Set `ENCRYPTION_ENABLED=true` and point `AGE_RECIPIENTS_FILE` at the public
recipient file to create an encrypted archive. When
`KEEP_UNENCRYPTED_ARCHIVE=false`, the `.tar.zst` file is removed only after the
encrypted archive and its checksum are successfully published.

Archives are written to `backup/archives/` by default. FTP upload, retention,
database capture/import, and writes back to source systems are not performed.
Their libraries remain placeholders only.

The restore script remains a future-phase scaffold and is not part of the Phase
3 backup flow.

# Backup and Restore

The backup engine collects configured paths and diagnostic output, creates a
compressed archive, optionally encrypts it, generates a checksum, and optionally
uploads the final artifact to FTP. Restore performs the inverse operation in a
staging directory and always verifies the checksum before decryption or
extraction.

## Prerequisites

- Bash 4+
- `tar`, `zstd`, and `sha256sum` for every backup and restore
- `age` and `age-keygen` when encryption is enabled
- `lftp` for FTP upload or download

Install all supported dependencies on Debian or Ubuntu:

```bash
sudo apt update
sudo apt install -y bash tar zstd coreutils age lftp
```

## Configuration

Copy and edit one of the reviewed examples:

```bash
cp backup/config/vps1.example.conf backup/config/vps1.conf
${EDITOR:-vi} backup/config/vps1.conf
```

Configuration files are trusted Bash and must be reviewed before use. The
following values control the workflow:

| Setting | Default | Purpose |
| --- | --- | --- |
| `BACKUP_NAME` | required | Safe label used in archive and log names |
| `BACKUP_PATHS` | required array | Absolute paths copied into the archive |
| `COMMAND_OUTPUTS` | required array | Read-only diagnostics as `file.txt\|command` |
| `COMMAND_OUTPUTS_FATAL` | `false` | Abort when a diagnostic command fails |
| `BACKUP_WORK_ROOT` | `backup/work` | Temporary staging directory |
| `BACKUP_OUTPUT_DIR` | `backup/archives` | Local archive directory |
| `KEEP_WORKDIR` | `false` | Preserve staging data for inspection |
| `ENCRYPTION_ENABLED` | `false` | Encrypt the compressed archive with age |
| `AGE_BINARY` | `age` | age executable name or test path |
| `AGE_RECIPIENTS_FILE` | empty | Public recipients used for encryption |
| `AGE_IDENTITY_FILE` | empty | Private identity used only during restore |
| `KEEP_UNENCRYPTED_ARCHIVE` | `false` | Retain `.tar.zst` after encryption |
| `FTP_ENABLED` | `false` | Upload backups after local creation |
| `FTP_HOST` | empty | Hostinger FTP hostname or IPv4 address |
| `FTP_PORT` | `21` | FTP port |
| `FTP_USER` | empty | FTP account name |
| `FTP_PASSWORD_ENV` | `SDRC_BACKUP_FTP_PASSWORD` | Environment variable containing the password |
| `FTP_REMOTE_DIR` | `/backups` | Remote archive directory |
| `FTP_SSL_VERIFY_CERT` | `true` | Verify the FTP/FTPS server certificate |

Diagnostic commands are best-effort by default. Their combined stdout and
stderr are saved even when they return non-zero. Path collection, compression,
encryption, checksum, and FTP failures remain fatal.

## Backup

```bash
./backup/backup.sh CONFIG_FILE [--dry-run]
```

Example:

```bash
./backup/backup.sh backup/config/vps1.conf --dry-run
./backup/backup.sh backup/config/vps1.conf
```

Dry-run mode validates configuration and reports planned actions. It does not
copy paths, run diagnostics, create workspaces or archives, encrypt, or contact
FTP. It writes only its log under `backup/logs/`.

Archives and checksums are built under `.partial` names and atomically renamed.
Incomplete local outputs are removed after failure. When FTP is enabled, the
checksum and final archive are also uploaded under remote `.partial` names and
renamed after both transfers complete.

## age encryption

Generate the private identity on a protected administrative or restore system,
not on the source VPS:

```bash
mkdir -p ~/.config/sdrc-backup/age
chmod 700 ~/.config/sdrc-backup/age
age-keygen -o ~/.config/sdrc-backup/age/sdrc-backup-key.txt
age-keygen -y ~/.config/sdrc-backup/age/sdrc-backup-key.txt \
  > ~/.config/sdrc-backup/age/recipients.txt
```

Keep `sdrc-backup-key.txt` offline or on the protected restore host. Copy only
the public `recipients.txt` file to the source server, for example:

```text
/etc/sdrc-backup/recipients/vps1.txt
```

Configure the source host:

```bash
ENCRYPTION_ENABLED=true
AGE_RECIPIENTS_FILE="/etc/sdrc-backup/recipients/vps1.txt"
KEEP_UNENCRYPTED_ARCHIVE=false
```

Configure the protected restore host separately:

```bash
AGE_IDENTITY_FILE="$HOME/.config/sdrc-backup/age/sdrc-backup-key.txt"
```

Never commit an age private identity.

## Hostinger FTP

FTP is disabled by default. Configure connection metadata without a password:

```bash
FTP_ENABLED=true
FTP_HOST="203.0.113.10"
FTP_PORT=21
FTP_USER="u123456789"
FTP_PASSWORD_ENV="SDRC_BACKUP_FTP_PASSWORD"
FTP_REMOTE_DIR="/backups"
FTP_SSL_VERIFY_CERT=true
```

Provide the password only through the named environment variable:

```bash
export SDRC_BACKUP_FTP_PASSWORD='set-at-runtime'
./backup/backup.sh backup/config/vps1.conf
unset SDRC_BACKUP_FTP_PASSWORD
```

Only set `FTP_SSL_VERIFY_CERT=false` when using encrypted archives, because
FTP/FTPS transport trust is weakened. Standard FTP also exposes credentials in
transit; use a dedicated account and prefer encrypted archives.

Remote retention is not implemented.

## Restore

```bash
./backup/restore.sh CONFIG_FILE ARCHIVE_OR_REMOTE_FILENAME RESTORE_DIR [OPTIONS]
```

Restore an existing local archive and adjacent `.sha256` file:

```bash
./backup/restore.sh backup/config/vps1.conf \
  /secure/backups/vps1_TIMESTAMP.tar.zst.age \
  /tmp/vps1-restore
```

Download the archive and checksum from FTP first:

```bash
export SDRC_BACKUP_FTP_PASSWORD='set-at-runtime'
./backup/restore.sh backup/config/vps1.conf \
  vps1_TIMESTAMP.tar.zst.age \
  /tmp/vps1-restore --ftp
unset SDRC_BACKUP_FTP_PASSWORD
```

Restore options:

- `--ftp` treats the source as a filename under `FTP_REMOTE_DIR`.
- `--dry-run` performs validation and logging without downloading or extracting.
- `--force` permits extraction into an existing directory without deleting it.

Without `--force`, the restore directory must not already exist. The filesystem
root is never accepted as a restore destination.

## Manual restore equivalent

This is the manual equivalent of an encrypted FTP restore:

```bash
export SDRC_BACKUP_FTP_PASSWORD='set-at-runtime'
work="$(mktemp -d)"
archive="vps1_TIMESTAMP.tar.zst.age"

LFTP_PASSWORD="$SDRC_BACKUP_FTP_PASSWORD" lftp --norc <<LFTP_COMMANDS
set cmd:fail-exit yes
set ftp:passive-mode true
open --env-password --user "u123456789" -p "21" "ftp://203.0.113.10"
cd "/backups"
get "$archive" -o "$work/$archive"
get "${archive}.sha256" -o "$work/${archive}.sha256"
bye
LFTP_COMMANDS

(cd "$work" && sha256sum --check "${archive}.sha256")
age --decrypt \
  --identity "$HOME/.config/sdrc-backup/age/sdrc-backup-key.txt" \
  --output "$work/${archive%.age}" "$work/$archive"
mkdir /tmp/vps1-restore
zstd -q -d -c "$work/${archive%.age}" | tar -C /tmp/vps1-restore -xf -
unset SDRC_BACKUP_FTP_PASSWORD
```

If certificate verification is intentionally disabled, add
`set ssl:verify-certificate no` to the `lftp` session.

## Command reference

```bash
./backup/backup.sh --help
./backup/restore.sh --help
./backup/backup.sh --version
./backup/restore.sh --version
```

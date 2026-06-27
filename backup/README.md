# Backup

Phase 5 creates local backups with optional age encryption and Hostinger FTP
upload. It copies configured paths into an
isolated working directory, captures configured command output, compresses the
result as `.tar.zst`, optionally encrypts it as `.tar.zst.age`, and writes a
`.sha256` checksum for the final archive.

Archives and checksums are published only after their write completes. Failed
runs remove `.partial` files and any incomplete archive/checksum output.

Configuration files are trusted Bash files. The required settings are
`BACKUP_NAME`, the indexed `BACKUP_PATHS` array, and the indexed
`COMMAND_OUTPUTS` array. Copy an example to an ignored `*.conf` file before
adapting it for a server.

`COMMAND_OUTPUTS` are best-effort diagnostics by default. Their stdout and
stderr are saved together in the requested text file. A non-zero exit status is
logged as a warning and the backup continues. Set `COMMAND_OUTPUTS_FATAL=true`
to abort on the first diagnostic failure. This setting affects only diagnostic
commands; path collection, compression, encryption, and checksum failures are
always fatal.

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

Archives are written to `backup/archives/` by default. Remote retention,
database capture/import, and writes back to source systems are not performed;
those libraries remain placeholders only.

## Hostinger FTP upload

Install `lftp`:

```bash
sudo apt update
sudo apt install -y lftp
```

FTP is disabled by default. Copy an example config and set the Hostinger FTP
host, port, user, and remote directory without adding a password:

```bash
FTP_ENABLED=true
FTP_HOST="203.0.113.10"
FTP_PORT=21
FTP_USER="u123456789"
FTP_PASSWORD_ENV="SDRC_BACKUP_FTP_PASSWORD"
FTP_REMOTE_DIR="/backups"
FTP_SSL_VERIFY_CERT=true
```

Only set `FTP_SSL_VERIFY_CERT=false` when using encrypted archives, because
FTP/FTPS transport trust is weakened.

Export the password only in the process environment, then run the backup:

```bash
export SDRC_BACKUP_FTP_PASSWORD='set-at-runtime'
./backup/backup.sh backup/config/vps1.conf --dry-run
./backup/backup.sh backup/config/vps1.conf
unset SDRC_BACKUP_FTP_PASSWORD
```

The final archive and matching checksum upload under `.partial` names. The
checksum is renamed first and the archive second, so the final archive name
marks a completed pair. Upload failure is fatal but does not delete the valid
local backup. Remote retention is not implemented.

Hostinger's standard FTP service uses port 21. Standard FTP does not provide
the transport security of SFTP, so use a dedicated account and enable age
encryption for backup contents.

## Automated restore

On the protected restore host, copy the server config and set the private
identity path without committing it:

```bash
AGE_IDENTITY_FILE="$HOME/.config/sdrc-backup/age/sdrc-backup-key.txt"
```

Restore an existing local archive and adjacent `.sha256` file:

```bash
./backup/restore.sh backup/config/vps1.conf \
  /secure/backups/vps1_20260101T000000Z.tar.zst.age \
  /tmp/vps1-restore
```

Download the archive and checksum from FTP before restoring:

```bash
export SDRC_BACKUP_FTP_PASSWORD='set-at-runtime'
./backup/restore.sh backup/config/vps1.conf \
  vps1_20260101T000000Z.tar.zst.age \
  /tmp/vps1-restore --ftp
unset SDRC_BACKUP_FTP_PASSWORD
```

Add `--dry-run` to preview without downloading, decrypting, creating the restore
directory, or extracting. An existing restore directory is rejected unless
`--force` is supplied; force permits extraction into that directory but does
not delete it first.

## Manual restore equivalent

The following is the exact manual sequence automated by `restore.sh`. Replace
the example host, user, filename, and paths with values from the protected
restore environment:

```bash
export SDRC_BACKUP_FTP_PASSWORD='set-at-runtime'
work="$(mktemp -d)"
archive="vps1_20260101T000000Z.tar.zst.age"

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

If `FTP_SSL_VERIFY_CERT=false` is intentionally required, the equivalent manual
`lftp` session also includes `set ssl:verify-certificate no`.

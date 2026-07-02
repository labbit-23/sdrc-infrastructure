# SDRC Infrastructure

SDRC Infrastructure is SDRC's infrastructure automation and disaster recovery
toolkit. The current release provides configurable local backups, optional age
encryption, Hostinger FTP transfer, checksum verification, and safe extraction
into a dedicated restore directory.

Current version: **1.0.0**. The canonical version is stored in [`VERSION`](VERSION).

## Scope

The repository is intended to support:

- VPS1 and VPS2
- future Nextcloud and Collabora deployments
- local Mirth, DEXA, and Orthanc systems

Only the backup and restore workflow is implemented today. Infrastructure
inventory, monitoring, and CTO dashboard integration remain roadmap items.

## Capabilities

- Copy configured files and directories without modifying their sources.
- Capture read-only diagnostic command output on a best-effort basis.
- Create atomic `.tar.zst` archives and SHA-256 checksum files.
- Optionally encrypt archives for one or more age recipients.
- Optionally upload or download backups through Hostinger FTP using `lftp`.
- Verify checksums before decryption and extraction.
- Refuse to extract into an existing directory unless explicitly forced.
- Preview backup and restore operations with `--dry-run`.

Database dumps, remote retention, service reconfiguration, and database imports
are intentionally not implemented.

## Prerequisites

The scripts target Linux with Bash 4 or newer and GNU userland tools.

| Command | Package | Required for |
| --- | --- | --- |
| `bash` | `bash` | All operations |
| `tar` | `tar` | Archive creation and extraction |
| `zstd` | `zstd` | Compression and decompression |
| `sha256sum` | `coreutils` | Archive integrity checks |
| `age`, `age-keygen` | `age` | Encrypted backup and restore |
| `lftp` | `lftp` | FTP upload and download |

On Debian or Ubuntu:

```bash
sudo apt update
sudo apt install -y bash tar zstd coreutils age lftp
```

`age` is optional when encryption is disabled. `lftp` is optional when using
local backups and restores only.

## Quick start

Copy an example configuration. Files ending in `backup/config/*.conf` are
ignored by Git because deployed configurations may contain host-specific data.

```bash
cp backup/config/vps1.example.conf backup/config/vps1.conf
${EDITOR:-vi} backup/config/vps1.conf
```

Preview and run a local backup:

```bash
./backup/backup.sh backup/config/vps1.conf --dry-run
./backup/backup.sh backup/config/vps1.conf
```

Restore an archive and its adjacent checksum into a new directory:

```bash
./backup/restore.sh backup/config/vps1.conf \
  backup/archives/vps1_TIMESTAMP.tar.zst \
  /tmp/vps1-restore
```

See [`backup/README.md`](backup/README.md) for encryption, FTP, configuration,
and restore procedures.

## Command help

```bash
./backup/backup.sh --help
./backup/restore.sh --help
./backup/backup.sh --version
./backup/restore.sh --version
```

## Safety and security

- Configuration files are sourced as trusted Bash. Never run an unreviewed
  configuration file.
- Passwords are read only from the configured environment variable and are not
  stored in example configurations.
- Keep age private identity files outside this repository and off source VPS
  systems. Source systems need only public recipient files.
- Standard FTP does not protect credentials in transit. Prefer a dedicated FTP
  account, keep certificate verification enabled where FTPS is available, and
  encrypt backup contents with age.
- `--force` permits restore extraction into an existing directory; it does not
  delete that directory first.

## Repository layout

- `backup/` — backup/restore entrypoints, libraries, examples, logs, and output
- `docs/` — architecture and operational documentation
- `inventory/` — future infrastructure inventory definitions
- `monitoring/` — future monitoring configuration
- `scripts/` — future operational scripts

Runtime logs, workspaces, archives, deployed configs, credentials, and key
material are excluded by `.gitignore`.

## Versioning

Releases use Semantic Versioning. Update [`VERSION`](VERSION) when publishing a
release; both command entrypoints report this value through `--version`.

## Roadmap

- Remote retention policies
- Database-native backup and restore workflows
- Automated restore validation
- Infrastructure inventory and monitoring
- CTO dashboard integration

## License

No open-source license has been selected yet. Add a `LICENSE` file before
publishing this repository as open source.

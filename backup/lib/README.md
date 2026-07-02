# Backup Libraries

- `archive.sh` provides compression and checksum helpers.
- `common.sh` provides logging, version lookup, and configuration validation.
- `encrypt.sh` provides age encryption and decryption helpers.
- `upload_ftp.sh` contains the optional `lftp` upload and restore-download helpers.

These files are sourced libraries, not standalone commands. The supported
entrypoints are `backup/backup.sh` and `backup/restore.sh`.

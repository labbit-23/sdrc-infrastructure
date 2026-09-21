# Google Drive sync-folder backup handoff

The backup engine can atomically copy the completed archive and its checksum to
a folder managed by Google Drive for desktop or another sync client. It does not
use Google APIs or store Google credentials.

## One-time setup

1. Create/select the local synchronized folder and obtain its absolute path.
2. Ensure the account running the scheduled backup can create files there.
3. Configure age encryption first. The existing VPS2 schema archives are
   unencrypted and should not be placed in cloud storage as-is.
4. In the deployed ignored `.conf`, set:

```bash
ENCRYPTION_ENABLED=true
AGE_RECIPIENTS_FILE="/etc/sdrc-backup/recipients/vps2-labit-core.txt"
KEEP_UNENCRYPTED_ARCHIVE=false
SYNC_FOLDER_ENABLED=true
SYNC_FOLDER_DIR="/absolute/path/to/Google Drive/SDRC-Backups/vps2-labit-core"
```

5. Run a dry run, then a real backup. The backup process copies under `.partial`
   names, renames both files, and verifies the copied artifact against the copied
   checksum. Confirm separately in the Google Drive UI that upload completed.

```bash
./backup/backup.sh backup/config/vps2-labit-core.conf --dry-run
./backup/backup.sh backup/config/vps2-labit-core.conf
```

## Publishing the latest existing backup

Prefer generating a fresh encrypted backup after the sync folder is supplied.
If an existing artifact must be handed off, encrypt it first, generate a checksum,
copy both using `.partial` names, rename, verify locally, then confirm the remote
Google Drive copy. Do not publish the current plaintext `.tar.zst` dumps.

The sync folder is a second local copy until the client confirms cloud upload.
Google Drive sync is not immutable; deletion/ransomware can propagate. Add an
independent protected copy or provider snapshot and document retention/version
recovery.

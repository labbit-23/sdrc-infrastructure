# Backup Configuration

The `*.example.conf` files are reviewed templates with no credentials. Copy one
to an ignored `*.conf` file and adapt it for the target host.

Configurations are sourced as trusted Bash because `BACKUP_PATHS` and
`COMMAND_OUTPUTS` are arrays. Never use an unreviewed configuration file.

Passwords must not be placed in a config. Set `FTP_PASSWORD_ENV` to the name of
an environment variable and export the password only for the backup or restore
process. Keep age private identities outside the repository and configure
`AGE_IDENTITY_FILE` only on a protected restore host.

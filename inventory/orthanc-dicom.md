# Orthanc / DICOM systems

Status: discovery required. No topology or configuration is asserted yet.

Use [the Orthanc runbook](../runbooks/orthanc.md) and ask the local machine
agent to return command output with secrets and patient data redacted.

## Information required from the local agent

1. Hostname, OS/version, hardware/VM, disks/filesystems/free space, IPs/VLAN,
   DNS, timezone/NTP, firewall and VPN/Tailscale state.
2. Orthanc version and installation method (package, Docker/Compose, binary or
   service), startup unit, service user, listening ports and reverse proxy/TLS.
3. Redacted configuration: file paths and effective settings for AE Title,
   DICOM/HTTP ports, authentication enabled/disabled, plugins and Lua scripts.
   Do not return passwords/tokens or patient data.
4. Storage directory/volume, database/index backend and path, PostgreSQL plugin
   if used, filesystem size/growth, compression and retention/deletion policy.
5. Modalities/peers: AE Title, host and port; purpose and direction; redact only
   credentials, not routing topology. Include Mirth/LIMS/reporting dependencies.
6. Exact source repository/config deployment, image/package versions, commands
   to install/start/stop/restart, logs and health checks.
7. Current backup job, destination, schedule, retention, encryption, last
   success, last restore test, and whether DICOM objects and index are captured
   consistently together.
8. Sample validation using synthetic/non-patient DICOM: C-ECHO, store/query,
   retrieval, UI/API health and downstream route checks.

Recommended read-only discovery commands (adapt to the installation):

```bash
hostnamectl
lsblk -f
df -hT
systemctl status orthanc --no-pager
systemctl cat orthanc
orthanc --version
docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Ports}}\t{{.Status}}'
docker compose config --images
ss -lntup
```

Configuration output must be reviewed/redacted locally before sharing.

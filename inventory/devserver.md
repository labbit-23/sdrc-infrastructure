# devserver / local application server

Last reviewed: 21 September 2026
Status: active local application, development and backup host

## Identity and capacity

- Hostname: `devserver`
- Location/owner: local SDRC premises (exact room and hardware owner TODO: VERIFY)
- Hardware: Intel desktop-class system, Core i3-4130, 2 cores/4 threads
- OS: Ubuntu 24.04.5 LTS, x86-64
- Kernel: `7.0.0-31-generic`
- Memory: 7.7 GiB RAM and 4 GiB swap
- Primary disk: 256 GB SATA SSD; approximately 153 GB free at review
- LAN: `192.168.134.85/24`, gateway `192.168.134.1`
- Tailscale: `100.65.63.54`

Do not treat these addresses as credentials. Firewall rules, router reservations
and public reachability remain TODO: VERIFY.

## Current roles

The machine is not merely a report-delivery desktop. Discovery found:

- four Next.js listeners on TCP 3000, 3001, 3100 and 3102;
- two application worktrees involved in those listeners:
  `/home/sdrc/projects/sdrc/sdrc-website` and
  `/home/sdrc/projects/labit/labit-patient`;
- a user-level `labit-db-tunnel.service`, exposing the remote Supabase PostgreSQL
  connection only at local TCP `127.0.0.1:15432`;
- the `sdrc-infrastructure` repository and nightly logical PostgreSQL backups;
- SSH, Tailscale, GNOME/GDM and AnyDesk for administration;
- development/agent processes during the review.

Docker and PM2 were not installed. Exact ownership of TCP 7070 and UDP 50001 is
TODO: VERIFY with privileged process inspection.

## Application startup and recovery risk

The four Next.js processes were live and had been running since approximately
13–14 September, but no PM2 installation or corresponding system-level service
was found. Their startup mechanism and automatic recovery after reboot are
TODO: VERIFY. Do not reboot this host until each listener is mapped to a named
application, working directory, environment source, log path and reproducible
service unit.

The Supabase tunnel is managed by a user systemd service. Capture its unit in
this repository after confirming that it contains no secrets, and document the
SSH host/key recovery location without committing the private key.

## Backups

The `sdrc` user crontab runs the repository backup script nightly:

- 02:00 IST: `vps2-labit-core`
- 03:30 IST: `vps2-public`
- stated retention: 30 daily and 84 weekly archives

Archives and SHA-256 sidecars were present through the 21 September run (UTC
filenames dated 20 September). They are local and unencrypted; Google Drive
sync-folder publication was not enabled at review. These are schema-level
logical dumps, not yet a complete Supabase disaster-recovery set. See the
[backup policy](../runbooks/backup-policy.md) and
[Google Drive procedure](../runbooks/google-drive-backups.md).

The backup password is obtained at runtime from VPS2 over SSH. Confirm that
cron failure cannot expose it in logs or process listings and replace this with
a least-privilege secret mechanism when practical.

## Desktop and remote access

- GDM is running an Xorg login session.
- AnyDesk is enabled and running.
- HDMI and VGA were both reported disconnected; Xorg created a 1024x768
  fallback display.
- A physical monitor is not required for server workloads. Reliable unattended
  AnyDesk access may require a virtual display/dummy plug or a separately tested
  headless configuration.

AnyDesk was consuming roughly 0.5–0.7 GiB during review. The host had recently
experienced an OOM kill and was using most of its swap. Multiple interactive
development/agent processes and Next.js contributed to memory pressure.

## Operational issues

- Two mount units were failed: `mnt-ge-lunar-data.mount` and
  `mnt-ge-lunar-shared.mount`. Identify the remote storage, intended consumers,
  credentials-file location and required boot behaviour.
- Tailscale reported DNS/control-plane timeouts and inability to reach a DERP
  relay. Diagnose local DNS/Internet reliability before relying on Tailscale as
  the sole recovery path.
- Confirm firewall policy for SSH and application ports. Binding a process to
  all interfaces does not establish that it is safely firewalled.
- Add service health checks and backup failure alerts.
- Record UPS/power protection and BIOS power-on-after-outage behaviour.

## Known tailnet peers

Discovery showed peers named `dicom`, `sdrc-h81`, `sdrc-orthanc` and `sdrc`.
Names and addresses are discovery clues only; their roles and ownership must be
confirmed in their own inventory records.

## Maintenance validation

After any reboot or relevant change, validate at minimum:

```bash
systemctl --failed
systemctl status ssh tailscaled anydesk --no-pager
systemctl --user status labit-db-tunnel.service --no-pager
ss -lntup
curl -fsS http://127.0.0.1:3000/ >/dev/null
curl -fsS http://127.0.0.1:3001/ >/dev/null
curl -fsS http://127.0.0.1:3100/ >/dev/null
curl -fsS http://127.0.0.1:3102/ >/dev/null
```

Application-specific health endpoints should replace homepage probes once
identified.

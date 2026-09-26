# lab-mirth — local analyzer / instrument host

Last reviewed: 26 September 2026
Provenance: **not yet inspected directly from this repository's side.** Facts below
come from `integrations/mirth/INFRASTRUCTURE_LAB_MIRTH.md` (repo
`labbit-23/integrations`, written 2026-09-26 by another session working on the
integrations host) and from what the user told us. Devserver's SSH key is not yet
installed on this machine (`sdrc@100.71.105.110` rejects it), so nothing here is
independently verified. Treat entries marked *unverified* accordingly.

- Hostname: `lab-mirth` (formerly `sdrc-h81`)
- LAN address: `192.168.134.41`; Tailscale: `100.71.105.110`
- OS: Ubuntu 24.04 LTS
- Hardware (observed 2026-09-26 by the other session): 8 GiB RAM, 4 GiB swap,
  about 117 GiB free disk
- Role: the local analyzer/instrument host, separate from the application
  integration host (`sdrc-integrations`, see `sdrc-integrations.md`)
- Power schedule (user): switched off outside lab hours (the lab closed about 14:00
  on 2026-09-25). It was reachable on Tailscale on the morning of 2026-09-26.
- Migration in progress (user): lab Mirth channels are being moved here from
  `sdrc-integrations`, one by one.

## Services (per the other session's document; unverified)

| Service | State / location | Purpose |
| --- | --- | --- |
| Mirth Connect | `mcservice.service`; ports `8443`, `2025`, `2026` | analyzer channels and order/result routing |
| Sysmex bridge | `/opt/integrations/sysmex`; Python service on TCP `1250` | ASTM transport to the local Mirth at `.41`, order forwarding |
| Clinitek client | live executable under `/home/sdrc/clinitek` | connects to the Clinitek instrument at `192.168.134.71:10001` |
| D10 bridge/UI | planned | to join the common integration-service model |
| Electrolytes bridge/UI | planned | to join the common integration-service model |

## Discrepancy to resolve

The document lists the Sysmex bridge as running on this host, but on the morning of
2026-09-26 `sdrc-integrations` (`192.168.134.62`) still had `sysmex-bridge` online
under PM2 with an **established connection on port 1250 from `192.168.134.210`**
(presumably the analyser). So the live Sysmex path still ends on `sdrc-integrations`
at that moment. Confirm which host is authoritative once SSH works, and make sure
both are not connected to the analyser at once.

## Gaps

- TODO: install devserver's key here and do a direct discovery pass (Mirth version,
  channel list, services, disk/RAM, listening ports, what is actually running).
- The Clinitek client is a live executable under `/home/sdrc/clinitek`, not yet
  moved to `/opt` nor run as a systemd unit, so it is not guaranteed to survive a
  reboot (per the source document).
- Backups: none known. Machine-specific credentials and live `config.ini` files are
  deliberately kept outside Git, so they are recoverable only from a backup that
  does not exist yet. Mirth channel configuration is likewise unbacked.
- Because the host is powered off nightly, a pull-based backup must run while it is
  on, or tolerate it being offline.
- Deployment direction (source document): keep Mirth as the systemd/Java process
  that owns its channels; run each bridge as its own systemd service with separate
  working directory, logs and restart policy; commit only redacted templates.

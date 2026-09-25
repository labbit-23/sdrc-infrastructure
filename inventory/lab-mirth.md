# lab-mirth — lab Mirth / analyser-bridge host

Last reviewed: 25 September 2026 (user-reported only; not yet observed directly)

- Hostname: `lab-mirth` (formerly `sdrc-h81`; Tailscale shows the new name as of 2026-09-25)
- Tailscale: `100.71.105.110`
- Role (per the user, 2026-09-25): runs Mirth Connect plus one or two Python
  services that bridge ASTM (and similar analyser protocols) to HL7.
- Power schedule: **switched off during lab shutoff hours** (the lab closed
  around 14:00 on 2026-09-25). It is offline in Tailscale outside lab hours
  by design, not a fault.
- Migration in progress: lab Mirth channels are being moved one by one from
  `sdrc-integrations` (see `sdrc-integrations.md`) to this host.

## Access

Devserver's SSH key has not been added here yet, so this host has not been
inspected. Add it while the machine is powered on, then run discovery.

## Gaps

- TODO: VERIFY OS, hardware, RAM/disk, Mirth version, channel list, the
  Python bridge services (paths, startup mechanism, which analysers), and
  network addresses.
- TODO: backup coverage. None known. Because the host is powered off
  nightly, any pull-based backup must run while it is on, or the job needs
  to tolerate it being offline.
- TODO: confirm nothing needs this host outside lab hours before relying on
  the nightly shutdown during the channel migration.

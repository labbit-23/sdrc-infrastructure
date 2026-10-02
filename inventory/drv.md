# drv

Last reviewed: 2026-10-02
Owner: TODO

## Identity and purpose

- Purpose: intended as a runtime helper machine (headless browser/Playwright
  rendering, throwaway build/test checkouts) for the devserver workload,
  **not** a second place to edit repos and not capable of useful LLM/coding-
  agent work (see Hardware below). Off most of the time, woken on demand.
- Hostname/provider or physical hardware: local machine on the SDRC LAN,
  behind the Sophos XG106w. Not a cloud VPS.
- OS/kernel/CPU/RAM/storage: Ubuntu 24.04.5 LTS, kernel 7.0.0-38-generic.
  Intel Core i3-4130 (Haswell, 2013) 2C/4T @ 3.4GHz, Intel H81 Express
  chipset. 7.7GB RAM (**16GB hard ceiling** — H81 has 2 DDR3 DIMM slots,
  8GB/DIMM max; slot occupancy not yet confirmed, no sudo on this box yet).
  233GB disk, ~203GB free. No discrete GPU — only integrated Intel HD 4400
  (no CUDA/compute). Realistic GPU upgrade path, if a free PCIe slot and
  the PSU allow it (unconfirmed, no sudo/physical inspection yet): a
  ≤75W card with no external power connector, e.g. GTX 1650 4GB — nothing
  bigger without a PSU change. USB AI accelerators (Coral/NCS2) ruled out:
  vision-only, not applicable to LLM/coding work.
- Network addresses: Tailscale `100.88.224.105` (hostname `drv`, connects
  via the `blr` DERP relay only — never seen a direct address). LAN
  `192.168.134.221`, currently a **dynamic** DHCP lease (not yet a static
  reservation — user intends to add one for this exact IP, see Sophos
  DHCP: 4 existing static reservations are `LAB-MIRTH` .41,
  `SDRC-ORTHANC` .61, `SDRC-REPORT` .62 [sdrc-integrations], 
  `SDRC-REPORT-DELIVERY` .85 [devserver]). SSH user `drv`.

## Wake-on-LAN

Wired in previously but never tested until 2026-10-02 (from devserver,
`sdrc-report-delivery`/`SDRC-REPORT-DELIVERY`, same LAN as `drv`).
**WOL does not work over Tailscale** (it's an L2 broadcast; Tailscale is a
unicast overlay and doesn't reach an offline node's `tailscaled` anyway) —
it only works from a machine on `drv`'s own physical LAN, broadcasting to
that LAN's broadcast address.

- MAC address: `00:e0:21:cd:10:31` (found via the Sophos WebAdmin's live
  DHCP lease view — Configure > Network > DHCP > current/active leases,
  **not** the static-reservations list, since `drv` wasn't a reservation).
- Command used (from devserver, same LAN, `wakeonlan` package):
  ```
  wakeonlan -i 192.168.134.255 00:e0:21:cd:10:31
  ```
- WOL itself has no acknowledgement in the protocol (fire-and-forget UDP
  broadcast on port 9) — confirmation is empirical only: ping/SSH
  reachability after the packet is sent.

### WOL log

| Date (IST) | From | Result | Notes |
| --- | --- | --- | --- |
| 2026-10-02 | devserver (this repo, Claude session) | Success | First-ever test. Host answered ping ~45s after the packet, SSH login succeeded immediately after. Lease at the time: `192.168.134.221`. |

## Software and operation

- Installed runtimes: stock Ubuntu 24.04 desktop-ish install (NetworkManager,
  pipewire/wireplumber running — appears to have been a desktop machine, not
  a stripped server image). Not yet inventoried further (no sudo yet).
- Applications/services and versions: not yet inventoried.
- SSH access: `drv@192.168.134.221` (LAN) confirmed working 2026-10-02.
  `sudo` on this box requires a password — not yet obtained, so `dmidecode`
  (exact RAM slot count/occupancy, PSU-relevant chassis info) is unverified.

## Continuity

- Secret names and secure recovery location: none yet — no app secrets live
  here.
- Backup source/schedule/retention/encryption/off-site destination: not
  applicable yet — this machine holds no unique data as of 2026-10-02.
- Known issues and decommission status: not yet decided whether this stays
  long-term infra or reverts to whatever its prior desktop role was. See
  "Purpose" above for what it's realistically good for.

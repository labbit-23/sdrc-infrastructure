# sdrc-integrations — local integrations/ops workstation

Last reviewed: 25 September 2026

- Hostname: `sdrc-integrations`
- Tailscale: `100.103.168.62` (tailnet device name shows as `sdrc`)
- Reachable as `sdrc-report@100.103.168.62`
- Location/owner: local SDRC premises (exact room TODO: VERIFY)
- OS: Ubuntu 24.04.5 LTS, kernel 7.0.0-31-generic, x86_64
- Memory: 7.6 GiB RAM, 3.6 GiB swap
- Primary disk: 219 GB, 163 GB free (22% used) at review
- Role: this is NOT a single-purpose Mirth box. It's a general local
  workstation doing double duty as an integrations/ops hub AND an
  interactive desktop (GNOME remote desktop + AnyDesk both active, heavy
  Chrome usage, multiple concurrent `claude`/`codex` agent sessions observed
  during this review).

Not previously documented anywhere in this repository before this review;
`inventory/README.md` only listed "Mirth, analysers/interfaces" as
outstanding discovery.

## Services

| Service | Path | Notes |
| --- | --- | --- |
| Mirth Connect | `/opt/mirthconnect` (1.6G) | `mcservice.service`, running since 2026-09-11, embedded appdata DB at `appdata/mirithdb`. Channel inventory/config not yet enumerated. |
| ERPNext (Frappe bench) | `/opt/frappe-bench` (5.8G) | Site `sdrc.local`. This is the ERPNext host referenced in earlier attendance-migration work (see `runbooks/attendance-erpnext-migration.md`) — not previously tied to this machine in the repo. Per the user (2026-09-25): ERPNext's only real remaining consumer is `zk-attendance`, and that dependency is nearly decoupled — ERPNext is planned for decommissioning once that's complete. Don't invest further backup/ops effort here beyond what's already running. |
| MariaDB 10.11.14 | — | Backs ERPNext (`mariadb-dump` visible in ERPNext's own backup log, `127.0.0.1:3306`). |
| Redis ×2 | `127.0.0.1:11000`, `127.0.0.1:13000` | Frappe cache/queue, standard ERPNext dependency. |
| Sysmex bridge | `/opt/integrations/sysmex` | Hematology analyser interface (PM2: `sysmex-bridge`, TCP 1250). On 2026-09-26 it had an established connection from `192.168.134.210` (presumably the analyser), so the live Sysmex path still ended here even though `lab-mirth`'s document also lists a Sysmex bridge; see `lab-mirth.md`. Repo: `labbit-23/integrations`. |
| ZK attendance panel | `/opt/zk-attendance` (71M) | Biometric check-in integration (PM2: `zk-panel`). |
| DICOM export / MWL | `/opt/labbit-utils/workers/` (2.0G total) | PM2: `dicom-export-cr`, `mwl-all` (radiology modality worklist). |
| DEXA app + collector | `/opt/sdrc/sdrc-dexa-app`, `/opt/sdrc/sdrc-dexa-worker/worker` (858M) | PM2: `sdrc-dexa-app`, `sdrc-collector-api`. |
| labbit monitoring | `/opt/labbit-py` (243M) | PM2: `labbit-monitoring-local`. |
| nginx | `/etc/nginx/sites-enabled/default` only | No custom vhosts configured as of review. |

PM2 process list (`pm2-sdrc-report.service`, all online at review):
`labbit-monitoring-local`, `erpnext` (0.3MB — likely a stub/placeholder
entry, not the real Frappe workload), `sdrc-dexa-app`,
`sdrc-collector-api`, `zk-panel`, `sysmex-bridge`, `dicom-export-cr`,
`mwl-all`.

Other listening ports not yet identified: `7070` (tcp+udp), `443` (bound
to the Tailscale IP directly — not nginx, since nginx has no custom
vhost), `8086`, `8000`, `1250`, `7119`. TODO: VERIFY owners (needs sudo,
not attempted this review).

## Backup coverage

- **ERPNext/MariaDB**: already has its own working backup —
  `bench --site all backup` via crontab every 6 hours (`0 */6 * * *`),
  logging to `/opt/frappe-bench/logs/backup.log`. Confirmed running
  successfully (dumps present for 00:00, 06:00, 12:00 on 2026-09-25,
  ~2.4MB each). **Local-only, no off-site copy** — same gap as everything
  else in this infrastructure before the devserver pipeline work; no
  retention policy confirmed beyond whatever `bench` defaults to.
- **Mirth channels/config**: no backup found. Matches the existing
  `backup-policy.md` "Unknown" coverage entry — now confirmed as a real
  gap, not just an undiscovered one.
- **Sysmex/ZK/DICOM/DEXA integration configs**: no backup found.
- Nothing on this host is covered by the devserver backup pipeline
  (`backup/config/*.conf`) as of this review.

## Operations and recovery gaps

- **Memory pressure, flagged urgent 2026-09-25, remediated same day.** At
  review, 985MiB free RAM and swap essentially full (3.6 GiB used of
  3.6 GiB) caused a near-incident: an in-place `swapoff`/resize attempt on
  the full swap file triggered severe thrashing (load average briefly hit
  27.91, rising) since the kernel had nowhere to reclaim swapped pages
  into. Interrupted cleanly (Linux's `swapoff` aborts safely on a pending
  signal, no data/swap-file corruption). Resolved by: killing the
  ERPNext/Frappe dev-mode processes (`bench serve` + 2 `esbuild`
  dev-tooling processes, ~1.3GB — justified given ERPNext's planned
  decommission, see above) and Chrome (~2GB), which let the original
  `/swap.img` reclaim finish naturally, then adding a second, independent
  swap file (`/swap2.img`, 12G, added to `/etc/fstab` for persistence)
  rather than resizing the original in place. Result: swap now 15G total
  (was 3.6G), RAM available headroom back to ~3.0Gi (was 479Mi at the
  worst point).
  **Root cause not fixed, only the symptom**: this machine still runs live
  Mirth/Sysmex integration traffic *and* is used as an interactive desktop
  (Chrome, GNOME remote desktop, AnyDesk) *and* runs multiple concurrent AI
  coding-agent sessions, all on 7.6GB RAM. The added swap buys headroom,
  not a real fix — worth revisiting once the Mirth channel migration
  (see below) and ERPNext decommission reduce this machine's load, or
  separating the interactive-desktop role from the integration-hosting
  role entirely.
- TODO: VERIFY Mirth channel inventory, message store location/retention,
  and whether the embedded Derby `mirithdb` is the only channel state or
  there's an external DB.
- TODO: VERIFY unidentified listening ports (7070, 443 direct-bind, 8086,
  8000, 1250, 7119).
- TODO: establish encrypted off-site backup for ERPNext's existing local
  dumps, Mirth config/channels, and the other integration configs —
  candidate to extend the devserver backup pipeline
  (`backup/config/*.conf`) the same way VPS1 was: devserver pulls over
  SSH, this host stays a pure data source, no credentials needed here.
- Second local host `lab-mirth` (formerly `sdrc-h81`, `100.71.105.110`) is where lab Mirth
  channels are being migrated, one by one. It is powered off outside lab
  hours (explaining its offline status); see `lab-mirth.md`.

After maintenance validate `systemctl --failed`, `pm2 status`, free memory
and swap usage, and each integration's actual message flow (not just
process liveness).

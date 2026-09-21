# VPS1 — Labit application server

Last reviewed: 21 September 2026

- Hostname: `ubuntu-4gb-hel1-1`
- Provider: Hetzner
- OS: Ubuntu 22.04.5 LTS, kernel 5.15.0-191-generic, x86_64
- Role: primary application/frontend server
- Runtimes: Node.js 22.23.2, npm 10.9.8, PM2 6.0.14, nginx 1.18.0,
  OpenJDK 21.0.12, Python 3.10.12, Docker 29.1.3
- Extra APT repository: NodeSource Node.js 22.x

## Services

PM2 inventory observed during the September review:

```text
labbit-api                 labbit-cto-collector
labbit-cto-digest          labbit-frontend
labbit-monitoring-vps      labbit-ops-cleanup
labit-app-api              labit-core
labit-jasper               labit-patient
labit-ui                   report-enqueue-watch
report-sender              shivam-archive
```

`labbit-cto-digest` and `labbit-ops-cleanup` may be scheduled rather than
continuous. Verify their invocation before treating a stopped state as failure.

Known application roots: `/opt/labbit-py`, `/opt/labit`, `/opt/py_utils`,
`/opt/shivam-archive`, and `/opt/labbit`. Known Python environments exist below
those roots and at `/opt/.venv`; collect exact ownership and interpreter versions
with the configuration collector before an OS upgrade.

## Operations and recovery gaps

- TODO: VERIFY CPU, RAM, disk layout, IPs, DNS, firewall, nginx sites/TLS, PM2
  startup user and saved process file.
- TODO: VERIFY repositories/deploy revisions, environment-file locations
  (locations only), log rotation, monitoring and alert owners.
- TODO: establish encrypted daily configuration/application-state backup,
  off-site copy, retention and tested rebuild.
- `labbit-api` is known to start through `/opt/labbit-py/start.sh`.

After maintenance validate `systemctl --failed`, `pm2 status`, nginx config and
external health/user journeys for every continuously running application.

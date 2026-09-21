# Ubuntu 22.04 to 24.04 staged upgrade

Upgrade VPS1 first and observe stability before VPS2. Before either host: update
normal packages, verify service health, collect configuration/version inventory,
confirm a fresh encrypted off-site backup and recent restore test, and take a
Hetzner snapshot. Record rollback criteria.

After VPS1, verify nginx/TLS, Node/npm/PM2 startup, Java, Docker, Python virtual
environments and every external Labit user journey.

For VPS2, additionally confirm full PostgreSQL/Supabase recovery coverage and
the bind mount at `/opt/supabase/docker/volumes/db/data`. Save Compose/config and
image versions. After the host upgrade, start the existing pinned stack and
verify PostgreSQL, Auth, REST, Storage, Kong, Supavisor, VPS1 connectivity and
host PM2 services. Do not combine the host upgrade with Supabase/PostgreSQL image
upgrades.

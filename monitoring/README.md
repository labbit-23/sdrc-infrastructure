# Monitoring

Infrastructure monitoring and management utilities for local SDRC systems.

## Sophos Firewall Management API

REST API for managing Sophos XG106w firewall on the local LAN (192.168.134.0/24).

### Features

- **Sophos restart endpoint**: Emergency firewall reboot (works even when WANs are down)
- **Accessible via Tailscale**: Can be called from CTO dashboard on VPS (100.65.63.54:5001)
- **Accessible via LAN**: Can be called from local machine (192.168.134.185:5001)

### Environment Variables

```bash
SOPHOS_SSH_HOST=192.168.134.1           # Sophos firewall IP
SOPHOS_SSH_USER=admin                    # SSH username
SOPHOS_SSH_PASSWORD=<password>           # SSH password
SOPHOS_API_PORT=5001                     # API port (default)
SOPHOS_API_DEBUG=0                       # Debug mode (0/1)
```

### Running on Local Machine

```bash
# Direct execution
python3 monitoring/sophos_api.py

# Via PM2
pm2 start "python3 /opt/sdrc-infrastructure/monitoring/sophos_api.py" \
  --name sophos-api-local \
  --update-env

pm2 save
```

### Endpoints

- **GET `/health`** — Health check
  ```
  curl http://100.65.63.54:5001/health
  ```

- **POST `/api/infrastructure/sophos/restart`** — Restart Sophos firewall
  ```
  curl -X POST http://100.65.63.54:5001/api/infrastructure/sophos/restart
  ```

### Use Cases

1. **Emergency WAN restore**: If both WANs are down, local admin can restart Sophos via this endpoint (works on local LAN)
2. **Remote restart**: VPS dashboard can trigger restart via Tailscale without needing manual SSH access

### Dependencies

- `flask` — Web framework
- `paramiko` — SSH client library

### CTO Dashboard Integration

The SophosWanCard component in labit-main calls this endpoint when "Restart Firewall" button is clicked.
Endpoint URL: `http://100.65.63.54:5001/api/infrastructure/sophos/restart`

# REST API Support Design

## Overview
Add support for Cobalt Strike 4.12+ REST API to the Docker container, enabling programmatic access to C2 operations.

## Requirements
- REST API must be exposed externally like other teamserver services
- Use same password as teamserver for authentication
- Always enabled (no optional flag needed)
- Requires `--experimental-db` flag on teamserver

## Architecture

### Service Orchestration
Add REST API as fourth supervised service with startup sequence:

1. **cs_installer** (priority=1): Downloads and installs Cobalt Strike
2. **teamserver** (priority=2): Starts team server with `--experimental-db` flag
3. **listener** (priority=3): Configures auto-start listeners
4. **restapi** (priority=4): Starts REST API server

### Networking
- **Internal**: REST API connects to teamserver on `127.0.0.1:50050`
- **External**: REST API listens on `0.0.0.0:50443` for external access
- **Docker**: Port 50443 exposed in Dockerfile and mapped in docker-compose

### Authentication
- Username: `csrestapi` (Cobalt Strike default)
- Password: Reuses `TEAMSERVER_PASSWORD` environment variable

## Implementation Components

### 1. Dockerfile Changes
```dockerfile
EXPOSE 50050 50443
```

### 2. New Script: scripts/start-restapi.sh
```bash
#!/bin/bash
set -euo pipefail

CS_DIR="/opt/cobaltstrike"
RESTAPI_SCRIPT="${CS_DIR}/server/csrestapi"

# Wait for teamserver on port 50050
echo "Waiting for teamserver to be ready..."
while ! nc -z localhost 50050; do
    sleep 5
done

echo "Starting Cobalt Strike REST API..."
cd "$CS_DIR/server" || exit 1

exec "$RESTAPI_SCRIPT" \
    --pass "$TEAMSERVER_PASSWORD" \
    --user csrestapi \
    --host 127.0.0.1 \
    --port 50050
```

### 3. Teamserver Script Update
Add `--experimental-db` flag to teamserver startup in `scripts/start-teamserver.sh:93`

### 4. supervisord.conf Addition
```ini
[program:restapi]
command=/bin/bash -c 'while ! nc -z localhost 50050; do sleep 5; done; /opt/cobaltstrike/scripts/start-restapi.sh'
priority=4
autostart=true
autorestart=true
startretries=3
startsecs=10
stopwaitsecs=10
stdout_logfile=/var/log/supervisor/restapi.out.log
stderr_logfile=/var/log/supervisor/restapi.err.log
```

### 5. Documentation Updates

**README.md docker-compose example:**
```yaml
services:
  cobaltstrike:
    image: chryzsh/cobaltstrike:latest
    container_name: cobaltstrike
    ports:
      - "50050:50050"  # Teamserver communication
      - "50443:50443"  # REST API
      - "53:53/udp"    # DNS listener
      - "443:443"      # HTTPS listener
      - "80:80"        # HTTP listener
    volumes:
      - ./profiles:/opt/cobaltstrike/profiles
      - ./server:/opt/cobaltstrike/server
      - ./logs:/var/log/supervisor
    environment:
      - LICENSE_KEY=your_license_key_here
      - TEAMSERVER_PASSWORD=your_secure_password
      - C2_PROFILE_NAME=your.profile
      - DNS_LISTENER_DOMAIN_NAME=ns1.example.com
      - DNS_LISTENER_STAGER_DOMAIN_NAME=ns1.example.com
      - SMB_LISTENER_NAMED_PIPE_NAME=msagent_pipe
    restart: unless-stopped
```

**docs/CONFIGURATION.md:**
Add section explaining:
- REST API endpoint: `https://<host>:50443`
- Default credentials: `csrestapi` / `TEAMSERVER_PASSWORD`
- REST API documentation reference

**docs/TROUBLESHOOTING.md:**
Add troubleshooting for:
- REST API not starting (check `--experimental-db` flag)
- Connection refused (check port 50443 exposed)
- Authentication failures (verify TEAMSERVER_PASSWORD)

## Error Handling
- REST API waits for teamserver availability before starting
- Auto-restarts on unexpected exits
- Logs captured to separate log files for debugging
- Standard retry mechanisms (3 attempts)

## Testing Verification
After deployment, verify with:
```bash
curl -k -u csrestapi:password https://localhost:50443/api/v1/beacons
```

## Limitations
Per Cobalt Strike documentation:
- Server-side Aggressor Scripts via REST API restricted to Sleep/Aggressor (no Java bindings)
- File uploads not supported via REST API (use SSH/SCP instead)
- Requires `--experimental-db` flag (database feature)

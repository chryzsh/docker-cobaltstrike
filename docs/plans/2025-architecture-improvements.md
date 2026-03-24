# Docker Cobalt Strike Architecture Improvements

## Current Architecture

The current implementation uses Docker to containerize Cobalt Strike with the following components:

- Ubuntu 22.04 base image
- Supervisord for process management
- Shell scripts for installation and service management
- CNA templates for listener configuration

## Identified Issues

### 1. Security Concerns
- Container runs as root
- Default password in environment variables
- No health checks
- No package version pinning
- No SSL/TLS configuration for internal communication
- No secrets management

### 2. Container Configuration
- Basic Dockerfile without multi-stage builds
- No .dockerignore file
- No container resource limits
- No proper signal handling
- No container health monitoring

### 3. Process Management
- Basic supervisord configuration
- File-based service coordination
- Limited retry and restart policies
- No proper dependency management
- No graceful shutdown handling

### 4. Error Handling & Reliability
- Basic error handling with set -e
- No cleanup on failure
- No retry mechanisms for downloads
- No checksum verification
- No backup mechanisms

### 5. Configuration Management
- Hardcoded paths and configurations
- Basic environment variable validation
- No configuration validation
- Limited profile selection logic

## Improvement Plan

### 1. Security Enhancements

#### Container Security
```dockerfile
# Add to Dockerfile
ARG USER_ID=1000
ARG GROUP_ID=1000

RUN groupadd -g $GROUP_ID cobaltstrike && \
    useradd -u $USER_ID -g $GROUP_ID -m cobaltstrike

USER cobaltstrike

HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD nc -z localhost 50050 || exit 1
```

#### Package Version Pinning
```dockerfile
# Update package installation
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      curl=7.81.0-1ubuntu1.15 \
      netcat=1.10-46 \
      expect=5.45.4-2build1 \
      supervisor=4.2.1-2ubuntu4 \
      gettext-base=0.21-4ubuntu4 \
      openjdk-11-jdk=11.0.20.1+1-0ubuntu1~22.04
```

### 2. Process Management Improvements

#### Enhanced Supervisord Configuration
```ini
[supervisord]
nodaemon=true
logfile=/var/log/supervisor/supervisord.log
pidfile=/var/run/supervisord.pid
childlogdir=/var/log/supervisor
user=cobaltstrike

[program:cs_installer]
command=/opt/cobaltstrike/scripts/install-teamserver.sh
autostart=true
autorestart=false
startretries=3
stopwaitsecs=10
stdout_logfile=/var/log/supervisor/cs_installer.out.log
stderr_logfile=/var/log/supervisor/cs_installer.err.log

[program:teamserver]
command=/opt/cobaltstrike/scripts/start-teamserver.sh
autostart=false
autorestart=true
startretries=3
startsecs=10
stopwaitsecs=10
stdout_logfile=/var/log/supervisor/teamserver.out.log
stderr_logfile=/var/log/supervisor/teamserver.err.log

[program:listener]
command=/opt/cobaltstrike/scripts/start-listeners.sh
autostart=false
autorestart=true
startretries=3
startsecs=10
stopwaitsecs=10
stdout_logfile=/var/log/supervisor/listener.out.log
stderr_logfile=/var/log/supervisor/listener.err.log

[eventlistener:processes]
command=python3 /opt/cobaltstrike/scripts/process_monitor.py
events=PROCESS_STATE
```

### 3. Enhanced Error Handling

#### Installation Script Improvements
```bash
#!/bin/bash
set -euo pipefail
trap cleanup EXIT

cleanup() {
    rm -f /tmp/cobaltstrike-dist-linux.tgz
    # Additional cleanup tasks
}

download_with_retry() {
    local url=$1
    local output=$2
    local max_attempts=3
    local attempt=1

    while [ $attempt -le $max_attempts ]; do
        if curl -sSL --retry 3 -o "$output" "$url"; then
            return 0
        fi
        echo "Download attempt $attempt failed. Retrying..."
        ((attempt++))
        sleep 5
    done
    return 1
}
```

### 4. Configuration Management

#### Environment Configuration
```bash
# Add to start-teamserver.sh
validate_config() {
    local required_vars=(
        "TEAMSERVER_PASSWORD"
        "C2_PROFILE_NAME"
        "LICENSE_KEY"
    )

    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ]; then
            echo "Error: Required environment variable $var is not set"
            exit 1
        fi
    done

    if [ ${#TEAMSERVER_PASSWORD} -lt 12 ]; then
        echo "Error: TEAMSERVER_PASSWORD must be at least 12 characters"
        exit 1
    fi
}
```

### 5. Monitoring & Logging

#### Process Monitor Script
```python
#!/usr/bin/env python3
import sys
import os
from supervisor.childutils import listener

def write_status(status):
    with open('/var/log/supervisor/status.log', 'a') as f:
        f.write(f"{status}\n")

def main():
    while True:
        headers, payload = listener.wait()
        if headers['eventname'].startswith('PROCESS_STATE'):
            write_status(f"{headers['eventname']}: {payload}")
        listener.ok()

if __name__ == "__main__":
    main()
```

## Implementation Strategy

1. Create a staging branch for testing improvements
2. Implement security improvements first
3. Update process management
4. Enhance error handling
5. Improve configuration management
6. Add monitoring and logging
7. Test thoroughly in isolated environment
8. Document all changes and new features

## Additional Recommendations

1. **Backup Strategy**
   - Implement regular state backups
   - Add backup verification
   - Document recovery procedures

2. **Documentation**
   - Add detailed setup instructions
   - Document all environment variables
   - Include troubleshooting guide
   - Add architecture diagrams

3. **Testing**
   - Add integration tests
   - Create validation scripts
   - Document testing procedures

4. **Monitoring**
   - Add Prometheus metrics
   - Create Grafana dashboards
   - Set up alerting

5. **CI/CD**
   - Add GitHub Actions workflow
   - Implement automated testing
   - Add security scanning
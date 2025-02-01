# Troubleshooting Guide

## Common Issues and Solutions

### Container Startup Issues

#### Container Exits Immediately
**Symptoms:**
- Container stops right after starting
- Repeated restart attempts

**Solutions:**
1. Check environment variables:
   ```bash
   docker logs cobaltstrike | grep "ERROR:"
   ```
2. Verify required files:
   - C2 profile exists in mounted profiles directory
   - License key is valid
   - All required environment variables are set

#### Container Runs But Nothing Happens
**Symptoms:**
- Container appears running but no services start
- No error messages in main logs

**Solutions:**
1. Check Supervisor logs:
   ```bash
   docker exec -it cobaltstrike /bin/bash -c 'cat /var/log/supervisor/*'
   ```
2. Check individual service logs:
   ```bash
   cat logs/cs_installer.out.log
   cat logs/teamserver.out.log
   cat logs/listener.out.log
   ```

### Teamserver Connection Issues

#### Can't Connect to Teamserver
**Symptoms:**
- Unable to connect via client
- Connection refused errors

**Solutions:**
1. Test port accessibility:
   ```bash
   nc localhost 50050 -vz
   ```
2. Check Teamserver status:
   ```bash
   docker exec -it cobaltstrike /bin/bash -c 'cat /var/log/supervisor/teamserver*'
   ```
3. Verify no port conflicts:
   ```bash
   docker ps | grep 50050
   ```

### Listener Issues

#### Listeners Not Starting
**Symptoms:**
- Teamserver running but listeners not appearing
- Listener setup errors in logs

**Solutions:**
1. Check listener-specific logs:
   ```bash
   docker exec -it cobaltstrike /bin/bash -c 'cat /var/log/supervisor/listener*'
   ```
2. Verify listener environment variables:
   - Check format of domain names
   - Ensure no conflicts in port mappings

#### SSL/TLS Certificate Warnings
**Symptoms:**
- SSL warnings in HTTPS listener
- Certificate validation failures

**Solutions:**
1. This is expected with default certificates
2. Use proper certificates in production
3. Consider terminating TLS at your redirector

### Profile Issues

#### Profile Not Loading
**Symptoms:**
- Teamserver fails to start
- Profile-related errors in logs

**Solutions:**
1. Verify profile location:
   ```bash
   docker exec -it cobaltstrike ls -l /opt/cobaltstrike/profiles
   ```
2. Check profile syntax:
   - Ensure valid .profile extension
   - Verify profile format
   - Check file permissions

### Log Analysis

#### Checking All Logs
```bash
# View all supervisor logs
docker exec -it cobaltstrike /bin/bash -c 'cat /var/log/supervisor/*'

# View specific service logs
docker exec -it cobaltstrike /bin/bash -c 'cat /var/log/supervisor/cs_installer.out.log'
docker exec -it cobaltstrike /bin/bash -c 'cat /var/log/supervisor/teamserver.out.log'
docker exec -it cobaltstrike /bin/bash -c 'cat /var/log/supervisor/listener.out.log'

# View process state changes
docker exec -it cobaltstrike /bin/bash -c 'cat /var/log/supervisor/state.log'
```

#### Common Error Messages

1. "Environment validation failed":
   - Check required variables are set
   - Verify variable formats
   - Look for specific validation errors

2. "TeamServerImage not found":
   - Installation failed or incomplete
   - Check installation logs
   - Verify license key validity

3. "Trapped java.io.EOFException":
   - Normal during listener setup
   - Can be ignored if listeners are working

4. "Remote host terminated the handshake":
   - Normal for non-CS client connections
   - Can be ignored in logs

### Recovery Procedures

#### Complete Reset
If you need to start fresh:
```bash
# Stop and remove container
docker stop cobaltstrike
docker rm cobaltstrike

# Remove any persisted data
rm -rf logs/*

# Start fresh
docker-compose up -d
```

#### Recovering from Failed Installation
```bash
# Access container
docker exec -it cobaltstrike /bin/bash

# Check installation status
ls -l /opt/cobaltstrike/server/TeamServerImage

# Remove installation flag if needed
rm /opt/cobaltstrike/installer_done.flag

# Restart container
docker restart cobaltstrike
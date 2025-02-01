# Process Management and Error Handling Improvements

## Current Implementation Analysis

### Process Management Issues
- Basic supervisord configuration using file flags for coordination
- Sequential listener setup without parallelization
- No proper dependency tracking between services
- Limited retry and restart policies
- Basic process monitoring

### Error Handling Issues
- Basic error handling with set -e
- No comprehensive validation of environment variables
- No retry mechanisms for downloads and operations
- No proper cleanup on failures
- Limited logging of errors and operations

## Improvement Plan

### 1. Process Management Enhancements

#### Updated Supervisord Configuration
```ini
[supervisord]
nodaemon=true
logfile=/var/log/supervisor/supervisord.log
pidfile=/var/run/supervisord.pid
childlogdir=/var/log/supervisor

[program:cs_installer]
command=/opt/cobaltstrike/scripts/install-teamserver.sh
priority=1
autostart=true
autorestart=unexpected
startretries=3
exitcodes=0
stdout_logfile=/var/log/supervisor/cs_installer.out.log
stderr_logfile=/var/log/supervisor/cs_installer.err.log

[program:teamserver]
command=/opt/cobaltstrike/scripts/start-teamserver.sh
priority=2
autostart=false
autorestart=true
startretries=3
startsecs=10
stopwaitsecs=10
stdout_logfile=/var/log/supervisor/teamserver.out.log
stderr_logfile=/var/log/supervisor/teamserver.err.log

[program:listener]
command=/opt/cobaltstrike/scripts/start-listeners.sh
priority=3
autostart=false
autorestart=true
startretries=3
startsecs=10
stopwaitsecs=10
stdout_logfile=/var/log/supervisor/listener.out.log
stderr_logfile=/var/log/supervisor/listener.err.log

[eventlistener:state_monitor]
command=/opt/cobaltstrike/scripts/state_monitor.sh
events=PROCESS_STATE
buffer_size=100
```

#### Process State Monitor (state_monitor.sh)
```bash
#!/bin/bash

# Read STDIN in a loop for supervisor events
while read line; do
    # Write event to state log
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $line" >> /var/log/supervisor/state.log
    
    # Parse the event
    if echo "$line" | grep -q "PROCESS_STATE_EXITED"; then
        process_name=$(echo "$line" | awk '{print $3}')
        exit_code=$(echo "$line" | awk '{print $5}')
        
        # Log process exit
        echo "Process $process_name exited with code $exit_code" >> /var/log/supervisor/state.log
        
        # Handle specific process failures
        case "$process_name" in
            cs_installer)
                if [ "$exit_code" != "0" ]; then
                    echo "FATAL: Installer failed with code $exit_code" >> /var/log/supervisor/state.log
                    kill -15 $(cat /var/run/supervisord.pid)
                fi
                ;;
            teamserver)
                if [ "$exit_code" != "0" ]; then
                    echo "ERROR: Teamserver failed with code $exit_code" >> /var/log/supervisor/state.log
                fi
                ;;
            listener)
                if [ "$exit_code" != "0" ]; then
                    echo "ERROR: Listener failed with code $exit_code" >> /var/log/supervisor/state.log
                fi
                ;;
        esac
    fi
    
    # Echo back OK to supervisor
    echo "READY"
done
```

### 2. Environment Variable Validation

#### Environment Configuration (env_validator.sh)
```bash
#!/bin/bash

# Required environment variables and their validation rules
declare -A ENV_VARS=(
    ["TEAMSERVER_HOST"]="^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$|^[a-zA-Z0-9.-]+$"
    ["TEAMSERVER_PASSWORD"]="^.{8,}$"
    ["C2_PROFILE_NAME"]="^[a-zA-Z0-9._-]+\.profile$"
    ["LICENSE_KEY"]="^[A-Za-z0-9-]+$"
)

# Optional environment variables for listeners
declare -A OPTIONAL_ENV_VARS=(
    ["DNS_LISTENER_DOMAIN_NAME"]="^[a-zA-Z0-9.-]+$"
    ["HTTPS_LISTENER_DOMAIN_NAME"]="^[a-zA-Z0-9.-]+$"
    ["SMB_C2_NAMED_PIPE_NAME"]="^[a-zA-Z0-9._-]+$"
)

validate_env_vars() {
    local has_error=0

    # Validate required variables
    for var in "${!ENV_VARS[@]}"; do
        if [ -z "${!var}" ]; then
            echo "ERROR: Required environment variable $var is not set"
            has_error=1
            continue
        }

        if ! echo "${!var}" | grep -qE "${ENV_VARS[$var]}"; then
            echo "ERROR: Environment variable $var has invalid format"
            has_error=1
        fi
    done

    # Validate optional variables if set
    for var in "${!OPTIONAL_ENV_VARS[@]}"; do
        if [ -n "${!var}" ]; then
            if ! echo "${!var}" | grep -qE "${OPTIONAL_ENV_VARS[$var]}"; then
                echo "ERROR: Environment variable $var has invalid format"
                has_error=1
            fi
        fi
    done

    return $has_error
}
```

### 3. Enhanced Error Handling

#### Updated Installation Script
```bash
#!/bin/bash
set -euo pipefail

# Source environment validator
source /opt/cobaltstrike/scripts/env_validator.sh

# Validate environment variables
if ! validate_env_vars; then
    echo "Environment validation failed. Exiting."
    exit 1
fi

# Function for retrying operations
retry_operation() {
    local max_attempts=$1
    local delay=$**2**
    local command="${@:3}"
    local attempt=1

    while [ $attempt -le $max_attempts ]; do
        if eval "$command"; then
            return 0
        fi
        
        echo "Attempt $attempt failed. Retrying in $delay seconds..."
        sleep $delay
        ((attempt++))
    done

    echo "Operation failed after $max_attempts attempts"
    return 1
}

# Download with retry and validation
download_file() {
    local url=$1
    local output=$2
    local max_attempts=3
    local delay=5

    retry_operation $max_attempts $delay "curl -sSL -o $output $url"
}

# Main installation process
main() {
    # Validate environment first
    if ! validate_env_vars; then
        echo "Environment validation failed"
        exit 1
    }

    # Download and install
    if ! download_file "$DOWNLOAD_URL" "/tmp/cobaltstrike-dist-linux.tgz"; then
        echo "Failed to download Cobalt Strike"
        exit 1
    fi

    # Extract and verify
    if ! tar xzf /tmp/cobaltstrike-dist-linux.tgz -C $CS_DIR --strip-components=1; then
        echo "Failed to extract Cobalt Strike"
        exit 1
    fi

    # Run update script
    if ! retry_operation 3 5 "cd $CS_DIR && echo '$LICENSE_KEY' | java -XX:ParallelGCThreads=4 -XX:+AggressiveHeap -XX:+UseParallelGC -jar update.jar -Type:linux"; then
        echo "Failed to run update script"
        exit 1
    fi

    # Verify installation
    if [ ! -f "$TEAMSERVER_IMAGE" ]; then
        echo "TeamServerImage not found after installation"
        exit 1
    fi

    echo "Installation completed successfully"
    touch /opt/cobaltstrike/installer_done.flag
}

# Cleanup function
cleanup() {
    rm -f /tmp/cobaltstrike-dist-linux.tgz
    if [ $? -ne 0 ]; then
        echo "Installation failed, cleaning up..."
    fi
}

# Set up trap for cleanup
trap cleanup EXIT

# Run main installation
main
```

### 4. Parallel Listener Setup

#### Updated Listener Script
```bash
#!/bin/bash
set -euo pipefail

source /opt/cobaltstrike/scripts/env_validator.sh

# Validate environment variables
if ! validate_env_vars; then
    echo "Environment validation failed. Exiting."
    exit 1
fi

# Function to set up a listener
setup_listener() {
    local script_name=$1
    local env_var=$2
    local output_file="/var/log/supervisor/listener_${script_name}.log"

    if [ -n "${!env_var}" ]; then
        echo "Setting up $script_name listener..."
        {
            envsubst < "$CNA_DIR/$script_name.template" > "$CNA_DIR/$script_name"
            $CS_DIR/client/agscript 127.0.0.1 50050 svc "$TEAMSERVER_PASSWORD" "$CNA_DIR/$script_name"
        } > "$output_file" 2>&1 &
    else
        echo "Skipping $script_name listener (${env_var} not set)"
    fi
}

# Start listeners in parallel
setup_listener "dns-listener.cna" "DNS_LISTENER_DOMAIN_NAME"
setup_listener "https-listener.cna" "HTTPS_LISTENER_DOMAIN_NAME"
setup_listener "http-listener.cna" "HTTP_LISTENER_DOMAIN_NAME"
setup_listener "smb-listener.cna" "SMB_C2_NAMED_PIPE_NAME"

# Wait for all background processes to complete
wait

echo "Listener setup completed"
```

## Implementation Steps

1. **Process Management Updates**
   - Replace supervisord.conf with new version
   - Add state_monitor.sh script
   - Update process dependencies and priorities

2. **Environment Validation**
   - Add env_validator.sh script
   - Integrate validation into all scripts
   - Test with various environment configurations

3. **Error Handling**
   - Update installation script with retry logic
   - Add cleanup procedures
   - Implement proper logging

4. **Listener Management**
   - Update listener script for parallel execution
   - Add proper logging for each listener
   - Implement retry logic for listener setup

## Testing Plan

1. Test environment validation with:
   - Missing required variables
   - Invalid variable formats
   - Optional variables

2. Test process management with:
   - Service startup order
   - Service failure scenarios
   - Process monitoring

3. Test error handling with:
   - Network failures
   - Invalid configurations
   - Process crashes

4. Test listener setup with:
   - Multiple listeners
   - Failed listener scenarios
   - Parallel execution
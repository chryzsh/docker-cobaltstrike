#!/bin/bash
set -euo pipefail

# Source environment validator
source /opt/cobaltstrike/scripts/env_validator.sh

# Default directories
CS_DIR="/opt/cobaltstrike"
CNA_DIR="$CS_DIR/services"

# Get container's primary IP
TEAMSERVER_HOST=$(hostname -I | awk '{print $1}')
if [ -z "$TEAMSERVER_HOST" ]; then
    echo "Error: Failed to determine container IP address"
    exit 1
fi

# Validate environment variables
if ! validate_env_vars; then
    echo "Environment validation failed. Exiting."
    exit 1
fi

# Function to get environment variable value safely
get_env_var() {
    local var_name=$1
    eval echo "\${$var_name:-}"
}

# Function to set up a listener with retry logic
setup_listener() {
    local script_name=$1
    local env_var=$2
    local max_attempts=3
    local attempt=1
    local output_file="/var/log/supervisor/listener_${script_name}.log"
    local var_value=$(get_env_var "$env_var")

    if [ -n "$var_value" ]; then
        echo "Setting up $script_name listener..."
        
        while [ $attempt -le $max_attempts ]; do
            {
                # Create the CNA script from template
                if ! envsubst < "$CNA_DIR/$script_name.template" > "$CNA_DIR/$script_name"; then
                    echo "Failed to create CNA script from template"
                    return 1
                fi

                cd "$CS_DIR/client" || exit 1
                # Run agscript with localhost
                if $CS_DIR/client/agscript "$TEAMSERVER_HOST" 50050 svc "$TEAMSERVER_PASSWORD" "$CNA_DIR/$script_name"; then
                    echo "Successfully set up $script_name listener"
                    return 0
                fi

                echo "Attempt $attempt failed. Retrying in 5 seconds..."
                sleep 5
                ((attempt++))
            } >> "$output_file" 2>&1
        done

        echo "Failed to set up $script_name listener after $max_attempts attempts"
        return 1
    else
        echo "Skipping $script_name listener (${env_var} not set)"
        return 0
    fi
}

# Array to store background process PIDs
declare -a pids

# Start listeners in parallel
echo "Starting listeners in parallel..."

# DNS Listener
setup_listener "dns-listener.cna" "DNS_LISTENER_DOMAIN_NAME" &
pids+=($!)

# HTTPS Listener
setup_listener "https-listener.cna" "HTTPS_LISTENER_DOMAIN_NAME" &
pids+=($!)

# HTTP Listener
setup_listener "http-listener.cna" "HTTP_LISTENER_DOMAIN_NAME" &
pids+=($!)

# SMB Listener
setup_listener "smb-listener.cna" "SMB_LISTENER_NAMED_PIPE_NAME" &
pids+=($!)

# Wait for all background processes and check their exit status
failed_listeners=0
for pid in "${pids[@]}"; do
    if ! wait $pid; then
        ((failed_listeners++))
    fi
done

# Report final status
if [ $failed_listeners -eq 0 ]; then
    echo "All listeners were set up successfully"
    exit 0
else
    echo "ERROR: $failed_listeners listener(s) failed to set up properly"
    echo "Check individual listener logs in /var/log/supervisor/ for details"
    exit 1
fi

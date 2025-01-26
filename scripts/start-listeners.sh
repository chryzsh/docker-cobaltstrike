#!/bin/bash
CS_DIR="/opt/cobaltstrike"
CNA_DIR="$CS_DIR/services"

echo "Starting Cobalt Strike listeners..."

# Helper function to process CNA scripts
process_cna_script() {
    local script_name=$1
    local env_var=$2

    # Check if the corresponding environment variable exists
    if [ -n "${!env_var}" ]; then
        echo "Environment variable $env_var is set. Applying $script_name..."
        envsubst < "$CNA_DIR/$script_name.template" > "$CNA_DIR/$script_name"
        cd $CS_DIR/client
        $CS_DIR/client/agscript 127.0.0.1 50050 svc "$TEAMSERVER_PASSWORD" "$CNA_DIR/$script_name"
    else
        echo "Environment variable $env_var is not set. Skipping $script_name..."
    fi
}

# Process individual listener CNA scripts
process_cna_script "dns-listener.cna" "DNS_LISTENER_DOMAIN_NAME"
process_cna_script "https-listener.cna" "HTTPS_LISTENER_DOMAIN_NAME"
process_cna_script "http-listener.cna" "HTTPS_LISTENER_DOMAIN_NAME"
process_cna_script "smb-listener.cna" "SMB_C2_NAMED_PIPE_NAME"

echo "Finished setting up listeners."

#!/bin/bash
set -euo pipefail

# Source environment validator
source /opt/cobaltstrike/scripts/env_validator.sh

# Default directories and files
CS_DIR="/opt/cobaltstrike"
RESTAPI_SCRIPT="${CS_DIR}/server/rest-server/csrestapi"

# Validate environment variables
if ! validate_env_vars; then
    echo "Environment validation failed. Exiting."
    exit 1
fi

# Wait for teamserver to be ready on port 50050
echo "Waiting for teamserver to be ready..."
while ! nc -z localhost 50050; do
    sleep 5
done

echo "Starting Cobalt Strike REST API..."
echo "Host: 127.0.0.1:50050 (teamserver connection)"
echo "REST API Port: 50443 (default)"
echo "Username: csrestapi"

cd "$CS_DIR/server/rest-server" || exit 1

# Execute REST API server
if ! exec "$RESTAPI_SCRIPT" \
     --pass "$TEAMSERVER_PASSWORD" \
     --user csrestapi \
     --host 127.0.0.1 \
     --port 50050; then
    echo "Failed to start REST API server"
    exit 1
fi

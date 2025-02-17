#!/bin/bash
set -euo pipefail

# Source environment validator
source /opt/cobaltstrike/scripts/env_validator.sh

# Default directories and files
CS_DIR="/opt/cobaltstrike"
LICENSE_FILE="${CS_DIR}/.cobaltstrike.license"
UPDATE_SCRIPT="${CS_DIR}/update"
TEAMSERVER_SCRIPT="${CS_DIR}/server/teamserver"
TEAMSERVER_IMAGE="${CS_DIR}/server/TeamServerImage"
PROFILE_DIR="$CS_DIR/profiles"

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

# Function to get first C2 profile
verify_c2_profile() {
    if [ ! -d "$PROFILE_DIR" ]; then
        echo "Error: Profile directory $PROFILE_DIR does not exist. Mount your profiles directory to the container."
        return 1
    fi

    # Find first .profile file
    local profile_path=$(find "$PROFILE_DIR" -maxdepth 1 -type f -name "*.profile" | head -n 1)
    if [ -z "$profile_path" ]; then
        echo "Error: No .profile files found in $PROFILE_DIR"
        return 1
    fi

    echo "$profile_path"
    return 0
}

# Function to verify teamserver prerequisites
verify_prerequisites() {
    # Check for TeamServerImage
    if [ ! -f "$TEAMSERVER_IMAGE" ]; then
        echo "Error: TeamServerImage not found at $TEAMSERVER_IMAGE"
        return 1
    fi

    # Check for teamserver script
    if [ ! -f "$TEAMSERVER_SCRIPT" ]; then
        echo "Error: Teamserver script not found at $TEAMSERVER_SCRIPT"
        return 1
    fi

    # Check for license file
    if [ ! -f "$LICENSE_FILE" ]; then
        echo "Error: License file not found at $LICENSE_FILE"
        return 1
    fi

    return 0
}

# Main function
main() {
    echo "Verifying teamserver prerequisites..."
    if ! verify_prerequisites; then
        echo "Failed to verify prerequisites"
        exit 1
    fi

    echo "Verifying C2 profile..."
    PROFILE_PATH=$(verify_c2_profile)
    if [ $? -ne 0 ]; then
        echo "Failed to verify C2 profile"
        exit 1
    fi
    echo "Using C2 profile: $PROFILE_PATH"

    # Launch the teamserver
    echo "Starting Cobalt Strike Teamserver..."
    echo "Host: $TEAMSERVER_HOST"
    echo "Profile: $PROFILE_PATH"
    
    cd "$CS_DIR/server" || exit 1
    
    # Execute teamserver with proper error handling
    if ! exec "$TEAMSERVER_SCRIPT" \
         "$TEAMSERVER_HOST" \
         "$TEAMSERVER_PASSWORD" \
         "$PROFILE_PATH"; then
        echo "Failed to start teamserver"
        exit 1
    fi
}

# Run main function
main

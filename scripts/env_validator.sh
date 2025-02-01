#!/bin/bash

# Required environment variables and their validation rules
declare -A ENV_VARS=(
    ["TEAMSERVER_PASSWORD"]="^.{8,}$"
    ["LICENSE_KEY"]="^[A-Za-z0-9-]+$"
    ["C2_PROFILE_NAME"]="^[a-zA-Z0-9._-]+\.profile$"
)

# Optional environment variables for listeners
declare -A OPTIONAL_ENV_VARS=(
    ["DNS_LISTENER_DOMAIN_NAME"]="^[a-zA-Z0-9.-]+$"
    ["HTTPS_LISTENER_DOMAIN_NAME"]="^[a-zA-Z0-9.-]+$"
    ["HTTP_LISTENER_DOMAIN_NAME"]="^[a-zA-Z0-9.-]+$"
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
        fi

        if ! echo "${!var}" | grep -qE "${ENV_VARS[$var]}"; then
            echo "ERROR: Environment variable $var has invalid format"
            case "$var" in
                "TEAMSERVER_PASSWORD")
                    echo "       Password must be at least 8 characters long"
                    ;;
                "C2_PROFILE_NAME")
                    echo "       Must be a valid filename ending in .profile"
                    ;;
                "LICENSE_KEY")
                    echo "       Must contain only letters, numbers, and hyphens"
                    ;;
            esac
            has_error=1
        fi
    done

    # Validate optional variables if set
    for var in "${!OPTIONAL_ENV_VARS[@]}"; do
        if [ -n "${!var}" ]; then
            if ! echo "${!var}" | grep -qE "${OPTIONAL_ENV_VARS[$var]}"; then
                echo "ERROR: Environment variable $var has invalid format"
                echo "       Must contain only letters, numbers, dots, and hyphens"
                has_error=1
            fi
        fi
    done

    return $has_error
}

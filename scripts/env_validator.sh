#!/bin/bash
set -u  # Enable nounset to catch unbound variables

# Required environment variables and their validation rules
declare -A ENV_VARS=(
    ["TEAMSERVER_PASSWORD"]="^.{8,}$"
    ["LICENSE_KEY"]="^[A-Za-z0-9-]+$"
)

# Optional environment variables for listeners
declare -A OPTIONAL_ENV_VARS=(
    ["DNS_LISTENER_DOMAIN_NAME"]="^[a-zA-Z0-9.-]+$"
    ["DNS_LISTENER_STAGER_DOMAIN_NAME"]="^[a-zA-Z0-9.-]+$"
    ["HTTPS_LISTENER_DOMAIN_NAME"]="^[a-zA-Z0-9.-]+$"
    ["HTTP_LISTENER_DOMAIN_NAME"]="^[a-zA-Z0-9.-]+$"
    ["SMB_LISTENER_NAMED_PIPE_NAME"]="^[a-zA-Z0-9._-]+$"
)

validate_env_vars() {
    local has_error=0

    # Validate required variables
    for var in "${!ENV_VARS[@]}"; do
        value=$(eval echo \$${var})
        if [ -z "${value}" ]; then
            echo "ERROR: Required environment variable $var is not set"
            has_error=1
            continue
        fi

        if ! echo "${value}" | grep -qE "${ENV_VARS[$var]}"; then
            echo "ERROR: Environment variable $var has invalid format"
            case "$var" in
                "TEAMSERVER_PASSWORD")
                    echo "       Password must be at least 8 characters long"
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
        value=$(eval echo \$${var} 2>/dev/null || true)
        if [ -n "${value}" ]; then
            if ! echo "${value}" | grep -qE "${OPTIONAL_ENV_VARS[$var]}"; then
                echo "ERROR: Environment variable $var has invalid format"
                echo "       Must contain only letters, numbers, dots, and hyphens"
                has_error=1
            fi
        fi
    done

    return $has_error
}

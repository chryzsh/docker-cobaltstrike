#!/bin/bash

# Required environment variables and their validation rules
declare -A ENV_VARS=(
    ["TEAMSERVER_PASSWORD"]="^.{8,}$"
    ["LICENSE_KEY"]="^[A-Za-z0-9-]+$"
)

validate_env_vars() {
    local has_error=0

    # Validate required variables only
    for var in "${!ENV_VARS[@]}"; do
        if [ -z "${!var+x}" ]; then
            echo "ERROR: Required environment variable $var is not set"
            has_error=1
            continue
        fi

        if ! printf '%s' "${!var}" | grep -qE "${ENV_VARS[$var]}"; then
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

    return $has_error
}

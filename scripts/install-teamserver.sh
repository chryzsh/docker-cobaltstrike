#!/bin/bash
set -euo pipefail

# Source environment validator
source /opt/cobaltstrike/scripts/env_validator.sh

# Default directories and files
CS_DIR="/opt/cobaltstrike"
LICENSE_FILE="${CS_DIR}/.cobaltstrike.license"
UPDATE_SCRIPT="${CS_DIR}/update"
TEAMSERVER_IMAGE="${CS_DIR}/server/TeamServerImage"

# Function for retrying operations
retry_operation() {
  local max_attempts=$1
  local delay=$2
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

# Cleanup function
cleanup() {
  rm -f /tmp/cobaltstrike-dist-linux.tgz
  if [ $? -ne 0 ]; then
    echo "Installation failed, cleaning up..."
  fi
}

# Set up trap for cleanup
trap cleanup EXIT

# Main installation process
main() {
  # Validate environment first
  if ! validate_env_vars; then
    echo "Environment validation failed"
    exit 1
  fi

  # Ensure a license file exists or use the LICENSE_KEY environment variable
  if [ ! -f "$LICENSE_FILE" ]; then
    if [ -n "$LICENSE_KEY" ]; then
      echo "No mounted license file found; writing LICENSE_KEY env to $LICENSE_FILE"
      echo "$LICENSE_KEY" >"$LICENSE_FILE"
    else
      echo "ERROR: No license file at $LICENSE_FILE and no LICENSE_KEY env var provided."
      exit 1
    fi
  fi

  # Install or update Cobalt Strike if required
  if [ ! -f "$TEAMSERVER_IMAGE" ]; then
    echo "Cobalt Strike not found; attempting to download and install..."

    # Retrieve the download token with retry
    echo "Retrieving Cobalt Strike download token..."
    if ! TOKEN_RESPONSE=$(retry_operation 3 5 "curl -s -X POST -d \"dlkey=\$(cat \"$LICENSE_FILE\")\" https://download.cobaltstrike.com/download"); then
      echo "Failed to retrieve download token"
      exit 1
    fi

    # Extract token and version
    TOKEN=$(echo "$TOKEN_RESPONSE" | grep -oP 'href="/downloads/\K[^/]+')
    VERSION=$(echo "$TOKEN_RESPONSE" | grep -oP 'href="/downloads/[^/]+/\K[^/]+(?=/cobaltstrike-dist-windows\.zip)')

    if [ -z "$TOKEN" ] || [ -z "$VERSION" ]; then
      echo "ERROR: Could not retrieve a valid token or version."
      exit 1
    fi

    # Download and extract with retry
    echo "Downloading cobaltstrike-dist-linux.tgz..."
    DOWNLOAD_URL="https://download.cobaltstrike.com/downloads/${TOKEN}/${VERSION}/cobaltstrike-dist-linux.tgz"
    if ! download_file "$DOWNLOAD_URL" "/tmp/cobaltstrike-dist-linux.tgz"; then
      echo "Failed to download Cobalt Strike"
      exit 1
    fi

    # Extract and verify
    if ! tar xzf /tmp/cobaltstrike-dist-linux.tgz -C $CS_DIR --strip-components=1; then
      echo "Failed to extract Cobalt Strike"
      exit 1
    fi

    # Run update script with retry
    echo "Running the update script..."
    if ! retry_operation 3 5 "cd $CS_DIR && echo '$(cat "$LICENSE_FILE")' | java -XX:ParallelGCThreads=4 -XX:+AggressiveHeap -XX:+UseParallelGC -jar update.jar -Type:linux"; then
      echo "Failed to run update script"
      exit 1
    fi
  fi

  # The final check to see if the installation was successful
  if [ -f "$TEAMSERVER_IMAGE" ]; then
    echo "Installation completed successfully."
    touch /opt/cobaltstrike/installer_done.flag
  else
    echo "TeamServerImage not found. Installation did not complete properly."
    exit 1
  fi
}

# Run main installation
main

#!/bin/bash
set -euo pipefail

# Source environment validator
source /opt/cobaltstrike/scripts/env_validator.sh

# Default directories and files
CS_DIR="/opt/cobaltstrike"
LICENSE_FILE="${CS_DIR}/.cobaltstrike.license"
UPDATE_SCRIPT="${CS_DIR}/update"
TEAMSERVER_IMAGE="${CS_DIR}/server/TeamServerImage"

# Pre-staged tarball location — mount your downloaded tarball here to skip the download
STAGED_TARBALL="${CS_DIR}/dist/cobaltstrike-dist-linux.tgz"

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
}

# Set up trap for cleanup
trap cleanup EXIT

# Extract tarball and run update
install_from_tarball() {
  local tarball=$1

  echo "Extracting Cobalt Strike from $tarball..."
  if ! tar xzf "$tarball" -C "$CS_DIR" --strip-components=1; then
    echo "ERROR: Failed to extract Cobalt Strike from $tarball"
    exit 1
  fi

  # Run update script
  echo "Running the update script..."
  if ! retry_operation 3 5 "cd $CS_DIR && echo '$(cat "$LICENSE_FILE")' | java -XX:ParallelGCThreads=4 -XX:+AggressiveHeap -XX:+UseParallelGC -jar update.jar -Type:linux"; then
    echo "Failed to run update script"
    exit 1
  fi
}

# Main installation process
main() {
  # Validate environment first
  if ! validate_env_vars; then
    echo "Environment validation failed"
    exit 1
  fi

  # Ensure a license file exists or use the LICENSE_KEY environment variable
  if [ ! -f "$LICENSE_FILE" ]; then
    if [ -n "${LICENSE_KEY:-}" ]; then
      echo "No mounted license file found; writing LICENSE_KEY env to $LICENSE_FILE"
      echo "$LICENSE_KEY" >"$LICENSE_FILE"
    else
      echo "ERROR: No license file at $LICENSE_FILE and no LICENSE_KEY env var provided."
      exit 1
    fi
  fi

  # Install or update Cobalt Strike if required
  if [ -f "$TEAMSERVER_IMAGE" ]; then
    echo "Cobalt Strike already installed (TeamServerImage found)."
  elif [ -f "$STAGED_TARBALL" ]; then
    # Use pre-staged tarball — skips the download entirely
    echo "Found pre-staged tarball at $STAGED_TARBALL, installing from local file..."
    install_from_tarball "$STAGED_TARBALL"
  else
    # Attempt to download from cobaltstrike.com
    echo "Cobalt Strike not found; attempting to download and install..."
    echo "NOTE: If this fails due to Cloudflare blocking, pre-stage the tarball instead:"
    echo "  1. Download cobaltstrike-dist-linux.tgz from your browser"
    echo "  2. Mount it to $STAGED_TARBALL in the container"

    # Retrieve the download token with retry
    echo "Retrieving Cobalt Strike download token..."
    TOKEN_RESPONSE=""
    if ! TOKEN_RESPONSE=$(retry_operation 3 5 "curl -s -X POST -d \"dlkey=\$(cat \"$LICENSE_FILE\")\" https://download.cobaltstrike.com/download"); then
      echo "ERROR: Failed to retrieve download token."
      echo "The download server may be blocking automated requests (Cloudflare)."
      echo "Pre-stage the tarball by mounting it to: $STAGED_TARBALL"
      exit 1
    fi

    # Check for Cloudflare block page
    if echo "$TOKEN_RESPONSE" | grep -q "cf-error-details\|cf-challenge\|cf-browser-verification\|you have been blocked"; then
      echo "ERROR: Cloudflare is blocking the download request."
      echo "Pre-stage the tarball by mounting it to: $STAGED_TARBALL"
      echo "  1. Download cobaltstrike-dist-linux.tgz from https://download.cobaltstrike.com using your browser"
      echo "  2. Mount it into the container, e.g.:"
      echo "     -v /path/to/cobaltstrike-dist-linux.tgz:$STAGED_TARBALL:ro"
      exit 1
    fi

    # Extract token and version
    TOKEN=$(echo "$TOKEN_RESPONSE" | grep -oP 'href="/downloads/\K[^/]+')
    VERSION=$(echo "$TOKEN_RESPONSE" | grep -oP 'href="/downloads/[^/]+/\K[^/]+(?=/cobaltstrike-dist-windows\.zip)')

    if [ -z "$TOKEN" ] || [ -z "$VERSION" ]; then
      echo "ERROR: Could not retrieve a valid token or version from the download page."
      echo "Response may have been blocked or the page format has changed."
      echo "Pre-stage the tarball by mounting it to: $STAGED_TARBALL"
      exit 1
    fi

    # Download and extract with retry
    echo "Downloading cobaltstrike-dist-linux.tgz (version: $VERSION)..."
    DOWNLOAD_URL="https://download.cobaltstrike.com/downloads/${TOKEN}/${VERSION}/cobaltstrike-dist-linux.tgz"
    if ! download_file "$DOWNLOAD_URL" "/tmp/cobaltstrike-dist-linux.tgz"; then
      echo "ERROR: Failed to download Cobalt Strike."
      echo "Pre-stage the tarball by mounting it to: $STAGED_TARBALL"
      exit 1
    fi

    install_from_tarball "/tmp/cobaltstrike-dist-linux.tgz"
  fi

  # The final check to see if the installation was successful
  if [ -f "$TEAMSERVER_IMAGE" ]; then
    echo "Installation completed successfully."
    touch /opt/cobaltstrike/installer_done.flag
  else
    echo "ERROR: TeamServerImage not found. Installation did not complete properly."
    exit 1
  fi
}

# Run main installation
main

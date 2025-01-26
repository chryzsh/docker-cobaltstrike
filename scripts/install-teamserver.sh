#!/bin/bash
set -e  # Exit on any command failure

# Default directories and files
CS_DIR="/opt/cobaltstrike"
LICENSE_FILE="${CS_DIR}/.cobaltstrike.license"
UPDATE_SCRIPT="${CS_DIR}/update"
TEAMSERVER_IMAGE="${CS_DIR}/server/TeamServerImage"

# Ensure a license file exists or use the LICENSE_KEY environment variable
if [ ! -f "$LICENSE_FILE" ]; then
  if [ -n "$LICENSE_KEY" ]; then
    echo "No mounted license file found; writing LICENSE_KEY env to $LICENSE_FILE"
    echo "$LICENSE_KEY" > "$LICENSE_FILE"
  else
    echo "ERROR: No license file at $LICENSE_FILE and no LICENSE_KEY env var provided."
    exit 1
  fi
fi

# Install or update Cobalt Strike if required
if [ ! -f "$TEAMSERVER_IMAGE" ]; then
  echo "Cobalt Strike not found; attempting to download and install..."

  # Retrieve the download token
  echo "Retrieving Cobalt Strike download token..."
  TOKEN_RESPONSE=$(curl -s -X POST -d "dlkey=$(cat "$LICENSE_FILE")" https://download.cobaltstrike.com/download)

  # Extract token and version
  TOKEN=$(echo "$TOKEN_RESPONSE" | grep -oP 'href="/downloads/\K[^/]+')
  VERSION=$(echo "$TOKEN_RESPONSE" | grep -oP 'href="/downloads/[^/]+/\K[^/]+(?=/cobaltstrike-dist-windows\.zip)')

  if [ -z "$TOKEN" ] || [ -z "$VERSION" ]; then
    echo "ERROR: Could not retrieve a valid token or version."
    exit 1
  fi

  # Download and extract
  echo "Downloading cobaltstrike-dist-linux.tgz..."
  curl -sSL -o /tmp/cobaltstrike-dist-linux.tgz \
       "https://download.cobaltstrike.com/downloads/${TOKEN}/${VERSION}/cobaltstrike-dist-linux.tgz"
  tar xzf /tmp/cobaltstrike-dist-linux.tgz -C $CS_DIR --strip-components=1

  # Run update script
  echo "Running the update script..."
  cd $CS_DIR
  echo "$(cat "$LICENSE_FILE")" | java -XX:ParallelGCThreads=4 -XX:+AggressiveHeap -XX:+UseParallelGC -jar update.jar -Type:linux
fi

# The final check to see if the installation was successful is to check if TeamServerImage exists in the server directory
if [ -f "$TEAMSERVER_IMAGE" ]; then
  echo "Installation completed successfully."
  touch /opt/cobaltstrike/installer_done.flag
else
  echo "TeamServerImage not found. Installation did not complete properly. Exiting"
  exit
fi
# Default directories and files
CS_DIR="/opt/cobaltstrike"
LICENSE_FILE="${CS_DIR}/.cobaltstrike.license"
UPDATE_SCRIPT="${CS_DIR}/update"
TEAMSERVER_SCRIPT="${CS_DIR}/server/teamserver"
TEAMSERVER_IMAGE="${CS_DIR}/server/TeamServerImage"
#PROFILE_PATH="$CS_DIR/profiles/${C2_PROFILE_NAME}"
PROFILE_DIR="$CS_DIR/profiles"
PROFILE_PATH=""
CNA_SCRIPT="$CS_DIR/services/cs-listener-service.cna"
TEAMSERVER_HOST=$(hostname -I | awk '{print $1}') # use the container's internal IP - doesnt matter

# Dynamically find the C2 profile
if [ -d "$PROFILE_DIR" ]; then
    PROFILE_PATH=$(find "$PROFILE_DIR" -type f -name "*.profile" | head -n 1)

    if [ -z "$PROFILE_PATH" ]; then
        echo "Error: No C2 profile found in $PROFILE_DIR. Exiting..."
        exit 1
    else
        echo "Using C2 profile: $PROFILE_PATH"
    fi
else
    echo "Error: Profile directory $PROFILE_DIR does not exist. Exiting..."
    exit 1
fi

# Launch the teamserver
echo "Starting Cobalt Strike Teamserver..."
cd $CS_DIR/server
exec "$TEAMSERVER_SCRIPT" \
     "$TEAMSERVER_HOST" \
     "$TEAMSERVER_PASSWORD" \
     "$PROFILE_PATH"
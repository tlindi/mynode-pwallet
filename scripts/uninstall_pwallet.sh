#!/bin/bash

source /usr/share/mynode/mynode_device_info.sh
source /usr/share/mynode/mynode_app_versions.sh

set -x
set -e

echo "==================== UNINSTALLING APP ===================="

echo Setting trap to detect errors. Following is not error:
trap 'echo "Error occurred at $(basename "$0") line $LINENO. status $?"; exit 1' ERR

export APP=pwallet
export PWALLET_DATA=/mnt/hdd/mynode/pwallet

backup_pwallet_data() {
    echo "Backing up pWallet data..."
    cd "$PWALLET_DATA" || exit 1
    echo "Changed directory to $(pwd)"
    
    export BACKUP_PATH="../pwallet_backup"

    if [ ! -d "$BACKUP_PATH" ]; then 
        mkdir -p "$BACKUP_PATH" || { echo "Backup path '$BACKUP_PATH' couldn't be created."; exit 1; }
        chown bitcoin:bitcoin "$BACKUP_PATH" || { echo "Backup path owner couldn't be set."; exit 1; }
    fi

    export PWALLET_VERSION=$(cat "$BACKUP_PATH/pwallet_version")
    export BACKUP_TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    export BACKUP_FILE="$BACKUP_PATH/pwallet-$PWALLET_VERSION-$BACKUP_TIMESTAMP.tgz"

    echo "Backing up pWallet data..."
    echo "Source: $(pwd)"
    echo "Destination: $BACKUP_FILE"

    tar zcfv "$BACKUP_FILE" --exclude=*.log ./
}

remove_pwallet_data() {
    echo "Removing pwallet data directory..."
    cd ..
    rm -rfv /mnt/hdd/mynode/pwallet

    echo "Removing pWallet install version backup..."
    rm -rfv /mnt/hdd/mynode/pwallet_backup/pwallet_version
}

#
## Main functionality using functions above
#
if [ ! -d "$PWALLET_DATA" ]; then
    echo "pWallet datadir does not exist - backup skipped."
else
    backup_pwallet_data

    if [ ! -f "$BACKUP_FILE" ]; then
        echo "Backup file does not exist - data removal skipped."
    else
        remove_pwallet_data
    fi
fi

docker rmi "$APP" || echo "Docker image for "$APP" does not exist."
# Remove Docker images related to $APP
if docker images --format '{{.Repository}}:{{.Tag}} {{.ID}}' | grep -q "$APP"; then
    docker images --format '{{.Repository}}:{{.Tag}} {{.ID}}' \
      | grep "$APP" \
      | awk '{print $2}' \
      | sort -u \
      | xargs -r docker rmi -f
else
    echo "No $APP images found, skipping $APP removal."
fi


echo "================== DONE UNINSTALLING APP ================="

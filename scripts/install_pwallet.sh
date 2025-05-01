#!/bin/bash

source /usr/share/mynode/mynode_device_info.sh
source /usr/share/mynode/mynode_app_versions.sh

set -ex
echo "==================== INSTALLING APP ===================="

trap 'echo "Error occurred at $(basename "$0") line $LINENO. status $?"; exit 1' ERR

# --- Helper Functions ---

# 1. Set environment variables for configuration.
set_configuration_env() {
    export PHOENIX_API_URL="http://172.17.0.1:9740"
    export PHOENIX_DIR="/mnt/hdd/mynode/phoenixd"
    export PHOENIX_CONF="${PHOENIX_DIR}/phoenix.conf"
    export PWALLET_BACKUP_DIR="/mnt/hdd/mynode/pwallet_backup"
    export PWALLET_DATA="/mnt/hdd/mynode/pwallet"
    export PWALLET_CONF="${PWALLET_DATA}/appsettings.json"
    export PWALLET_UIDOMAIN=yourdomain.com
    export PWALLET_LNURLP="${PWALLET_DATA}/lnurlp"
    export PWALLET_LNURLP_USER=yourname
    export PWALLET_LNURLP_DOMAIN="$PWALLET_UIDOMAIN"
}

# 2. Check that the phoenixd directory and the required configuration file exist.
phoenixd_exists() {
    if [ ! -d "$PHOENIX_DIR" ]; then
        echo "Error: Phoenix directory '$PHOENIX_DIR' does not exist." >&2
        exit 1
    fi
    if [ ! -f "$PHOENIX_CONF" ]; then
        echo "Error: Phoenix configuration file '$PHOENIX_CONF' does not exist." >&2
        exit 1
    fi
}

# 3. Restore configuration from backup
restore_backup_data() {
    if [ ! -d "$PWALLET_BACKUP_DIR" ]; then
        mkdir -p "$PWALLET_BACKUP_DIR" || { echo "Backup path '$PWALLET_BACKUP_DIR' couldn't be created."; exit 1; }
        echo "pwallet $VERSION will be populated by default data."
    else
        export BACKUP_FILE=$(ls -1 "$PWALLET_BACKUP_DIR"/*.tgz 2>/dev/null | \
            sed -E 's/.*(.{15})\.tgz$/\1|\0/' | sort | tail -1 | cut -d'|' -f2-)
        if [ -n "$BACKUP_FILE" ]; then
            tar xzvf "$BACKUP_FILE" --strip-components=1 -C "$PWALLET_DATA"
        else
            echo "No restoreable backup was found."
        fi
    fi
}

# 4. Create the appsettings.json from a stub
create_appsettings() {
    cp -a appsettings.json "$PWALLET_CONF" || { echo "Error: Failed to copy stub to $PWALLET_CONF" >&2; exit 1; }
    chgrp docker "$PWALLET_CONF" || { echo "Error: Failed to change group ownership of $PWALLET_CONF" >&2; exit 1; }
    chmod g+w "$PWALLET_CONF" || { echo "Error: Failed to set group write permission on $PWALLET_CONF" >&2; exit 1; }
}

# 5. Set API credentials
set_api_credentials() {
    set +x
    export API_PASSWORD=$(grep '^http-password=' "$PHOENIX_CONF" | cut -d'=' -f2)
    if [ -z "$API_PASSWORD" ]; then
        echo "Error: API password in $PHOENIX_CONF is empty." >&2
        exit 1
    fi
    set -x
}

# 6. Create the database stub
create_database_stub() {
    export PWALLET_DB="${PWALLET_DATA}/SimpLN.db"
    if [ ! -f "$PWALLET_DB" ]; then
        touch "$PWALLET_DB"
        chgrp docker "$PWALLET_DB"
        chmod g+w "$PWALLET_DB"
    fi
}

# 7. Create the LNURLp folder structure
create_lnurlp_structure() {
    if [ ! -d "$PWALLET_LNURLP" ]; then
        cp -av wwwroot/.well-known/lnurlp "$PWALLET_DATA/"
        chgrp -R bitcoin "$PWALLET_LNURLP"
        chmod -R g+w "$PWALLET_LNURLP"
        mv "$PWALLET_LNURLP/zap.example" "$PWALLET_LNURLP/$PWALLET_LNURLP_USER"
    fi
}

# 8. Update appsettings
update_appsettings() {
    exec 7> >(sed "s|${API_PASSWORD}|****************************************************************|g" >&2)
    export BASH_XTRACEFD=7
    export PS4='+ '

    sed -i -E "s|(\"ApiUrl\":\s*\")[^\"]*(\",?)|\1${PHOENIX_API_URL}\2|" "$PWALLET_CONF"
    sed -i -E "s|(\"ApiPassword\":\s*\")[^\"]*(\",?)|\1${API_PASSWORD}\2|" "$PWALLET_CONF"
    sed -i -E "s|(\"UiDomain\":\s*\")[^\"]*(\",?)|\1${PWALLET_UIDOMAIN}\2|" "$PWALLET_CONF"
    sed -i -E "s|(\"LnUrlpDomain\":\s*\")[^\"]*(\",?)|\1${PWALLET_LNURLP_DOMAIN}\2|" "$PWALLET_CONF"
}

# 9. Version backup
version_backup() {
    if [ ! -d "$PWALLET_BACKUP_DIR" ]; then
        mkdir -p "$PWALLET_BACKUP_DIR"
        chgrp -R bitcoin "$PWALLET_BACKUP_DIR"
        chmod -R g+w "$PWALLET_BACKUP_DIR"
    fi
	
	echo $VERSION > "$PWALLET_BACKUP_DIR/pwallet_version"
}

# Make service working directory.
mkdir -p /opt/mynode/pwallet || true

# Set environment variables.
set_configuration_env

# Verify that the phoenixd directory and its configuration exist.
phoenixd_exists

# If PWALLET_CONF does not exist, try restoring from backup.
if [ ! -f "$PWALLET_CONF" ]; then
    restore_backup_data
    # After restoration, if PWALLET_CONF still does not exist, create defaults.
    if [ ! -f "$PWALLET_CONF" ]; then
         create_appsettings
         set_api_credentials
         create_database_stub
         create_lnurlp_structure
         update_appsettings
    fi
fi

version_backup

docker build -t pwallet .
docker image prune -f

echo "================== DONE INSTALLING APP ================="

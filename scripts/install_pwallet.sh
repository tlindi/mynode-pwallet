#!/bin/bash

source /usr/share/mynode/mynode_device_info.sh
source /usr/share/mynode/mynode_app_versions.sh

set -ex

echo "==================== INSTALLING APP ===================="

# The current directory is the app install folder and the app tarball from GitHub
# has already been downloaded and extracted. Any additional env variables specified
# in the JSON file are also present.

export PHOENIX_CONF="/mnt/hdd/mynode/phoenixd/phoenix.conf"
export PWALLET_DATA="/mnt/hdd/mynode/pwallet"
export PWALLET_CONF="${PWALLET_DATA}/appsettings.json"
# There is not official way to support dynamical domainname on MyNodeBTC.
# so PWALLET_LNURL creates nonworking template for advanced users to modify.
export PWALLET_UIDOMAIN=yourdomain.com
export PWALLET_LNURLP=$PWALLET_DATA/lnurlp
export PWALLET_LNURLP_USER=yourname
export PWALLET_LNURLP_DOMAIN=$PWALLET_UIDOMAIN

# Verify that the Phoenix configuration file exists
if [ ! -f "$PHOENIX_CONF" ]; then
    echo "Error: Phoenix configuration file '$PHOENIX_CONF' does not exist." >&2
    exit 1
fi

#   Verify if pwallet configuration file exists, and create if needed
if [ ! -f "$PWALLET_CONF" ]; then
    echo "Creating stub for configuration file '$PWALLET_CONF' cause it does not exist."
    mkdir -p /mnt/hdd/mynode/pwallet || { echo "Error: Failed to create directory /mnt/hdd/mynode/pwallet" >&2; exit 1; }
    cp -a appsettings.json "$PWALLET_CONF" || { echo "Error: Failed to copy stub appsettings.json to $PWALLET_CONF" >&2; exit 1; }
    chgrp docker "$PWALLET_CONF" || { echo "Error: Failed to change group ownership of $PWALLET_CONF" >&2; exit 1; }
    chmod g+w "$PWALLET_CONF" || { echo "Error: Failed to set group write permission on $PWALLET_CONF" >&2; exit 1; }
fi

# Set API_URL and update it in PWALLET_CONF
export API_URL="http://172.17.0.1:9740"

# Extract API_PASSWORD from phoenix.conf and verify it's not empty
export API_PASSWORD=$(grep '^http-password=' "$PHOENIX_CONF" | cut -d'=' -f2)
if [ -z "$API_PASSWORD" ]; then
    echo "Error: API password in $PHOENIX_CONF is empty. Please set a valid 'http-password'." >&2
    exit 1
fi

sed -i -E "s|(\"ApiPassword\":\s*\")[^\"]*(\",?)|\1${API_PASSWORD}\2|" "$PWALLET_CONF"
sed -i -E "s|(\"ApiUrl\":\s*\")[^\"]*(\",?)|\1${API_URL}\2|" "$PWALLET_CONF"
sed -i -E "s|(\"UiDomain\":\s*\")[^\"]*(\",?)|\1${PWALLET_UIDOMAIN}\2|" "$PWALLET_CONF"
sed -i -E "s|(\"LnUrlpDomain\":\s*\")[^\"]*(\",?)|\1${PWALLET_LNURLP_DOMAIN}\2|" "$PWALLET_CONF"

echo "Configuration updated successfully in $PWALLET_CONF."

## Create LNURLp folder structure with dafault LNURLp user
if [ ! -d $PWALLET_LNURLP ]; then
    cp -av wwwroot/.well-known/lnurlp $PWALLET_DATA/
    chgrp -R bitcoin $PWALLET_LNURLP
    chmod -R g+w $PWALLET_LNURLP
	cp -a $PWALLET_LNURLP/zap.example $PWALLET_LNURLP/$PWALLET_LNURLP_USER
fi

# make db location stub file (so docker build wont create folder on its location)
#
export PWALLET_DB=$PWALLET_DATA/SimpLN.db
if [ ! -f "$PWALLET_DB" ]; then
    echo "$PWALLET_DB database does not exist! Creating stub..."
    touch "$PWALLET_DB"
    chgrp docker "$PWALLET_DB"
    chmod g+w "$PWALLET_DB"
fi

docker build -t pwallet .

# Dare you clean after build?
#docker image prune -af

echo "================== DONE INSTALLING APP ================="


#!/bin/bash

source /usr/share/mynode/mynode_device_info.sh
source /usr/share/mynode/mynode_app_versions.sh

set -ex

echo "==================== INSTALLING APP ===================="

# The current directory is the app install folder and the app tarball from GitHub
# has already been downloaded and extracted. Any additional env variables specified
# in the JSON file are also present.

export PWALLET_DATA="/mnt/hdd/mynode/pwallet"

# make appsettings
export PWALLET_CONF="${PWALLET_DATA}/appsettings.json"
if [ ! -f "$PWALLET_CONF" ]; then
    echo "$PWALLET_CONF configuration does not exist! Creating stub..."
    mkdir -p /mnt/hdd/mynode/pwallet || { echo "Error: Failed to create directory /mnt/hdd/mynode/pwallet" >&2; exit 1; }
    cp -a appsettings.json "$PWALLET_CONF" || { echo "Error: Failed to copy stub appsettings.json to $PWALLET_CONF" >&2; exit 1; }
    chgrp docker "$PWALLET_CONF" || { echo "Error: Failed to change group ownership of $PWALLET_CONF" >&2; exit 1; }
    chmod g+w "$PWALLET_CONF" || { echo "Error: Failed to set group write permission on $PWALLET_CONF" >&2; exit 1; }
fi

# Set API_URL and update it in PWALLET_CONF
export API_URL="http://172.17.0.1:9740"
# Escape forward slashes for sed
escaped_api_url=$(echo "$API_URL" | sed 's/\//\\\//g')
sed -i -E "s/^([[:space:]]*\"ApiUrl\":\s*\")[^\"]*(\",?)/\1${escaped_api_url}\2/" "$PWALLET_CONF" || { echo "Error: Failed to update ApiUrl in $PWALLET_CONF" >&2; exit 1; }

# Verify that the Phoenix configuration file exists before extracting the password
PHOENIX_CONF="/mnt/hdd/mynode/phoenixd/phoenix.conf"
if [ ! -f "$PHOENIX_CONF" ]; then
    echo "Error: Phoenix configuration file '$PHOENIX_CONF' does not exist." >&2
    exit 1
fi

# Extract API_PASSWORD from phoenix.conf and verify it's not empty
export API_PASSWORD=$(grep '^http-password=' "$PHOENIX_CONF" | cut -d'=' -f2)
if [ -z "$API_PASSWORD" ]; then
    echo "Error: API password in $PHOENIX_CONF is empty. Please set a valid 'http-password'." >&2
    exit 1
fi

# Update ApiPassword in PWALLET_CONF
sed -i -E "s/^([[:space:]]*\"ApiPassword\":\s*\")[^\"]*(\",?)/\1${API_PASSWORD}\2/" "$PWALLET_CONF" || { echo "Error: Failed to update ApiPassword in $PWALLET_CONF" >&2; exit 1; }

echo "Configuration updated successfully in $PWALLET_CONF."


# Comment rest of the lines
if [ -f "$PWALLET_CONF" ]; then
    sed -i -E '
      s/^([[:space:]]*)"UiDomain": "SET BY USER",/\1\/\/ "UiDomain": "SET BY USER",/g;
      s/^([[:space:]]*)"LnUrlpDomain":\s*"[[:space:]]*SET BY USER"/\1\/\/ "LnUrlpDomain": "SET BY USER"/g
    ' "$PWALLET_CONF" || { 
      echo "Error: Failed to update domain comments in $PWALLET_CONF" >&2
      exit 1
    }
else
    echo "Error: Wallet configuration file '$PWALLET_CONF' does not exist." >&2
    exit 1
fi

# make db location stub
#
export PWALLET_DB=$PWALLET_DATA/SimpLN.db
if [ ! -f $PWALLET_DB ]; then
    echo "$PWALLET_DB database does not exist! Creating stub..."
    touch $PWALLET_DB
    chgrp docker $PWALLET_DB
    chmod g+w $PWALLET_DB
fi

## get wwwroot/.well-known/lnurlp dir and make it editable for docker
#ToDo-implement domain name parcing also to appsettings above
#
export PWALLET_LNURLP=$PWALLET_DATA/lnurlp
export PWALLET_LNURLP_USER=yourname
export PWALLET_LNURLP_DOMAIN=yourdomain.com
# create dafault LNURLp user
if [ ! -d $PWALLET_LNURLP ]; then
    cp -av wwwroot/.well-known/lnurlp $PWALLET_DATA/
    chgrp -R bitcoin $PWALLET_LNURLP
    chmod -R g+w $PWALLET_LNURLP
	mv -v $PWALLET_LNURLP/zap.example $PWALLET_LNURLP/$PWALLET_LNURL_USER
	# sudo 'sed s/yourdomain.com/(echo $PWALLET_LNURLP_DOMAIN)/g' or how this was done anyhow
fi

docker build -t pwallet .

# Dare you clean after build?
#docker image prune -af

echo "================== DONE INSTALLING APP ================="


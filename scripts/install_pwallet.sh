#!/bin/bash

source /usr/share/mynode/mynode_device_info.sh
source /usr/share/mynode/mynode_app_versions.sh

set -x
set -e

echo "==================== INSTALLING APP ===================="

# The current directory is the app install folder and the app tarball from GitHub
# has already been downloaded and extracted. Any additional env variables specified
# in the JSON file are also present.

export PWALLET_DATA=/mnt/hdd/mynode/pwallet

# make appsettings
#
export PWALLET_CONF=$PWALLET_DATA/appsettings.json
if [ ! -f $PWALLET_CONF ]; then
    echo "$PWALLET_CONF configuration does not exist! Creating stub..."
    mkdir -p /mnt/hdd/mynode/pwallet
    cp -a appsettings.json $PWALLET_CONF
    chgrp docker $PWALLET_CONF
    chmod g+w $PWALLET_CONF
fi
# Set API_URL
export API_URL=http://172.17.0.1:9740
sed -i "s/\"ApiUrl\": \"SET BY USER\"/\"ApiUrl\": \"$(echo $API_URL | sed 's/\//\\\//g')\"/g" $PWALLET_CONF
# Extract API_PASSWORD from phoenixd.conf
export API_PASSWORD=$(grep '^http-password=' /mnt/hdd/mynode/phoenixd/phoenix.conf | cut -d'=' -f2)
# Set password and remove "," from end due following lines are commended later on
sed -i "s/\"ApiPassword\"\: \"SET BY USER\",/\"ApiPassword\"\: \"$API_PASSWORD\"/g" $PWALLET_CONF
# Comment rest of the lines
sed -i 's/\"UiDomain\"\: \"SET BY USER\",/\/\/ \"UiDomain\"\: \"SET BY USER\",/g' $PWALLET_CONF
sed -i 's/\"LnUrlpDomain\"\: \"	SET BY USER\"/\/\/ \"LnUrlpDomain\"\: \"SET BY USER\"/g' $PWALLET_CONF

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


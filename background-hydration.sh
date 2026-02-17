#!/bin/bash
# background-hydration.sh
set -e

FLAG_FILE="/var/www/html/.hydration_complete"

if [ -f "/var/www/html/index.php" ]; then
    echo "[Hydration] Skip: index.php exists."
    touch "$FLAG_FILE"
    exit 0
fi

echo "[Hydration] Starting background download..."
VERSION=${NEXTCLOUD_VERSION:-30.0.4}
curl -fsSL -o /tmp/nextcloud.tar.bz2 \
    "https://download.nextcloud.com/server/releases/nextcloud-${VERSION}.tar.bz2"

echo "[Hydration] Extracting Nextcloud..."
tar -xjf /tmp/nextcloud.tar.BZ2 --strip-components=1 -C /var/www/html/ || tar -xjf /tmp/nextcloud.tar.bz2 --strip-components=1 -C /var/www/html/
rm /tmp/nextcloud.tar.bz2

echo "[Hydration] Applying configuration overrides..."
mkdir -p /var/www/html/config
cp /tmp/overrides.config.php /var/www/html/config/overrides.config.php

chown -R www-data:www-data /var/www/html
touch "$FLAG_FILE"
echo "[Hydration] SUCCESS: Nextcloud is ready."

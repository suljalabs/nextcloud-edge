#!/bin/bash
set -e

echo "[Init] Starting Cloudflare Nextcloud Container..."

# 1. Credentials Check
if [ -z "$R2_ACCOUNT_ID" ] || [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
    echo "[Error] R2 configuration missing. Check Worker environment variables."
    exit 1
fi

# 2. Runtime Hydration (Download Nextcloud if missing)
# This reduces Docker image size for registry push by ~700MB
if [ ! -f "/var/www/html/index.php" ]; then
    echo "[Init] Nextcloud source missing. Hydrating from download.nextcloud.com..."
    VERSION=${NEXTCLOUD_VERSION:-30.0.4}
    curl -fsSL -o /tmp/nextcloud.tar.bz2 \
        "https://download.nextcloud.com/server/releases/nextcloud-${VERSION}.tar.bz2"
    
    echo "[Init] Extracting Nextcloud ${VERSION}..."
    tar -xjf /tmp/nextcloud.tar.bz2 --strip-components=1 -C /var/www/html/
    rm /tmp/nextcloud.tar.bz2
    
    echo "[Init] Applying configuration overrides..."
    mkdir -p /var/www/html/config
    cp /tmp/overrides.config.php /var/www/html/config/overrides.config.php
    
    chown -R www-data:www-data /var/www/html
    echo "[Init] Hydration complete."
else
    echo "[Init] Nextcloud source found. Skipping hydration."
fi

# 3. R2 FUSE Mounting via TigrisFS
R2_ENDPOINT="https://${R2_ACCOUNT_ID}.r2.cloudflarestorage.com"
MOUNT_POINT="/mnt/r2"

echo "[Init] Mounting R2 Bucket: $R2_BUCKET_NAME to $MOUNT_POINT"

# Start TigrisFS in the background
/usr/local/bin/tigrisfs \
    --endpoint "${R2_ENDPOINT}" \
    --bucket "${R2_BUCKET_NAME}" \
    --mount-point "${MOUNT_POINT}" \
    --permissions 0770 \
    --uid $(id -u www-data) \
    --gid $(id -g www-data) \
    --allow-other &

# 4. Mount Verification Loop
echo "[Init] Waiting for filesystem mount..."
TIMEOUT=0
MAX_WAIT=15
while [ $TIMEOUT -lt $MAX_WAIT ]; do
    sleep 1
    TIMEOUT=$((TIMEOUT+1))
    if ls "$MOUNT_POINT" > /dev/null 2>&1; then
        echo "[Init] Mount verified."
        break
    fi
done

if [ $TIMEOUT -eq $MAX_WAIT ]; then
    echo "[Error] FUSE mount timed out."
    exit 1
fi

# 5. Start Supervisor
echo "[Init] Starting Process Manager..."
exec /usr/bin/supervisord -c /etc/supervisord.conf

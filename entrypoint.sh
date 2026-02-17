#!/bin/bash
set -e

echo "[Init] Starting Cloudflare Nextcloud Container..."

# 1. Credentials Check
if [ -z "$R2_ACCOUNT_ID" ] || [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
    echo "[Error] R2 configuration missing. Check Worker environment variables."
    exit 1
fi

# 2. Start Background Services
echo "[Init] Triggering background hydration and mounting..."
/background-hydration.sh &

# R2 FUSE Mounting via TigrisFS
R2_ENDPOINT="https://${R2_ACCOUNT_ID}.r2.cloudflarestorage.com"
MOUNT_POINT="/mnt/r2"
/usr/local/bin/tigrisfs \
    --endpoint "${R2_ENDPOINT}" \
    --bucket "${R2_BUCKET_NAME}" \
    --mount-point "${MOUNT_POINT}" \
    --permissions 0770 \
    --uid $(id -u www-data) \
    --gid $(id -g www-data) \
    --allow-other &

# 3. Start Supervisor Immediately ( удовлетворить Cloudflare Health Check )
echo "[Init] Starting Process Manager..."
exec /usr/bin/supervisord -c /etc/supervisord.conf

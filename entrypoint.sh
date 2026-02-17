#!/bin/bash
# entrypoint.sh - Robust startup script for Cloudflare Containers
echo "[Init] Container boot started."

# 1. Credentials Check
if [ -z "$R2_ACCOUNT_ID" ] || [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
    echo "[Error] R2 configuration missing. Available keys: $(env | cut -d= -f1 | xargs)"
fi

# 2. Trigger Background Services
echo "[Init] Starting background hydration..."
/background-hydration.sh >/dev/stdout 2>&1 &

# R2 FUSE Mounting (Non-blocking)
echo "[Init] Starting R2 mount..."
R2_ENDPOINT="https://${R2_ACCOUNT_ID}.r2.cloudflarestorage.com"
/usr/local/bin/tigrisfs \
    --endpoint "${R2_ENDPOINT}" \
    --bucket "${R2_BUCKET_NAME}" \
    --mount-point "/mnt/r2" \
    --permissions 0770 \
    --uid 82 \
    --gid 82 \
    --allow-other >/dev/stdout 2>&1 &

# 3. Start Process Manager
echo "[Init] Starting Supervisor..."
# Use full path and explicit config location
exec /usr/bin/supervisord -n -c /etc/supervisord.conf

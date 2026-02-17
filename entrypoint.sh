#!/bin/bash
# entrypoint.sh - Robust non-blocking startup
echo "[Init] Container boot started."

# 1. Background Services Wrapper
(
    echo "[Init/Bg] Starting background orchestration..."
    
    # Hydration
    /background-hydration.sh >/dev/stdout 2>&1
    
    # R2 Mounting
    R2_ENDPOINT="https://${R2_ACCOUNT_ID}.r2.cloudflarestorage.com"
    echo "[Init/Bg] Mounting R2 via TigrisFS..."
    /usr/local/bin/tigrisfs \
        --endpoint "${R2_ENDPOINT}" \
        --bucket "${R2_BUCKET_NAME}" \
        --mount-point "/mnt/r2" \
        --permissions 0770 --uid 82 --gid 82 --allow-other >/dev/stdout 2>&1
) &

# 2. Port Watcher (Diagnostics)
(
    while true; do
        if ss -lnt | grep -q :8080; then
            echo "[Diagnostic] SUCCESS: Port 8080 is listening."
            break
        fi
        echo "[Diagnostic] Waiting for port 8080..."
        sleep 1
    done
) &

# 3. Start Process Manager (SUPERVISOR IS THE PARENT)
echo "[Init] Executing Supervisor..."
exec /usr/bin/supervisord -n -c /etc/supervisord.conf

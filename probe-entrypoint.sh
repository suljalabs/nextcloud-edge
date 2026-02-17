#!/bin/sh
# probe-entrypoint.sh - Minimal /bin/sh listener
echo "[Probe] Starting minimal /bin/sh listener on port 8080..."

mkdir -p /tmp/www
echo "<html><body><h1>Platform Reachable (sh)</h1><p>Health check satisfied.</p></body></html>" > /tmp/www/index.html

# Run httpd in the foreground
exec busybox httpd -f -p 8080 -h /tmp/www

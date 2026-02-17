#!/bin/bash
# probe-entrypoint.sh - Ultra-minimal listener to verify platform health check
echo "[Probe] Starting minimal listener on port 8080..."

# Use busybox httpd to serve a simple success message
# This should bind almost instantaneously.
mkdir -p /tmp/www
echo "<html><body><h1>Platform Reachable</h1><p>Health check satisfied.</p></body></html>" > /tmp/www/index.html

# Run httpd in the foreground to keep container alive
exec busybox httpd -f -p 8080 -h /tmp/www

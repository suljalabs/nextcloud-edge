# PLAN.md: Port 8080 Health Check Recovery

This plan outlines the systematic resolution of the "Port 8080 not listening" error in the Nextcloud Cloudflare Container.

## 1. Analysis & Hypotheses
The container fails the health check despite having Caddy configured for port 8080.
- **Hypothesis A**: Caddy fails to start due to Alpine binary/library issues or syntax errors in the `Caddyfile`.
- **Hypothesis B**: `supervisord` is blocked by the background hydration or FUSE mounting process.
- **Hypothesis C**: Cloudflare's IPv6-only environment (in some regions/tiers) is conflicting with a default IPv4 bind.

## 2. Phase 2: Implementation (Parallel)

### 🚀 [DevOps] Container Hardening
- **Explicit Binding**: Update Caddy and PHP-FPM to bind to `0.0.0.0` and `[::]` explicitly.
- **Entrypoint Logic**: Rearrange the entrypoint to ensure `supervisord` is the *very first* process that gains stability, moving all mounting/hydration to a separate supervised process or a more robust backgrounding method.
- **Health Check Probe**: Add a tiny `health.sh` script that runs in the background and logs port status to stdout.

### ⚙️ [Backend] Server Optimization
- **Caddy Simplication**: Strip the `Caddyfile` to a bare-bones response until the platform stabilizes.
- **PHP-FPM Tuning**: Ensure `www.conf` doesn't try to write to read-only paths (e.g., `/run/php-fpm.pid`).

### 🔍 [Debugger] Runtime Diagnostics
- **Diagnostic Deployment**: Pushing a "Probe" image that just runs `nc -l -p 8080` to verify platform network reachability.
- **Log Synthesis**: Using `wrangler tail` to capture the exact second the container fails.

## 3. Verification Plan
1. **Probe Pass**: Verify that the "Probe" image satisfies the health check.
2. **Minimal App Pass**: Deploy the simplified Caddy configuration.
3. **Full Hydration Pass**: Transition to the background hydration model.

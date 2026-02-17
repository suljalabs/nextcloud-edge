/**
 * Welcome to Cloudflare Workers! This is your entry point.
 *
 * - Run `npm run dev` in your terminal to start a development server
 * - Open a browser tab at http://localhost:8787/ to see your worker in action
 * - Run `npm run deploy` to publish your worker
 *
 * Learn more at https://developers.cloudflare.com/workers/
 */

// Polyfill for Performance API if missing (needed for some Container dependencies)
if (typeof globalThis.performance === 'undefined') {
    (globalThis as any).performance = {
        now: () => Date.now()
    };
}

import { Container, getContainer } from "@cloudflare/containers";

// Interface defining the environment bindings
interface Env {
    // Bindings
    DB_HYPERDRIVE: Hyperdrive;
    NEXTCLOUD_BUCKET: R2Bucket;
    NEXTCLOUD_CONTAINER: DurableObjectNamespace<NextcloudContainer>;
    AI: any; // Workers AI binding

    // Secrets (set via `wrangler secret put`)
    // R2 / S3
    AWS_ACCESS_KEY_ID: string;
    AWS_SECRET_ACCESS_KEY: string;
    // Database
    DB_PASSWORD: string;
    DB_NAME: string;
    DB_USER: string;
    // Redis (Upstash)
    REDIS_URL: string; // e.g., redis://default:token@host:port
    REDIS_HOST: string;
    REDIS_PORT: string;
    REDIS_PASSWORD: string;

    // Config Vars (from wrangler.toml vars)
    R2_ACCOUNT_ID: string;
    R2_BUCKET_NAME: string;
}

// Definition of the Nextcloud Container Class
export class NextcloudContainer extends Container<Env> {
    // Container Lifecycle Configuration
    defaultPort = 8080;
    // Sleep after 30 minutes of inactivity to save costs
    sleepAfter = "30m";

    // Injection of Environment Variables
    // These are available to the process running inside the container (e.g., entrypoint.sh)
    // Note: We map our Worker Env to the Container Env
    envVars = {
        // R2 Credentials
        AWS_ACCESS_KEY_ID: this.env.AWS_ACCESS_KEY_ID,
        AWS_SECRET_ACCESS_KEY: this.env.AWS_SECRET_ACCESS_KEY,
        R2_ACCOUNT_ID: this.env.R2_ACCOUNT_ID,
        R2_BUCKET_NAME: this.env.R2_BUCKET_NAME,

        // Database Connection String (Dynamic from Hyperdrive)
        // This string allows PHP to connect to the local Hyperdrive tunnel
        DATABASE_URL: this.env.DB_HYPERDRIVE.connectionString,
        DB_NAME: this.env.DB_NAME,
        DB_USER: this.env.DB_USER,
        DB_PASSWORD: this.env.DB_PASSWORD,
        DB_HOST: "hyperdrive.local", // Often handled by the shim, but good to set if needed by overrides

        // Redis Configuration
        REDIS_HOST: this.env.REDIS_HOST,
        REDIS_PORT: this.env.REDIS_PORT,
        REDIS_PASSWORD: this.env.REDIS_PASSWORD,

        // AI Configuration for Nextcloud Assistant
        CLOUDFLARE_API_TOKEN: this.env.AWS_SECRET_ACCESS_KEY, // Reusing token if permissions align
        CLOUDFLARE_ACCOUNT_ID: this.env.R2_ACCOUNT_ID
    };
}

export default {
    // HTTP Handler
    async fetch(request: Request, env: Env): Promise<Response> {
        const url = new URL(request.url);

        // 1. Tenant Logic
        const hostname = url.hostname;
        const parts = hostname.split('.');
        let tenantId = 'default';
        if (parts.length > 2) {
            tenantId = parts[0];
        }

        // 2. Container Retrieval
        if (!env.NEXTCLOUD_CONTAINER) {
            return new Response(`Error: NEXTCLOUD_CONTAINER binding is missing. Keys: ${Object.keys(env).join(",")}`, { status: 500 });
        }

        const container = getContainer(env.NEXTCLOUD_CONTAINER, tenantId);

        // 3. Request Forwarding
        return await container.fetch(request);
    },

    // Cron Handler
    async scheduled(event: ScheduledEvent, env: Env, ctx: ExecutionContext) {
        console.log("Cron Triggered");

        // Strategy: We need to trigger cron.php inside the containers.
        // For a multi-tenant system, we ideally iterate through active tenants.
        // Since we don't have a list of active tenants in this simple design,
        // we will demonstrate triggering a specific tenant or a set of known tenants.
        // In a real SaaS, you'd fetch active tenant IDs from a KV or D1 database.

        const tenantsToService = ['default']; // Placeholder for tenant list retrieval

        for (const tenantId of tenantsToService) {
            ctx.waitUntil((async () => {
                try {
                    const container = getContainer(env.NEXTCLOUD_CONTAINER, tenantId);
                    // Trigger cron.php via HTTP call to the container
                    // We construct a fake request to /cron.php
                    const response = await container.fetch(new Request("http://internal/cron.php"));
                    console.log(`Tenant ${tenantId} Cron: ${response.status}`);
                } catch (e) {
                    console.error(`Tenant ${tenantId} Cron Failed:`, e);
                }
            })());
        }
    }
};

# Infrastructure (`infra`)

This directory documents and contains infrastructure-as-code (IaC) configuration for the `static.re` architecture.

## Architecture Overview

```text
                                       ┌─────────────────────────┐
[Public Web Users / Consumers] ───────>│ my.static.re            │
                                       │ (Cloudflare R2 Bucket)  │
                                       └─────────────────────────┘
                                                    ▲
                                                    │ Direct Presigned PUT
                                                    │
                                       ┌─────────────────────────┐
[macOS Client / Admin Tools] ─────────>│ my-api.static.re        │
                                       │ (Cloudflare Worker API) │
                                       └─────────────────────────┘
```

## Cloudflare Resources

1. **R2 Bucket:**
   - Bucket Name: `my-static-re`
   - Custom Domain: `my.static.re` (Public Read delivery)

2. **Cloudflare Worker (`my-api-static-re`):**
   - Managed via `apps/api/wrangler.toml`
   - Custom Domain / Route: `my-api.static.re/*`
   - R2 Binding: `ASSETS_BUCKET -> my-static-re`

3. **Required Secrets (Worker):**
   Set via `pnpm --filter @my-static-re/api exec wrangler secret put <KEY>`:
   - `API_KEY`: Authentication secret for write endpoints.
   - `R2_ACCOUNT_ID`: Cloudflare Account ID for presigning.
   - `R2_ACCESS_KEY_ID`: Cloudflare R2 API token Access Key ID.
   - `R2_SECRET_ACCESS_KEY`: Cloudflare R2 API token Secret Access Key.

4. **DNS Zone (`static.re`):**
   - Managed in Cloudflare Dashboard or Terraform / Pulumi.
   - Custom Domain mappings for `my.static.re` (R2) and `my-api.static.re` (Worker) automatically configure necessary DNS records.

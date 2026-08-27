# my.static.re Monorepo

Monorepo for `my.static.re` asset delivery service, Cloudflare Worker ingestion API (`my-api.static.re`), and future macOS client application.

## Directory Structure

```text
/
├── package.json (pnpm workspace root)
├── pnpm-workspace.yaml
├── turbo.json
├── apps/
│   ├── api/                 # Cloudflare Worker API (my-api.static.re)
│   │   ├── src/
│   │   ├── package.json
│   │   ├── tsconfig.json
│   │   └── wrangler.toml    # Configured with R2 bucket bindings
│   └── macos/               # Placeholder for future macOS app
│       └── README.md        # Architecture intentions for Swift/Tauri
├── packages/
│   ├── shared-types/        # DTOs, API responses, schemas
│   │   ├── src/
│   │   ├── package.json
│   │   └── tsconfig.json
│   └── config/              # Shared TypeScript & Tooling configs
└── infra/                   # Infrastructure as Code documentation & specs
```

## Tech Stack

- **Package Manager:** `pnpm`
- **Monorepo Tool:** Turborepo (`turbo`)
- **API Backend:** Cloudflare Workers (TypeScript, Hono framework)
- **Object Storage:** Cloudflare R2 (`my-static-re-assets`)
- **Public CDN:** `my.static.re` (Direct R2 custom domain mapping)
- **API Domain:** `my-api.static.re` (Worker custom domain route)
- **Shared Code:** TypeScript (`@my-static-re/shared-types`, `@my-static-re/config`)

## Getting Started

### 1. Install Dependencies

```bash
pnpm install
```

### 2. Build All Packages

```bash
pnpm build
```

### 3. Typecheck

```bash
pnpm typecheck
```

### 4. Run API in Local Development Mode

```bash
cd apps/api
cp .dev.vars.example .dev.vars
# Edit .dev.vars with your credentials
pnpm dev
```

## API Endpoints

- `GET /health` - System health check & R2 connectivity status.
- `POST /upload/presign` - Generates an R2 S3-compatible presigned URL for direct asset upload. Requires `x-api-key` or `Authorization: Bearer <API_KEY>`.
- `GET /assets` - List assets in the R2 bucket. Requires authentication.
- `GET /assets/:key` - Retrieve metadata for a specific asset. Requires authentication.
- `DELETE /assets/:key` - Delete an asset from the R2 bucket. Requires authentication.

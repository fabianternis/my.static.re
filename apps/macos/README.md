# macOS Client (`apps/macos`)

This directory is designated for the future native macOS client application.

## 1. Architectural Scope & Technical Boundaries

The macOS client application is responsible for local asset management, clipboard integration, menu bar interactions, and background asset synchronization.

### Strict System Boundaries
1. **API & Ingestion (Private / State-Mutating):**
   - Interacts **exclusively** with the Cloudflare Worker API at `https://my-api.static.re`.
   - All mutations (`POST /upload/presign`, `DELETE /assets/:key`, metadata queries) must include authentication headers (`x-api-key: <KEY>` or `Authorization: Bearer <KEY>`).
   - The macOS client requests a presigned upload URL from `POST /upload/presign`, then performs a direct binary HTTP `PUT` to Cloudflare R2 via the signed URL.

2. **Asset Delivery (Public Read):**
   - Generates or copies public asset URLs pointing to the public CDN domain `https://my.static.re/<key>`.
   - Never routes public read requests through the management API.

3. **Shared Contracts (`packages/shared-types`):**
   - The client will consume the data structures defined in `@my-static-re/shared-types` (e.g., `PresignUploadRequest`, `PresignedUrlResponse`, `HealthResponse`, `ApiErrorResponse`).
   - In a Swift implementation, types can be generated via QuickType / CodeGen tooling or mapped into native `Codable` structs matching the TypeScript interfaces.
   - In a Tauri / Rust implementation, types can be shared via TS bindings or serde models.

## 2. Technology Stack Options

### Option A: Native Swift / SwiftUI (Recommended)
- **UI Framework:** SwiftUI + AppKit menu bar extra (`MenuBarExtra`).
- **Networking:** Native `URLSession` with background upload tasks.
- **Keychain Integration:** Store `API_KEY` securely in the macOS Keychain (`Security.framework`).
- **Drag-and-Drop & Clipboard:** `NSPasteboard` listener for automatic screenshot/file ingestion and direct URL copy.

### Option B: Tauri (Rust + Lightweight Web View)
- **Core:** Rust backend handling Keychain integration, file system watchers, and R2 upload streaming.
- **IPC:** Strongly typed IPC bridge consuming shared schemas.

## 3. Workflow Specification

```text
[User Drops File / Screenshot]
             │
             ▼
[macOS App] ──(1. POST /upload/presign with API_KEY)──> [my-api.static.re]
             │                                                 │
             │ <──(2. Returns Presigned R2 PUT URL)────────────┘
             │
             ▼
[macOS App] ──(3. Direct HTTP PUT Binary Data)────────> [Cloudflare R2 Bucket]
             │                                                 │
             │ <──(4. HTTP 200 OK)─────────────────────────────┘
             │
             ▼
[macOS App copies https://my.static.re/<key> to Clipboard & displays notification]
```

## 4. Environment Configuration
When implementing the client, the following configuration keys will be required:
- `API_BASE_URL`: `https://my-api.static.re`
- `PUBLIC_DELIVERY_URL`: `https://my.static.re`
- `API_KEY`: User-configured token stored in macOS Keychain.

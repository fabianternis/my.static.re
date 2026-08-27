export interface Env {
  // Cloudflare R2 Bindings
  ASSETS_BUCKET: R2Bucket;

  // Environment Secrets and Configuration
  API_KEY: string;
  R2_ACCOUNT_ID?: string;
  R2_ACCESS_KEY_ID?: string;
  R2_ACCESS_KEY?: string; // Fallback alias
  R2_SECRET_ACCESS_KEY?: string;
  R2_SECRET_KEY?: string; // Fallback alias
  R2_BUCKET_NAME?: string;
  PUBLIC_ASSET_BASE_URL?: string;
  ENVIRONMENT?: string;
}

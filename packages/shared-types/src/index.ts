/**
 * System Health Check Response
 */
export interface HealthResponse {
  status: "ok" | "degraded" | "error";
  timestamp: string;
  version: string;
  environment: string;
  services: {
    r2Bucket: "connected" | "disconnected" | "unknown";
  };
}

/**
 * Standard API Error Response Payload
 */
export interface ApiErrorResponse {
  success: false;
  error: {
    code: ApiErrorCode;
    message: string;
    details?: unknown;
  };
}

export type ApiErrorCode =
  | "UNAUTHORIZED"
  | "FORBIDDEN"
  | "BAD_REQUEST"
  | "NOT_FOUND"
  | "PRESIGN_FAILED"
  | "INTERNAL_SERVER_ERROR"
  | "RATE_LIMITED";

/**
 * Request payload to generate an R2 presigned upload URL
 */
export interface PresignUploadRequest {
  /**
   * The destination path/key in the bucket.
   * If omitted, a random UUID or timestamped key will be generated from fileName.
   */
  key?: string;

  /**
   * Original file name (e.g., "screenshot.png")
   */
  fileName: string;

  /**
   * Standard MIME content type (e.g., "image/png", "application/pdf")
   */
  contentType: string;

  /**
   * Expected file size in bytes (optional, for validation/content-length checks)
   */
  contentLength?: number;

  /**
   * Optional custom metadata key-value pairs to attach to the object
   */
  customMetadata?: Record<string, string>;

  /**
   * Presigned URL validity duration in seconds (default: 3600, max: 86400)
   */
  expiresInSeconds?: number;
}

/**
 * Response payload containing the presigned upload URL and public asset mapping
 */
export interface PresignedUrlResponse {
  success: true;
  data: {
    /**
     * The unique asset key/path within the bucket
     */
    key: string;

    /**
     * The presigned HTTP URL where the client performs the upload
     */
    uploadUrl: string;

    /**
     * HTTP method to use for the upload (typically "PUT")
     */
    method: "PUT" | "POST";

    /**
     * Required or recommended HTTP headers to include with the upload request
     */
    headers: Record<string, string>;

    /**
     * Public read URL on the delivery CDN (e.g. https://my.static.re/images/photo.png)
     */
    publicUrl: string;

    /**
     * Presigned URL expiration timestamp (ISO 8601 string)
     */
    expiresAt: string;

    /**
     * Presigned URL expiration duration in seconds
     */
    expiresInSeconds: number;
  };
}

/**
 * Asset Metadata Information
 */
export interface AssetMetadata {
  key: string;
  size: number;
  etag: string;
  contentType: string;
  uploadedAt: string;
  publicUrl: string;
  customMetadata?: Record<string, string>;
}

/**
 * Single Asset Details Response
 */
export interface AssetDetailsResponse {
  success: true;
  data: AssetMetadata;
}

/**
 * Asset Delete Response
 */
export interface AssetDeleteResponse {
  success: true;
  data: {
    key: string;
    deleted: boolean;
  };
}

/**
 * Asset List Request Query Options
 */
export interface AssetListQuery {
  prefix?: string;
  cursor?: string;
  limit?: number;
  delimiter?: string;
}

/**
 * Asset List Response
 */
export interface AssetListResponse {
  success: true;
  data: {
    objects: AssetMetadata[];
    truncated: boolean;
    cursor?: string;
  };
}

/**
 * Authentication Constants and Types
 */
export const AUTH_HEADER_API_KEY = "x-api-key" as const;
export const AUTH_HEADER_BEARER = "authorization" as const;

export interface AuthContext {
  authenticated: boolean;
  role?: "admin" | "uploader" | "service";
}

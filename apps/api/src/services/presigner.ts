import { S3Client, PutObjectCommand } from "@aws-sdk/client-s3";
import { getSignedUrl } from "@aws-sdk/s3-request-presigner";
import type { PresignedUrlResponse } from "@my-static-re/shared-types";
import type { Env } from "../env.js";

export interface GeneratePresignedUrlParams {
  key?: string;
  fileName: string;
  contentType: string;
  contentLength?: number;
  customMetadata?: Record<string, string>;
  expiresInSeconds?: number;
}

/**
 * Sanitizes a filename to create a safe R2 object key
 */
export function sanitizeFileName(fileName: string): string {
  // Remove leading slashes and unsafe characters
  const clean = fileName
    .trim()
    .replace(/^(\.\.[\/\\])+/, "")
    .replace(/[^a-zA-Z0-9._\-\/]/g, "_");
  return clean || "file.bin";
}

/**
 * Generates a storage key if one is not explicitly provided.
 * Format: YYYY/MM/DD/<uuid>-<sanitized-filename>
 */
export function generateObjectKey(fileName: string, explicitKey?: string): string {
  if (explicitKey && explicitKey.trim().length > 0) {
    return explicitKey.trim().replace(/^\/+/, "");
  }

  const date = new Date();
  const year = date.getUTCFullYear();
  const month = String(date.getUTCMonth() + 1).padStart(2, "0");
  const day = String(date.getUTCDate()).padStart(2, "0");
  const randomId = crypto.randomUUID().slice(0, 8);
  const cleanName = sanitizeFileName(fileName);

  return `${year}/${month}/${day}/${randomId}-${cleanName}`;
}

/**
 * Generates an R2 S3-compatible presigned URL for direct asset upload.
 */
export async function createPresignedUploadUrl(
  env: Env,
  params: GeneratePresignedUrlParams
): Promise<PresignedUrlResponse> {
  const accountId = env.R2_ACCOUNT_ID;
  const accessKeyId = env.R2_ACCESS_KEY_ID || env.R2_ACCESS_KEY;
  const secretAccessKey = env.R2_SECRET_ACCESS_KEY || env.R2_SECRET_KEY;
  const bucketName = env.R2_BUCKET_NAME || "my-static-re";
  const publicBaseUrl = (env.PUBLIC_ASSET_BASE_URL || "https://my.static.re").replace(/\/+$/, "");

  if (!accountId || !accessKeyId || !secretAccessKey) {
    throw new Error(
      "Missing R2 S3 credentials (R2_ACCOUNT_ID, R2_ACCESS_KEY_ID or R2_ACCESS_KEY, R2_SECRET_ACCESS_KEY). " +
      "Please configure these secrets in Cloudflare Dashboard."
    );
  }

  const key = generateObjectKey(params.fileName, params.key);
  const expiresIn = Math.min(Math.max(params.expiresInSeconds || 3600, 60), 86400);

  const s3Client = new S3Client({
    region: "auto",
    endpoint: `https://${accountId}.r2.cloudflarestorage.com`,
    credentials: {
      accessKeyId,
      secretAccessKey,
    },
  });

  const command = new PutObjectCommand({
    Bucket: bucketName,
    Key: key,
    ContentType: params.contentType,
    ContentLength: params.contentLength,
    Metadata: params.customMetadata,
  });

  const uploadUrl = await getSignedUrl(s3Client, command, {
    expiresIn,
  });

  const expiresAt = new Date(Date.now() + expiresIn * 1000).toISOString();
  const publicUrl = `${publicBaseUrl}/${key}`;

  const headers: Record<string, string> = {
    "Content-Type": params.contentType,
  };

  if (params.customMetadata) {
    for (const [metaKey, metaVal] of Object.entries(params.customMetadata)) {
      headers[`x-amz-meta-${metaKey.toLowerCase()}`] = metaVal;
    }
  }

  return {
    success: true,
    data: {
      key,
      uploadUrl,
      method: "PUT",
      headers,
      publicUrl,
      expiresAt,
      expiresInSeconds: expiresIn,
    },
  };
}

import { Hono } from "hono";
import type {
  ApiErrorResponse,
  AssetDetailsResponse,
  AssetDeleteResponse,
  AssetListResponse,
  AssetMetadata,
} from "@my-static-re/shared-types";
import type { Env } from "../env.js";
import { requireAuth } from "../middleware/auth.js";

export const assetsRouter = new Hono<{ Bindings: Env }>();

/**
 * List assets in the bucket (Authenticated)
 */
assetsRouter.get("/", requireAuth, async (c) => {
  const prefix = c.req.query("prefix");
  const cursor = c.req.query("cursor");
  const limitParam = c.req.query("limit");
  const limit = limitParam ? Math.min(Math.max(parseInt(limitParam, 10) || 20, 1), 100) : 20;

  try {
    const listResult = await c.env.ASSETS_BUCKET.list({
      prefix,
      cursor,
      limit,
    });

    const publicBaseUrl = (c.env.PUBLIC_ASSET_BASE_URL || "https://my.static.re").replace(/\/+$/, "");

    const objects: AssetMetadata[] = listResult.objects.map((obj) => ({
      key: obj.key,
      size: obj.size,
      etag: obj.etag,
      contentType: obj.httpMetadata?.contentType || "application/octet-stream",
      uploadedAt: obj.uploaded.toISOString(),
      publicUrl: `${publicBaseUrl}/${obj.key}`,
      customMetadata: obj.customMetadata,
    }));

    const response: AssetListResponse = {
      success: true,
      data: {
        objects,
        truncated: listResult.truncated,
        cursor: listResult.truncated ? listResult.cursor : undefined,
      },
    };

    return c.json(response, 200);
  } catch (err) {
    console.error("List assets error:", err);
    const errorResponse: ApiErrorResponse = {
      success: false,
      error: {
        code: "INTERNAL_SERVER_ERROR",
        message: "Failed to list bucket assets.",
      },
    };
    return c.json(errorResponse, 500);
  }
});

/**
 * Get single asset metadata (Authenticated)
 */
assetsRouter.get("/:key{.+}", requireAuth, async (c) => {
  const key = c.req.param("key");

  try {
    const object = await c.env.ASSETS_BUCKET.head(key);

    if (!object) {
      const errorResponse: ApiErrorResponse = {
        success: false,
        error: {
          code: "NOT_FOUND",
          message: `Asset '${key}' not found.`,
        },
      };
      return c.json(errorResponse, 404);
    }

    const publicBaseUrl = (c.env.PUBLIC_ASSET_BASE_URL || "https://my.static.re").replace(/\/+$/, "");

    const response: AssetDetailsResponse = {
      success: true,
      data: {
        key: object.key,
        size: object.size,
        etag: object.etag,
        contentType: object.httpMetadata?.contentType || "application/octet-stream",
        uploadedAt: object.uploaded.toISOString(),
        publicUrl: `${publicBaseUrl}/${object.key}`,
        customMetadata: object.customMetadata,
      },
    };

    return c.json(response, 200);
  } catch (err) {
    console.error("Get asset metadata error:", err);
    const errorResponse: ApiErrorResponse = {
      success: false,
      error: {
        code: "INTERNAL_SERVER_ERROR",
        message: "Failed to retrieve asset metadata.",
      },
    };
    return c.json(errorResponse, 500);
  }
});

/**
 * Delete asset from bucket (State-mutating: strictly Authenticated)
 */
assetsRouter.delete("/:key{.+}", requireAuth, async (c) => {
  const key = c.req.param("key");

  try {
    await c.env.ASSETS_BUCKET.delete(key);

    const response: AssetDeleteResponse = {
      success: true,
      data: {
        key,
        deleted: true,
      },
    };

    return c.json(response, 200);
  } catch (err) {
    console.error("Delete asset error:", err);
    const errorResponse: ApiErrorResponse = {
      success: false,
      error: {
        code: "INTERNAL_SERVER_ERROR",
        message: `Failed to delete asset '${key}'.`,
      },
    };
    return c.json(errorResponse, 500);
  }
});

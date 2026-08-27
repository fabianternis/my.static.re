import { Hono } from "hono";
import type { ApiErrorResponse, PresignUploadRequest } from "@my-static-re/shared-types";
import type { Env } from "../env.js";
import { requireAuth } from "../middleware/auth.js";
import { createPresignedUploadUrl } from "../services/presigner.js";

export const uploadRouter = new Hono<{ Bindings: Env }>();

// Enforce authentication on all upload routes
uploadRouter.use("*", requireAuth);

/**
 * Direct Worker Binary Upload (Uses native R2 binding)
 */
uploadRouter.put("/direct/:key{.+}", async (c) => {
  const rawKey = c.req.param("key");
  const key = decodeURIComponent(rawKey);
  const contentType = c.req.header("content-type") || "application/octet-stream";

  try {
    const body = await c.req.arrayBuffer();

    if (!c.env.ASSETS_BUCKET) {
      const errorResponse: ApiErrorResponse = {
        success: false,
        error: {
          code: "INTERNAL_SERVER_ERROR",
          message: "R2 bucket binding ASSETS_BUCKET is not connected.",
        },
      };
      return c.json(errorResponse, 500);
    }

    await c.env.ASSETS_BUCKET.put(key, body, {
      httpMetadata: {
        contentType,
      },
    });

    const publicBaseUrl = (c.env.PUBLIC_ASSET_BASE_URL || "https://my.static.re").replace(/\/+$/, "");

    return c.json(
      {
        success: true,
        data: {
          key,
          size: body.byteLength,
          contentType,
          publicUrl: `${publicBaseUrl}/${key}`,
        },
      },
      201
    );
  } catch (err) {
    console.error("Direct upload error:", err);
    const errorResponse: ApiErrorResponse = {
      success: false,
      error: {
        code: "INTERNAL_SERVER_ERROR",
        message: err instanceof Error ? err.message : "Direct upload failed.",
      },
    };
    return c.json(errorResponse, 500);
  }
});

/**
 * Request Presigned Upload URL
 */
uploadRouter.post("/presign", async (c) => {
  let body: Partial<PresignUploadRequest>;

  try {
    body = await c.req.json<PresignUploadRequest>();
  } catch {
    const errorResponse: ApiErrorResponse = {
      success: false,
      error: {
        code: "BAD_REQUEST",
        message: "Invalid JSON payload in request body.",
      },
    };
    return c.json(errorResponse, 400);
  }

  // Validate required fields
  if (!body.fileName || typeof body.fileName !== "string" || body.fileName.trim() === "") {
    const errorResponse: ApiErrorResponse = {
      success: false,
      error: {
        code: "BAD_REQUEST",
        message: "Missing or invalid 'fileName' field.",
      },
    };
    return c.json(errorResponse, 400);
  }

  if (!body.contentType || typeof body.contentType !== "string" || body.contentType.trim() === "") {
    const errorResponse: ApiErrorResponse = {
      success: false,
      error: {
        code: "BAD_REQUEST",
        message: "Missing or invalid 'contentType' field.",
      },
    };
    return c.json(errorResponse, 400);
  }

  try {
    const url = new URL(c.req.url);
    const apiBaseUrl = `${url.protocol}//${url.host}`;

    const response = await createPresignedUploadUrl(c.env, {
      fileName: body.fileName,
      contentType: body.contentType,
      key: body.key,
      contentLength: body.contentLength,
      customMetadata: body.customMetadata,
      expiresInSeconds: body.expiresInSeconds,
      apiBaseUrl,
    });

    return c.json(response, 201);
  } catch (err) {
    const errorMessage = err instanceof Error ? err.message : "Failed to generate presigned upload URL";
    console.error("Presign generation error:", err);

    const errorResponse: ApiErrorResponse = {
      success: false,
      error: {
        code: "PRESIGN_FAILED",
        message: errorMessage,
      },
    };
    return c.json(errorResponse, 500);
  }
});

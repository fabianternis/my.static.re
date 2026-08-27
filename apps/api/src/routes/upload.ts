import { Hono } from "hono";
import type { ApiErrorResponse, PresignUploadRequest } from "@my-static-re/shared-types";
import type { Env } from "../env.js";
import { requireAuth } from "../middleware/auth.js";
import { createPresignedUploadUrl } from "../services/presigner.js";

export const uploadRouter = new Hono<{ Bindings: Env }>();

// Enforce strict authentication on upload endpoints
uploadRouter.use("*", requireAuth);

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
    const response = await createPresignedUploadUrl(c.env, {
      fileName: body.fileName,
      contentType: body.contentType,
      key: body.key,
      contentLength: body.contentLength,
      customMetadata: body.customMetadata,
      expiresInSeconds: body.expiresInSeconds,
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

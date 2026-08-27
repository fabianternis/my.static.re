import type { MiddlewareHandler } from "hono";
import type { ApiErrorResponse } from "@my-static-re/shared-types";
import { AUTH_HEADER_API_KEY, AUTH_HEADER_BEARER } from "@my-static-re/shared-types";
import type { Env } from "../env.js";

/**
 * Strict authentication middleware.
 * Inspects `X-API-Key` header or `Authorization: Bearer <token>` header.
 * Compares with configured API_KEY in Worker environment.
 */
export const requireAuth: MiddlewareHandler<{ Bindings: Env }> = async (c, next) => {
  const configuredApiKey = c.env.API_KEY;

  if (!configuredApiKey) {
    const errorResponse: ApiErrorResponse = {
      success: false,
      error: {
        code: "INTERNAL_SERVER_ERROR",
        message: "API_KEY secret is not configured on this server.",
      },
    };
    return c.json(errorResponse, 500);
  }

  // Check X-API-Key header
  const apiKeyHeader = c.req.header(AUTH_HEADER_API_KEY);

  // Check Authorization Bearer header
  const authHeader = c.req.header(AUTH_HEADER_BEARER);
  let bearerToken: string | undefined;
  if (authHeader && authHeader.toLowerCase().startsWith("bearer ")) {
    bearerToken = authHeader.slice(7).trim();
  }

  const providedToken = apiKeyHeader || bearerToken;

  if (!providedToken) {
    const errorResponse: ApiErrorResponse = {
      success: false,
      error: {
        code: "UNAUTHORIZED",
        message: "Missing authentication credentials. Provide 'x-api-key' or 'Authorization: Bearer <token>' header.",
      },
    };
    return c.json(errorResponse, 401);
  }

  // Support multiple comma-separated keys if configured
  const validKeys = configuredApiKey.split(",").map((k) => k.trim());
  const isValid = validKeys.includes(providedToken);

  if (!isValid) {
    const errorResponse: ApiErrorResponse = {
      success: false,
      error: {
        code: "FORBIDDEN",
        message: "Invalid or unauthorized API key.",
      },
    };
    return c.json(errorResponse, 403);
  }

  return await next();
};

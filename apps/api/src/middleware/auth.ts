import type { MiddlewareHandler } from "hono";
import type { ApiErrorResponse } from "@my-static-re/shared-types";
import { AUTH_HEADER_API_KEY, AUTH_HEADER_BEARER } from "@my-static-re/shared-types";
import type { Env } from "../env.js";

/**
 * Authentication middleware.
 * Supports:
 * - Header: `x-api-key: <key>`
 * - Header: `Authorization: Bearer <key>`
 * - Query param: `?api_key=<key>` or `?key=<key>`
 */
export const requireAuth: MiddlewareHandler<{ Bindings: Env }> = async (c, next) => {
  const configuredApiKey = c.env.API_KEY;

  // 1. Check X-API-Key header
  const apiKeyHeader = c.req.header(AUTH_HEADER_API_KEY);

  // 2. Check Authorization Bearer header
  const authHeader = c.req.header(AUTH_HEADER_BEARER);
  let bearerToken: string | undefined;
  if (authHeader && authHeader.toLowerCase().startsWith("bearer ")) {
    bearerToken = authHeader.slice(7).trim();
  }

  // 3. Check Query parameter fallback (useful for browser viewing)
  const queryKey = c.req.query("api_key") || c.req.query("key");

  const providedToken = apiKeyHeader || bearerToken || queryKey;

  if (!providedToken) {
    const errorResponse: ApiErrorResponse = {
      success: false,
      error: {
        code: "UNAUTHORIZED",
        message: "Missing authentication credentials. Provide 'x-api-key' header, 'Authorization: Bearer <token>', or '?key=<key>' query param.",
      },
    };
    return c.json(errorResponse, 401);
  }

  if (!configuredApiKey) {
    const errorResponse: ApiErrorResponse = {
      success: false,
      error: {
        code: "INTERNAL_SERVER_ERROR",
        message: "API_KEY secret is not configured on this server. Please add API_KEY in Cloudflare Dashboard -> Variables and Secrets.",
      },
    };
    return c.json(errorResponse, 500);
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

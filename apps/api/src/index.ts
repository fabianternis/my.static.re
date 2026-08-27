import { Hono } from "hono";
import { cors } from "hono/cors";
import { logger } from "hono/logger";
import type { ApiErrorResponse } from "@my-static-re/shared-types";
import type { Env } from "./env.js";
import { healthRouter } from "./routes/health.js";
import { uploadRouter } from "./routes/upload.js";
import { assetsRouter } from "./routes/assets.js";

const app = new Hono<{ Bindings: Env }>();

// Global Middleware
app.use("*", logger());
app.use(
  "*",
  cors({
    origin: "*",
    allowMethods: ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allowHeaders: ["Content-Type", "Authorization", "x-api-key"],
    exposeHeaders: ["Content-Length"],
    maxAge: 86400,
  })
);

// Health check endpoint (Public status)
app.route("/health", healthRouter);

// Asset upload endpoints (Authenticated)
app.route("/upload", uploadRouter);

// Asset management endpoints (Authenticated)
app.route("/assets", assetsRouter);

// Root informational endpoint
app.get("/", (c) => {
  return c.json({
    service: "my-api-static-re",
    domain: "my-api.static.re",
    deliveryDomain: "my.static.re",
    endpoints: {
      health: "/health",
      presignUpload: "POST /upload/presign",
      assets: "GET /assets",
    },
  });
});

// 404 Not Found Handler
app.notFound((c) => {
  const errorResponse: ApiErrorResponse = {
    success: false,
    error: {
      code: "NOT_FOUND",
      message: `Path ${c.req.method} ${c.req.path} not found.`,
    },
  };
  return c.json(errorResponse, 404);
});

// Global Unhandled Error Handler
app.onError((err, c) => {
  console.error("Unhandled API Error:", err);
  const errorResponse: ApiErrorResponse = {
    success: false,
    error: {
      code: "INTERNAL_SERVER_ERROR",
      message: err.message || "An unexpected internal server error occurred.",
    },
  };
  return c.json(errorResponse, 500);
});

export default app;

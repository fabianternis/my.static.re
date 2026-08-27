import { Hono } from "hono";
import type { HealthResponse } from "@my-static-re/shared-types";
import type { Env } from "../env.js";

export const healthRouter = new Hono<{ Bindings: Env }>();

healthRouter.get("/", async (c) => {
  let r2Status: "connected" | "disconnected" | "unknown" = "unknown";

  try {
    if (c.env.ASSETS_BUCKET) {
      // Test R2 binding connectivity
      await c.env.ASSETS_BUCKET.list({ limit: 1 });
      r2Status = "connected";
    } else {
      r2Status = "disconnected";
    }
  } catch (err) {
    console.error("Health check R2 probe failed:", err);
    r2Status = "disconnected";
  }

  const response: HealthResponse & { envKeys?: string[] } = {
    status: r2Status === "connected" ? "ok" : "degraded",
    timestamp: new Date().toISOString(),
    version: "0.1.0",
    environment: c.env.ENVIRONMENT || "production",
    services: {
      r2Bucket: r2Status,
    },
    envKeys: Object.keys(c.env || {}),
  };

  return c.json(response, response.status === "ok" ? 200 : 503);
});

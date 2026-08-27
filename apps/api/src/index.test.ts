import { describe, it, expect, vi } from "vitest";
import app from "./index.js";
import type { Env } from "./env.js";
import { sanitizeFileName, generateObjectKey } from "./services/presigner.js";

const mockBucket: Partial<R2Bucket> = {
  list: vi.fn().mockResolvedValue({ objects: [], truncated: false }),
  head: vi.fn().mockResolvedValue(null),
  delete: vi.fn().mockResolvedValue(undefined),
};

const mockEnv: Env = {
  ASSETS_BUCKET: mockBucket as R2Bucket,
  API_KEY: "test-secret-key",
  R2_ACCOUNT_ID: "test-account-id",
  R2_ACCESS_KEY_ID: "test-access-key-id",
  R2_SECRET_ACCESS_KEY: "test-secret-access-key",
  R2_BUCKET_NAME: "my-static-re",
  PUBLIC_ASSET_BASE_URL: "https://my.static.re",
  ENVIRONMENT: "test",
};

describe("API Worker Tests", () => {
  describe("Utility Functions", () => {
    it("sanitizes file names properly", () => {
      expect(sanitizeFileName("../../../evil.png")).toBe("evil.png");
      expect(sanitizeFileName("my image #1 (final).png")).toBe("my_image__1__final_.png");
      expect(sanitizeFileName("document.pdf")).toBe("document.pdf");
    });

    it("generates structured object keys", () => {
      const explicit = generateObjectKey("photo.jpg", "custom/folder/photo.jpg");
      expect(explicit).toBe("custom/folder/photo.jpg");

      const generated = generateObjectKey("photo.jpg");
      const currentYear = new Date().getUTCFullYear().toString();
      expect(generated.startsWith(currentYear)).toBe(true);
      expect(generated.endsWith("photo.jpg")).toBe(true);
    });
  });

  describe("GET /health", () => {
    it("returns 200 OK with health status", async () => {
      const res = await app.fetch(new Request("http://localhost/health"), mockEnv);
      expect(res.status).toBe(200);

      const data = (await res.json()) as any;
      expect(data.status).toBe("ok");
      expect(data.services.r2Bucket).toBe("connected");
      expect(data.environment).toBe("test");
    });
  });

  describe("Authentication Middleware", () => {
    it("rejects unauthorized requests without API key", async () => {
      const res = await app.fetch(
        new Request("http://localhost/upload/presign", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ fileName: "test.png", contentType: "image/png" }),
        }),
        mockEnv
      );

      expect(res.status).toBe(401);
      const data = (await res.json()) as any;
      expect(data.success).toBe(false);
      expect(data.error.code).toBe("UNAUTHORIZED");
    });

    it("rejects requests with invalid API key", async () => {
      const res = await app.fetch(
        new Request("http://localhost/upload/presign", {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "x-api-key": "invalid-key",
          },
          body: JSON.stringify({ fileName: "test.png", contentType: "image/png" }),
        }),
        mockEnv
      );

      expect(res.status).toBe(403);
      const data = (await res.json()) as any;
      expect(data.success).toBe(false);
      expect(data.error.code).toBe("FORBIDDEN");
    });
  });

  describe("POST /upload/presign", () => {
    it("generates presigned upload response when authenticated", async () => {
      const res = await app.fetch(
        new Request("http://localhost/upload/presign", {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "x-api-key": "test-secret-key",
          },
          body: JSON.stringify({
            fileName: "screenshot.png",
            contentType: "image/png",
            key: "uploads/screenshot.png",
          }),
        }),
        mockEnv
      );

      expect(res.status).toBe(201);
      const data = (await res.json()) as any;
      expect(data.success).toBe(true);
      expect(data.data.key).toBe("uploads/screenshot.png");
      expect(data.data.method).toBe("PUT");
      expect(data.data.publicUrl).toBe("https://my.static.re/uploads/screenshot.png");
      expect(data.data.uploadUrl).toContain("test-account-id.r2.cloudflarestorage.com");
    });

    it("validates missing fileName and returns 400 Bad Request", async () => {
      const res = await app.fetch(
        new Request("http://localhost/upload/presign", {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Authorization: "Bearer test-secret-key",
          },
          body: JSON.stringify({
            contentType: "image/png",
          }),
        }),
        mockEnv
      );

      expect(res.status).toBe(400);
      const data = (await res.json()) as any;
      expect(data.success).toBe(false);
      expect(data.error.code).toBe("BAD_REQUEST");
    });
  });
});

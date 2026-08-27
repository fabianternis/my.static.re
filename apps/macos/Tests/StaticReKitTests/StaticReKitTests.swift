import Foundation
import Testing
@testable import StaticReKit

struct StaticReKitTests {
    @Test func testModelEncodingAndDecoding() throws {
        let presignResponse = PresignedUrlResponse(
            success: true,
            data: PresignedUrlData(
                key: "2026/08/27/test-image.png",
                uploadUrl: "https://account.r2.cloudflarestorage.com/upload",
                method: "PUT",
                headers: ["Content-Type": "image/png"],
                publicUrl: "https://my.static.re/2026/08/27/test-image.png",
                expiresAt: "2026-08-27T22:00:00Z",
                expiresInSeconds: 3600
            )
        )

        let data = try JSONEncoder().encode(presignResponse)
        let decoded = try JSONDecoder().decode(PresignedUrlResponse.self, from: data)

        #expect(decoded.success == true)
        #expect(decoded.data.key == "2026/08/27/test-image.png")
        #expect(decoded.data.publicUrl == "https://my.static.re/2026/08/27/test-image.png")
    }

    @Test func testMimeTypeDetection() {
        let client = StaticReClient(config: AppConfig())
        #expect(client.detectContentType(for: URL(fileURLWithPath: "test.png")) == "image/png")
        #expect(client.detectContentType(for: URL(fileURLWithPath: "document.pdf")) == "application/pdf")
        #expect(client.detectContentType(for: URL(fileURLWithPath: "clip.mp4")) == "video/mp4")
    }
}

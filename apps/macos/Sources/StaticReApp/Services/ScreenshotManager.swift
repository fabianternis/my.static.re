import Foundation
import AppKit

@MainActor
public final class ScreenshotManager {
    public static let shared = ScreenshotManager()

    private init() {}

    /**
     * In-Process Interactive Screen Capture:
     * Uses native CGWindowListCreateImage inside the app process (which holds the TCC Screen Recording grant),
     * avoiding macOS child-process permission blocks.
     */
    public func captureInteractiveScreenshot(onCaptured: @escaping @Sendable (URL) -> Void) {
        ScreenSelectionOverlay.shared.startInteractiveCapture { pngData in
            guard let data = pngData, !data.isEmpty else { return }

            let tempDir = FileManager.default.temporaryDirectory
            let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
            let destinationUrl = tempDir.appendingPathComponent("screenshot-\(timestamp).png")

            do {
                try data.write(to: destinationUrl)
                onCaptured(destinationUrl)
            } catch {
                print("Failed to save screenshot data: \(error)")
            }
        }
    }
}

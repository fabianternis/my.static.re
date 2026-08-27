import Foundation
import AppKit

@MainActor
public final class ScreenshotManager {
    public static let shared = ScreenshotManager()

    private init() {}

    /**
     * Interactive Screen Capture:
     * Captures screen contents using in-process ScreenCaptureKit with fallback,
     * crops user selection, and triggers upload.
     */
    public func captureInteractiveScreenshot(
        onCaptured: @escaping @Sendable (URL) -> Void,
        onPermissionNeeded: (@Sendable () -> Void)? = nil
    ) {
        ScreenSelectionOverlay.shared.startInteractiveCapture { pngData in
            guard let data = pngData, !data.isEmpty else {
                onPermissionNeeded?()
                return
            }

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

import Foundation
import AppKit
import CoreGraphics

@MainActor
public final class ScreenshotManager {
    public static let shared = ScreenshotManager()

    private init() {}

    /**
     * Checks if macOS has granted Screen Recording access to capture other applications' windows.
     * If not granted, triggers macOS system prompt.
     */
    public func checkAndRequestPermission() -> Bool {
        if #available(macOS 10.15, *) {
            if !CGPreflightScreenCaptureAccess() {
                // Triggers native macOS system permission dialog
                CGRequestScreenCaptureAccess()
                return false
            }
            return true
        }
        return true
    }

    /**
     * Interactive Screen Capture:
     * Validates TCC permission, triggers system prompt if needed,
     * and performs in-process capture of all visible windows.
     */
    public func captureInteractiveScreenshot(
        onCaptured: @escaping @Sendable (URL) -> Void,
        onPermissionNeeded: (@Sendable () -> Void)? = nil
    ) {
        if !checkAndRequestPermission() {
            onPermissionNeeded?()
            return
        }

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

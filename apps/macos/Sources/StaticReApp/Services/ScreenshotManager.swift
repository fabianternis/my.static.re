import Foundation
import AppKit

@MainActor
public final class ScreenshotManager {
    public static let shared = ScreenshotManager()

    private init() {}

    /**
     * Triggers native macOS interactive screen capture crosshair (-i).
     * Once user selects an area, saves to a temporary PNG file and triggers upload.
     */
    public func captureInteractiveScreenshot(onCaptured: @escaping @Sendable (URL) -> Void) {
        let tempDir = FileManager.default.temporaryDirectory
        let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let destinationUrl = tempDir.appendingPathComponent("screenshot-\(timestamp).png")

        // Hide app windows briefly so they don't block the screen capture if desired
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = ["-i", "-r", destinationUrl.path] // -i: interactive selection, -r: do not add shadow to windows

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try process.run()
                process.waitUntilExit()

                if process.terminationStatus == 0 && FileManager.default.fileExists(atPath: destinationUrl.path) {
                    DispatchQueue.main.async {
                        onCaptured(destinationUrl)
                    }
                }
            } catch {
                print("Failed to run screencapture: \(error)")
            }
        }
    }
}

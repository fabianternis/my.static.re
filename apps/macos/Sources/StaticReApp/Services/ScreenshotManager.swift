import Foundation
import AppKit

@MainActor
public final class ScreenshotManager {
    public static let shared = ScreenshotManager()

    private init() {}

    /**
     * Triggers native macOS interactive screen capture crosshair.
     * Captures directly to clipboard/file and uploads immediately.
     */
    public func captureInteractiveScreenshot(onCaptured: @escaping @Sendable (URL) -> Void) {
        let tempDir = FileManager.default.temporaryDirectory
        let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let destinationUrl = tempDir.appendingPathComponent("screenshot-\(timestamp).png")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        // -i: interactive selection
        // -o: in window capture mode, do not capture the window shadow
        // -x: do not play sounds (app handles sound)
        process.arguments = ["-i", "-o", "-x", destinationUrl.path]

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
                print("Failed to execute screencapture: \(error)")
            }
        }
    }
}

import Foundation
import SwiftUI
import AppKit
import StaticReKit

public enum AppTab: String, CaseIterable, Identifiable {
    case upload = "Upload"
    case library = "Assets"
    case settings = "Settings"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .upload: return "arrow.up.circle.fill"
        case .library: return "square.grid.2x2.fill"
        case .settings: return "gearshape.fill"
        }
    }
}

public struct ToastMessage: Identifiable, Equatable {
    public let id = UUID()
    public let title: String
    public let message: String
    public let isError: Bool
}

@MainActor
public final class AppViewModel: ObservableObject {
    @Published public var config: AppConfig
    @Published public var selectedTab: AppTab = .upload
    @Published public var isUploading: Bool = false
    @Published public var uploadProgressMessage: String = ""
    @Published public var recentUploads: [AssetMetadata] = []
    @Published public var searchQuery: String = ""
    @Published public var healthStatus: String = "Checking..."
    @Published public var healthDetails: String = ""
    @Published public var latencyMs: Int? = nil
    @Published public var activeToast: ToastMessage? = nil
    @Published public var lastUploadedAsset: AssetMetadata? = nil

    private var client: StaticReClient
    private let configManager: ConfigManager

    public init() {
        self.configManager = ConfigManager.shared
        let loadedConfig = configManager.loadConfig()
        self.config = loadedConfig
        self.client = StaticReClient(config: loadedConfig)

        // Setup local keyboard shortcut monitor for CMD+V
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            // Check for CMD+V (charactersIgnoringModifiers == "v" and modifierFlags contains .command)
            if event.modifierFlags.contains(.command),
               event.charactersIgnoringModifiers?.lowercased() == "v" {
                // If focus is not inside a standard editable text field, trigger clipboard upload
                if let firstResponder = NSApp.keyWindow?.firstResponder,
                   !(firstResponder is NSTextView || firstResponder is NSTextField) {
                    Task { @MainActor in
                        await self?.handlePasteCommand()
                    }
                    return nil // Handled
                }
            }
            return event
        }

        Task {
            await self.checkHealth()
            await self.fetchRecentUploads()
        }
    }

    public var filteredUploads: [AssetMetadata] {
        if searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return recentUploads
        }
        let query = searchQuery.lowercased()
        return recentUploads.filter {
            $0.key.lowercased().contains(query) ||
            $0.contentType.lowercased().contains(query)
        }
    }

    public func saveSettings() {
        do {
            try configManager.saveConfig(config)
            self.client = StaticReClient(config: self.config)
            showToast(title: "Settings Saved", message: "Configuration updated successfully.", isError: false)
            Task {
                await self.checkHealth()
                await self.fetchRecentUploads()
            }
        } catch {
            showToast(title: "Save Failed", message: error.localizedDescription, isError: true)
        }
    }

    public func checkHealth() async {
        self.healthStatus = "Testing..."
        let startTime = CFAbsoluteTimeGetCurrent()
        do {
            let health = try await client.checkHealth()
            let elapsed = Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000)
            self.latencyMs = elapsed
            self.healthStatus = "\(health.status.uppercased()) (\(elapsed)ms)"
            self.healthDetails = "Bucket: \(health.services.r2Bucket) | Env: \(health.environment) | v\(health.version)"
        } catch {
            self.latencyMs = nil
            self.healthStatus = "Unreachable"
            self.healthDetails = error.localizedDescription
        }
    }

    public func fetchRecentUploads() async {
        guard !config.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        do {
            let res = try await client.listAssets(limit: 50)
            self.recentUploads = res.data.objects
        } catch {
            print("Failed to fetch assets: \(error)")
        }
    }

    // MARK: - Clipboard Ingestion (CMD+V)

    public func handlePasteCommand() async {
        await uploadFromClipboard()
    }

    public func uploadFromClipboard() async {
        guard !config.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            showToast(title: "API Key Required", message: "Please enter your API Key in Settings to upload.", isError: true)
            self.selectedTab = .settings
            return
        }

        let pasteboard = NSPasteboard.general

        // 1. Check for File URLs copied in Finder
        if let fileUrls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
           let firstUrl = fileUrls.first, firstUrl.isFileURL {
            await uploadFile(url: firstUrl)
            return
        }

        // 2. Check for Image Data (Screenshots, copied graphics)
        if let images = pasteboard.readObjects(forClasses: [NSImage.self], options: nil) as? [NSImage],
           let image = images.first {
            guard let tiffData = image.tiffRepresentation,
                  let bitmapImage = NSBitmapImageRep(data: tiffData),
                  let pngData = bitmapImage.representation(using: .png, properties: [:]) else {
                showToast(title: "Image Error", message: "Failed to convert clipboard image to PNG format.", isError: true)
                return
            }

            let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
            let tempFile = FileManager.default.temporaryDirectory
                .appendingPathComponent("screenshot-\(timestamp).png")

            do {
                try pngData.write(to: tempFile)
                await uploadFile(url: tempFile)
                try? FileManager.default.removeItem(at: tempFile)
            } catch {
                showToast(title: "Upload Failed", message: error.localizedDescription, isError: true)
            }
            return
        }

        // 3. Check for plain text snippets
        if let string = pasteboard.string(forType: .string), !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
            let tempFile = FileManager.default.temporaryDirectory
                .appendingPathComponent("snippet-\(timestamp).txt")

            do {
                try string.write(to: tempFile, atomically: true, encoding: .utf8)
                await uploadFile(url: tempFile)
                try? FileManager.default.removeItem(at: tempFile)
            } catch {
                showToast(title: "Upload Failed", message: error.localizedDescription, isError: true)
            }
            return
        }

        showToast(title: "Empty Clipboard", message: "No image, file, or text found on clipboard to paste.", isError: true)
    }

    public func uploadFile(url: URL) async {
        guard !config.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            showToast(title: "API Key Required", message: "Please enter your API Key in Settings to upload.", isError: true)
            self.selectedTab = .settings
            return
        }

        isUploading = true
        uploadProgressMessage = "Uploading \(url.lastPathComponent)..."

        do {
            let response = try await client.uploadFile(at: url)
            let publicUrl = response.data.publicUrl

            // Copy to clipboard
            copyToClipboard(publicUrl)

            // Play nice feedback sound
            NSSound(named: "Glass")?.play()

            let asset = AssetMetadata(
                key: response.data.key,
                size: (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0,
                etag: "",
                contentType: client.detectContentType(for: url),
                uploadedAt: response.data.expiresAt,
                publicUrl: publicUrl
            )
            self.lastUploadedAsset = asset

            showToast(
                title: "Upload Complete! 📋",
                message: "Public link copied to clipboard:\n\(publicUrl)",
                isError: false
            )

            // Refresh recent list
            await fetchRecentUploads()
        } catch {
            NSSound(named: "Basso")?.play()
            showToast(title: "Upload Failed", message: error.localizedDescription, isError: true)
        }

        self.isUploading = false
        self.uploadProgressMessage = ""
    }

    public func deleteAsset(key: String) async {
        do {
            _ = try await client.deleteAsset(key: key)
            self.recentUploads.removeAll(where: { $0.key == key })
            if lastUploadedAsset?.key == key {
                lastUploadedAsset = nil
            }
            showToast(title: "Asset Deleted", message: "Removed \(key) from storage.", isError: false)
        } catch {
            showToast(title: "Delete Failed", message: error.localizedDescription, isError: true)
        }
    }

    public func copyToClipboard(_ text: String, formatName: String = "Link") {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        showToast(title: "Copied \(formatName)!", message: text, isError: false)
    }

    public func showToast(title: String, message: String, isError: Bool) {
        self.activeToast = ToastMessage(title: title, message: message, isError: isError)
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) { [weak self] in
            if self?.activeToast?.title == title {
                self?.activeToast = nil
            }
        }
    }
}

import Foundation
import SwiftUI
import AppKit
import StaticReKit

@MainActor
public final class AppViewModel: ObservableObject {
    @Published public var config: AppConfig
    @Published public var isUploading: Bool = false
    @Published public var uploadProgressMessage: String = ""
    @Published public var errorMessage: String?
    @Published public var recentUploads: [AssetMetadata] = []
    @Published public var healthStatus: String = "Checking..."
    @Published public var healthDetails: String = ""

    private var client: StaticReClient
    private let configManager: ConfigManager

    public init() {
        self.configManager = ConfigManager.shared
        let loadedConfig = configManager.loadConfig()
        self.config = loadedConfig
        self.client = StaticReClient(config: loadedConfig)

        Task {
            await self.checkHealth()
            await self.fetchRecentUploads()
        }
    }

    public func saveSettings() {
        do {
            try configManager.saveConfig(config)
            self.client = StaticReClient(config: self.config)
            self.errorMessage = nil
            Task {
                await self.checkHealth()
                await self.fetchRecentUploads()
            }
        } catch {
            self.errorMessage = "Failed to save settings: \(error.localizedDescription)"
        }
    }

    public func checkHealth() async {
        self.healthStatus = "Testing..."
        do {
            let health = try await client.checkHealth()
            self.healthStatus = "\(health.status.uppercased())"
            self.healthDetails = "R2: \(health.services.r2Bucket) | Env: \(health.environment) | v\(health.version)"
        } catch {
            self.healthStatus = "Unreachable"
            self.healthDetails = error.localizedDescription
        }
    }

    public func fetchRecentUploads() async {
        guard !config.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        do {
            let res = try await client.listAssets(limit: 20)
            self.recentUploads = res.data.objects
        } catch {
            print("Failed to fetch uploads: \(error)")
        }
    }

    public func uploadFile(url: URL) async {
        guard !config.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            self.errorMessage = "API Key is required. Please enter your API Key in Settings."
            return
        }

        isUploading = true
        uploadProgressMessage = "Uploading \(url.lastPathComponent)..."
        errorMessage = nil

        do {
            let response = try await client.uploadFile(at: url)
            let publicUrl = response.data.publicUrl

            copyToClipboard(publicUrl)
            uploadProgressMessage = "Uploaded! Link copied to clipboard."

            // Refresh recent list
            await fetchRecentUploads()
        } catch {
            self.errorMessage = error.localizedDescription
            self.uploadProgressMessage = ""
        }

        self.isUploading = false
    }

    public func uploadFromClipboard() async {
        guard !config.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            self.errorMessage = "API Key is required. Please enter your API Key in Settings."
            return
        }

        let pasteboard = NSPasteboard.general
        guard let images = pasteboard.readObjects(forClasses: [NSImage.self], options: nil) as? [NSImage],
              let image = images.first else {
            self.errorMessage = "No image found on your clipboard. Take a screenshot (⌘+Shift+Control+4) and try again."
            return
        }

        guard let tiffData = image.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapImage.representation(using: .png, properties: [:]) else {
            self.errorMessage = "Failed to convert clipboard image to PNG."
            return
        }

        let tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("screenshot-\(UUID().uuidString.prefix(8)).png")

        do {
            try pngData.write(to: tempFile)
            await uploadFile(url: tempFile)
            try? FileManager.default.removeItem(at: tempFile)
        } catch {
            self.errorMessage = "Failed to process screenshot: \(error.localizedDescription)"
        }
    }

    public func deleteAsset(key: String) async {
        do {
            _ = try await client.deleteAsset(key: key)
            self.recentUploads.removeAll(where: { $0.key == key })
        } catch {
            self.errorMessage = "Failed to delete asset: \(error.localizedDescription)"
        }
    }

    public func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}

import SwiftUI
import StaticReKit

struct ContentView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var showingSettings: Bool = false

    var body: some View {
        VStack(spacing: 16) {
            // Header Bar
            HStack(spacing: 10) {
                Image(systemName: "cloud.fill")
                    .foregroundColor(.accentColor)
                    .imageScale(.large)

                VStack(alignment: .leading, spacing: 2) {
                    Text("my.static.re")
                        .font(.headline)
                        .fontWeight(.bold)
                    Text(viewModel.config.apiBaseUrl)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Button(action: {
                    showingSettings = true
                }) {
                    Label("Settings", systemImage: "gearshape")
                }
                .controlSize(.small)
            }
            .padding(.horizontal, 4)

            // Drop zone for uploads
            DropZoneView(viewModel: viewModel)

            // Progress / Status notification
            if viewModel.isUploading {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text(viewModel.uploadProgressMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            } else if !viewModel.uploadProgressMessage.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(viewModel.uploadProgressMessage)
                        .font(.caption)
                        .foregroundColor(.green)
                }
                .padding(.vertical, 4)
            }

            // Error Banner
            if let error = viewModel.errorMessage {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer()
                    Button(action: {
                        viewModel.errorMessage = nil
                    }) {
                        Image(systemName: "xmark")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(10)
                .background(Color.red.opacity(0.12))
                .cornerRadius(8)
            }

            Divider()

            // Recent Uploads Section
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Recent Assets")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Spacer()

                    Button(action: {
                        Task {
                            await viewModel.fetchRecentUploads()
                        }
                    }) {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundColor(.accentColor)
                }

                if viewModel.recentUploads.isEmpty {
                    VStack(spacing: 6) {
                        Image(systemName: "tray")
                            .font(.title2)
                            .foregroundColor(.secondary.opacity(0.5))
                        Text(viewModel.config.apiKey.isEmpty ? "Configure your API Key in Settings to view uploaded assets." : "No uploaded assets found.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, minHeight: 120)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(viewModel.recentUploads) { asset in
                                AssetRowView(asset: asset, viewModel: viewModel)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .frame(maxHeight: 220)
                }
            }
        }
        .padding(20)
        .frame(minWidth: 400, maxWidth: .infinity)
        .sheet(isPresented: $showingSettings) {
            SettingsView(viewModel: viewModel)
        }
    }
}

struct AssetRowView: View {
    let asset: AssetMetadata
    @ObservedObject var viewModel: AppViewModel
    @State private var copied: Bool = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: iconForContentType(asset.contentType))
                .foregroundColor(.secondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(asset.key.components(separatedBy: "/").last ?? asset.key)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)

                Text("\(formatSize(asset.size)) • \(asset.key)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button(action: {
                viewModel.copyToClipboard(asset.publicUrl)
                copied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    copied = false
                }
            }) {
                HStack(spacing: 4) {
                    Image(systemName: copied ? "checkmark" : "link")
                    Text(copied ? "Copied" : "Copy")
                }
                .font(.caption2)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help("Copy Public URL to Clipboard")

            Button(action: {
                Task {
                    await viewModel.deleteAsset(key: asset.key)
                }
            }) {
                Image(systemName: "trash")
                    .foregroundColor(.red.opacity(0.8))
            }
            .buttonStyle(.plain)
            .help("Delete Asset from R2")
        }
        .padding(8)
        .background(Color.secondary.opacity(0.06))
        .cornerRadius(8)
    }

    private func iconForContentType(_ type: String) -> String {
        if type.contains("image") { return "photo" }
        if type.contains("video") { return "film" }
        if type.contains("pdf") { return "doc.richtext" }
        return "doc"
    }

    private func formatSize(_ bytes: Int64) -> String {
        let kb = Double(bytes) / 1024.0
        if kb > 1024 {
            return String(format: "%.1f MB", kb / 1024.0)
        }
        return String(format: "%.1f KB", kb)
    }
}

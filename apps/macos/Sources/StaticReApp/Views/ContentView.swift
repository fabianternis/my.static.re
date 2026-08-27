import SwiftUI
import StaticReKit

struct ContentView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var showingSettings: Bool = false

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Image(systemName: "cloud.fill")
                    .foregroundColor(.accentColor)
                    .imageScale(.large)

                Text("my.static.re")
                    .font(.headline)

                Spacer()

                Button(action: {
                    showingSettings = true
                }) {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(.plain)
                .help("Settings")

                Button(action: {
                    NSApplication.shared.terminate(nil)
                }) {
                    Image(systemName: "power")
                }
                .buttonStyle(.plain)
                .help("Quit Application")
            }
            .padding(.horizontal, 4)

            // Drop zone
            DropZoneView(viewModel: viewModel)

            // Upload Status / Progress
            if viewModel.isUploading {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text(viewModel.uploadProgressMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else if !viewModel.uploadProgressMessage.isEmpty {
                Text(viewModel.uploadProgressMessage)
                    .font(.caption)
                    .foregroundColor(.green)
            }

            // Error Banner
            if let error = viewModel.errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .lineLimit(2)
                }
                .padding(8)
                .background(Color.red.opacity(0.1))
                .cornerRadius(6)
            }

            Divider()

            // Recent Uploads List
            VStack(alignment: .leading, spacing: 8) {
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
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.plain)
                    .help("Refresh")
                }

                if viewModel.recentUploads.isEmpty {
                    Text("No recent uploads found.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 12)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(viewModel.recentUploads) { asset in
                                AssetRowView(asset: asset, viewModel: viewModel)
                            }
                        }
                    }
                    .frame(maxHeight: 180)
                }
            }
        }
        .padding(16)
        .frame(width: 360)
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
        HStack(spacing: 8) {
            Image(systemName: iconForContentType(asset.contentType))
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(asset.key.components(separatedBy: "/").last ?? asset.key)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)

                Text(formatSize(asset.size))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(action: {
                viewModel.copyToClipboard(asset.publicUrl)
                copied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    copied = false
                }
            }) {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
            }
            .buttonStyle(.borderless)
            .help("Copy Public URL")

            Button(action: {
                Task {
                    await viewModel.deleteAsset(key: asset.key)
                }
            }) {
                Image(systemName: "trash")
                    .foregroundColor(.red.opacity(0.8))
            }
            .buttonStyle(.borderless)
            .help("Delete Asset")
        }
        .padding(6)
        .background(Color.secondary.opacity(0.08))
        .cornerRadius(6)
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

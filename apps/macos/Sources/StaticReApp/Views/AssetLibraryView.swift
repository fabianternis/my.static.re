import SwiftUI
import StaticReKit

struct AssetLibraryView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        VStack(spacing: 14) {
            // Search & Refresh Toolbar
            HStack(spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search assets by name or type...", text: $viewModel.searchQuery)
                        .textFieldStyle(.plain)
                    if !viewModel.searchQuery.isEmpty {
                        Button(action: { viewModel.searchQuery = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Color.secondary.opacity(0.08))
                .cornerRadius(8)

                Button(action: {
                    Task {
                        await viewModel.fetchRecentUploads()
                    }
                }) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .help("Refresh Asset List")
            }

            // Results List
            if viewModel.filteredUploads.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: viewModel.searchQuery.isEmpty ? "tray" : "magnifyingglass")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary.opacity(0.4))
                    Text(viewModel.searchQuery.isEmpty ? "No assets in bucket yet." : "No assets match '\(viewModel.searchQuery)'.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    if viewModel.searchQuery.isEmpty {
                        Text("Upload files or paste images from clipboard to see them here.")
                            .font(.caption)
                            .foregroundColor(.secondary.opacity(0.8))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.vertical, 40)
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(viewModel.filteredUploads) { asset in
                            AssetCardView(asset: asset, viewModel: viewModel)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }
}

struct AssetCardView: View {
    let asset: AssetMetadata
    @ObservedObject var viewModel: AppViewModel
    @State private var isHovered: Bool = false
    @State private var showingDeleteConfirm: Bool = false

    var fileName: String {
        asset.key.components(separatedBy: "/").last ?? asset.key
    }

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(isHovered ? 0.14 : 0.08))
                    .frame(width: 40, height: 40)
                Image(systemName: iconForContentType(asset.contentType))
                    .font(.system(size: 18))
                    .foregroundColor(.accentColor)
            }

            // Details (Clickable area)
            VStack(alignment: .leading, spacing: 3) {
                Text(fileName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(formatSize(asset.size))
                    Text("•")
                    Text(asset.key)
                        .lineLimit(1)
                }
                .font(.caption2)
                .foregroundColor(.secondary)
            }

            Spacer()

            // Quick Actions
            HStack(spacing: 6) {
                Menu {
                    Button("Copy Direct URL") {
                        viewModel.copyToClipboard(asset.publicUrl, formatName: "URL")
                    }
                    Button("Copy Markdown Tag") {
                        let md = "![\(fileName)](\(asset.publicUrl))"
                        viewModel.copyToClipboard(md, formatName: "Markdown")
                    }
                    Button("Copy HTML Tag") {
                        let html = "<img src=\"\(asset.publicUrl)\" alt=\"\(fileName)\" />"
                        viewModel.copyToClipboard(html, formatName: "HTML")
                    }
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .menuStyle(.borderlessButton)
                .controlSize(.small)

                Button(action: {
                    openInBrowser()
                }) {
                    Image(systemName: "arrow.up.right.square")
                }
                .buttonStyle(.plain)
                .help("Open in Browser")

                Button(action: {
                    showingDeleteConfirm = true
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red.opacity(0.7))
                }
                .buttonStyle(.plain)
                .help("Delete Asset")
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isHovered ? Color.secondary.opacity(0.12) : Color.secondary.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(isHovered ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            openInBrowser()
        }
        .onTapGesture(count: 1) {
            viewModel.copyToClipboard(asset.publicUrl, formatName: "Link")
        }
        .onHover { hovering in
            isHovered = hovering
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
        .contextMenu {
            Button("Copy Direct URL") {
                viewModel.copyToClipboard(asset.publicUrl, formatName: "URL")
            }
            Button("Copy Markdown") {
                let md = "![\(fileName)](\(asset.publicUrl))"
                viewModel.copyToClipboard(md, formatName: "Markdown")
            }
            Button("Copy HTML Tag") {
                let html = "<img src=\"\(asset.publicUrl)\" alt=\"\(fileName)\" />"
                viewModel.copyToClipboard(html, formatName: "HTML")
            }
            Divider()
            Button("Open in Browser") {
                openInBrowser()
            }
            Divider()
            Button("Delete Asset", role: .destructive) {
                showingDeleteConfirm = true
            }
        }
        .confirmationDialog("Delete Asset", isPresented: $showingDeleteConfirm) {
            Button("Delete \(fileName)", role: .destructive) {
                Task {
                    await viewModel.deleteAsset(key: asset.key)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to permanently delete '\(asset.key)' from your Cloudflare R2 bucket?")
        }
    }

    private func openInBrowser() {
        if let url = URL(string: asset.publicUrl) {
            NSWorkspace.shared.open(url)
        }
    }

    private func iconForContentType(_ type: String) -> String {
        let t = type.lowercased()
        if t.contains("image") || t.contains("png") || t.contains("jpeg") || t.contains("jpg") || t.contains("webp") {
            return "photo.fill"
        }
        if t.contains("video") || t.contains("mp4") || t.contains("mov") {
            return "film.fill"
        }
        if t.contains("pdf") {
            return "doc.richtext.fill"
        }
        if t.contains("json") || t.contains("javascript") || t.contains("typescript") {
            return "chevron.left.forwardslash.chevron.right"
        }
        return "doc.fill"
    }

    private func formatSize(_ bytes: Int64) -> String {
        let kb = Double(bytes) / 1024.0
        if kb > 1024 {
            return String(format: "%.1f MB", kb / 1024.0)
        }
        return String(format: "%.1f KB", kb)
    }
}

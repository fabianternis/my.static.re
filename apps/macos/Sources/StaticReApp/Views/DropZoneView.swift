import SwiftUI
import UniformTypeIdentifiers
import StaticReKit

struct DropZoneView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var isTargeted: Bool = false

    var body: some View {
        VStack(spacing: 20) {
            // Drop & Paste Container
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(isTargeted ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.08))
                        .frame(width: 72, height: 72)
                        .scaleEffect(isTargeted ? 1.1 : 1.0)
                        .animation(.spring(response: 0.35, dampingFraction: 0.6), value: isTargeted)

                    Image(systemName: isTargeted ? "arrow.down.doc.fill" : "cloud.and.arrow.up.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 36, height: 36)
                        .foregroundColor(isTargeted ? .accentColor : .secondary)
                }

                VStack(spacing: 6) {
                    Text(isTargeted ? "Release to Upload File" : "Drag & Drop Files Here")
                        .font(.title3)
                        .fontWeight(.bold)

                    HStack(spacing: 4) {
                        Text("or press")
                            .foregroundColor(.secondary)
                        Text("⌘V")
                            .font(.system(.caption, design: .monospaced))
                            .fontWeight(.bold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.15))
                            .cornerRadius(5)
                        Text("anywhere to paste screenshot/file")
                            .foregroundColor(.secondary)
                    }
                    .font(.caption)
                }

                // Action Buttons
                HStack(spacing: 10) {
                    Button(action: {
                        Task {
                            await viewModel.uploadFromClipboard()
                        }
                    }) {
                        Label("Paste (⌘V)", systemImage: "doc.on.clipboard.fill")
                            .fontWeight(.medium)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                    .keyboardShortcut("v", modifiers: .command)

                    Button(action: {
                        ScreenshotManager.shared.captureInteractiveScreenshot(
                            onCaptured: { tempUrl in
                                Task { @MainActor in
                                    await viewModel.uploadFile(url: tempUrl)
                                    try? FileManager.default.removeItem(at: tempUrl)
                                }
                            },
                            onPermissionNeeded: {
                                Task { @MainActor in
                                    viewModel.showToast(
                                        title: "Screen Recording Permission",
                                        message: "Please ensure StaticRe is enabled in System Settings > Privacy & Security > Screen Recording.",
                                        isError: true
                                    )
                                }
                            }
                        )
                    }) {
                        Label("Screenshot", systemImage: "camera.fill")
                            .fontWeight(.medium)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                    .keyboardShortcut("s", modifiers: [.command, .shift])

                    Button(action: {
                        selectAndUploadFile()
                    }) {
                        Label("Browse", systemImage: "folder.badge.plus")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                }
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
            .padding(.horizontal, 20)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        isTargeted ? Color.accentColor : Color.secondary.opacity(0.2),
                        style: StrokeStyle(lineWidth: 2, dash: isTargeted ? [] : [8, 6])
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(isTargeted ? Color.accentColor.opacity(0.04) : Color.secondary.opacity(0.02))
                    )
            )
            .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
                guard let provider = providers.first else { return false }
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    guard let url = url else { return }
                    Task { @MainActor in
                        await viewModel.uploadFile(url: url)
                    }
                }
                return true
            }

            // Upload in progress bar
            if viewModel.isUploading {
                HStack(spacing: 12) {
                    ProgressView()
                        .controlSize(.small)
                    Text(viewModel.uploadProgressMessage)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(Color.accentColor.opacity(0.08))
                .cornerRadius(10)
            }

            // Last Uploaded Asset Card
            if let asset = viewModel.lastUploadedAsset {
                LastUploadCardView(asset: asset, viewModel: viewModel)
            }
        }
    }

    private func selectAndUploadFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.prompt = "Upload"

        if panel.runModal() == .OK, let url = panel.url {
            Task {
                await viewModel.uploadFile(url: url)
            }
        }
    }
}

struct LastUploadCardView: View {
    let asset: AssetMetadata
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("Latest Upload")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                Spacer()
                Text(asset.key)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            HStack(spacing: 8) {
                Button(action: {
                    viewModel.copyToClipboard(asset.publicUrl, formatName: "Raw Link")
                }) {
                    Label("Copy Link", systemImage: "link")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                Button(action: {
                    let markdown = "![\(asset.key)](\(asset.publicUrl))"
                    viewModel.copyToClipboard(markdown, formatName: "Markdown")
                }) {
                    Label("Markdown", systemImage: "text.quote")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button(action: {
                    let html = "<img src=\"\(asset.publicUrl)\" alt=\"\(asset.key)\" />"
                    viewModel.copyToClipboard(html, formatName: "HTML Tag")
                }) {
                    Label("HTML", systemImage: "chevron.left.forwardslash.chevron.right")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Spacer()

                Button(action: {
                    if let url = URL(string: asset.publicUrl) {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    Image(systemName: "arrow.up.right.square")
                }
                .buttonStyle(.plain)
                .help("Open in Browser")
            }
        }
        .padding(14)
        .background(Color.secondary.opacity(0.06))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.secondary.opacity(0.12), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            if let url = URL(string: asset.publicUrl) {
                NSWorkspace.shared.open(url)
            }
        }
        .onTapGesture(count: 1) {
            viewModel.copyToClipboard(asset.publicUrl, formatName: "Link")
        }
        .onHover { hovering in
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
        .contextMenu {
            Button("Copy Direct Link") {
                viewModel.copyToClipboard(asset.publicUrl, formatName: "Link")
            }
            Button("Copy Markdown") {
                let md = "![\(asset.key)](\(asset.publicUrl))"
                viewModel.copyToClipboard(md, formatName: "Markdown")
            }
            Button("Copy HTML Tag") {
                let html = "<img src=\"\(asset.publicUrl)\" alt=\"\(asset.key)\" />"
                viewModel.copyToClipboard(html, formatName: "HTML")
            }
            Divider()
            Button("Open in Browser") {
                if let url = URL(string: asset.publicUrl) {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }
}

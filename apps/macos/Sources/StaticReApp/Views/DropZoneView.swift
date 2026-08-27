import SwiftUI
import UniformTypeIdentifiers

struct DropZoneView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var isTargeted: Bool = false

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: isTargeted ? "arrow.down.doc.fill" : "arrow.up.doc")
                .resizable()
                .scaledToFit()
                .frame(width: 32, height: 32)
                .foregroundColor(isTargeted ? .accentColor : .secondary)

            Text(isTargeted ? "Drop file to upload" : "Drag & drop files here")
                .font(.headline)

            Text("or paste screenshot from clipboard")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(spacing: 8) {
                Button(action: {
                    selectAndUploadFile()
                }) {
                    Label("Choose File", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                Button(action: {
                    Task {
                        await viewModel.uploadFromClipboard()
                    }
                }) {
                    Label("Paste Image", systemImage: "doc.on.clipboard")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(isTargeted ? Color.accentColor : Color.secondary.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [6]))
                .background(isTargeted ? Color.accentColor.opacity(0.05) : Color.clear)
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
    }

    private func selectAndUploadFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        if panel.runModal() == .OK, let url = panel.url {
            Task {
                await viewModel.uploadFile(url: url)
            }
        }
    }
}

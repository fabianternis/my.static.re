import SwiftUI
import StaticReKit

struct SettingsView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var showKey: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Authentication Section
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Authentication", systemImage: "key.fill")
                            .font(.headline)
                            .foregroundColor(.primary)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("API Secret Key:")
                                .font(.caption)
                                .fontWeight(.semibold)

                            HStack {
                                if showKey {
                                    TextField("Enter API Secret Key", text: $viewModel.config.apiKey)
                                        .textFieldStyle(.roundedBorder)
                                } else {
                                    SecureField("Enter API Secret Key", text: $viewModel.config.apiKey)
                                        .textFieldStyle(.roundedBorder)
                                }

                                Button(action: { showKey.toggle() }) {
                                    Image(systemName: showKey ? "eye.slash" : "eye")
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                                .help(showKey ? "Hide Key" : "Show Key")
                            }

                            Text("Must match the API_KEY configured on your Cloudflare Worker.")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(10)
                }

                // Endpoints Section
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Label("Endpoints", systemImage: "network")
                                .font(.headline)
                            Spacer()
                            // Quick Presets
                            Button("Use Localhost") {
                                viewModel.config.apiBaseUrl = "http://127.0.0.1:8787"
                            }
                            .buttonStyle(.borderless)
                            .font(.caption2)

                            Button("Use Production") {
                                viewModel.config.apiBaseUrl = "https://my-api.static.re"
                                viewModel.config.publicBaseUrl = "https://my.static.re"
                            }
                            .buttonStyle(.borderless)
                            .font(.caption2)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("API Base URL (Ingestion & Metadata):")
                                .font(.caption)
                                .fontWeight(.semibold)

                            TextField("https://my-api.static.re", text: $viewModel.config.apiBaseUrl)
                                .textFieldStyle(.roundedBorder)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Public CDN Base URL (Public Read):")
                                .font(.caption)
                                .fontWeight(.semibold)

                            TextField("https://my.static.re", text: $viewModel.config.publicBaseUrl)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                    .padding(10)
                }

                // Diagnostics & Status
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Service Diagnostics", systemImage: "waveform.path.ecg")
                            .font(.headline)

                        HStack {
                            Text("Connection Status:")
                                .font(.subheadline)
                            Spacer()
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(statusColor)
                                    .frame(width: 8, height: 8)
                                Text(viewModel.healthStatus)
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundColor(statusColor)
                            }
                        }

                        if !viewModel.healthDetails.isEmpty {
                            Text(viewModel.healthDetails)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }

                        Button(action: {
                            Task {
                                viewModel.saveSettings()
                                await viewModel.checkHealth()
                            }
                        }) {
                            Label("Test Connection Now", systemImage: "arrow.triangle.2.circlepath")
                        }
                        .controlSize(.small)
                    }
                    .padding(10)
                }

                // Save Action
                HStack {
                    Spacer()
                    Button(action: {
                        viewModel.saveSettings()
                    }) {
                        Label("Save & Apply Settings", systemImage: "checkmark")
                            .fontWeight(.medium)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                }
            }
            .padding(16)
        }
    }

    private var statusColor: Color {
        if viewModel.healthStatus.contains("OK") {
            return .green
        }
        if viewModel.healthStatus.contains("Testing") || viewModel.healthStatus.contains("Checking") {
            return .orange
        }
        return .red
    }
}

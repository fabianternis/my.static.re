import SwiftUI
import StaticReKit

struct SettingsView: View {
    @ObservedObject var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Settings")
                .font(.title2)
                .fontWeight(.bold)

            GroupBox("API Authentication") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("API Key:")
                        .font(.caption)
                        .fontWeight(.semibold)

                    SecureField("Enter API Key (secret)", text: $viewModel.config.apiKey)
                        .textFieldStyle(.roundedBorder)

                    Text("This key must match the API_KEY secret configured in your Cloudflare Worker.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(8)
            }

            GroupBox("Endpoints") {
                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("API Base URL (Ingestion & Metadata):")
                            .font(.caption)
                            .fontWeight(.semibold)

                        TextField("https://my-api.static.re", text: $viewModel.config.apiBaseUrl)
                            .textFieldStyle(.roundedBorder)

                        Text("Use http://127.0.0.1:8787 for local dev worker.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Public Delivery Base URL (CDN Read):")
                            .font(.caption)
                            .fontWeight(.semibold)

                        TextField("https://my.static.re", text: $viewModel.config.publicBaseUrl)
                            .textFieldStyle(.roundedBorder)
                    }
                }
                .padding(8)
            }

            GroupBox("Connection Diagnostics") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("API Status:")
                            .font(.caption)
                            .fontWeight(.semibold)
                        Spacer()
                        Text(viewModel.healthStatus)
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(viewModel.healthStatus.contains("OK") ? .green : (viewModel.healthStatus.contains("Testing") ? .orange : .red))
                    }

                    if !viewModel.healthDetails.isEmpty {
                        Text(viewModel.healthDetails)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    Button("Test Connection Now") {
                        Task {
                            viewModel.saveSettings()
                            await viewModel.checkHealth()
                        }
                    }
                    .controlSize(.small)
                }
                .padding(8)
            }

            HStack {
                Button("Close") {
                    dismiss()
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Save & Apply") {
                    viewModel.saveSettings()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.top, 8)
        }
        .padding(24)
        .frame(width: 440)
    }
}

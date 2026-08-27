import SwiftUI
import StaticReKit

struct SettingsView: View {
    @ObservedObject var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section("API Credentials") {
                SecureField("API Key", text: $viewModel.config.apiKey)
                    .textFieldStyle(.roundedBorder)

                Text("Obtain your API Key from Cloudflare Worker secrets or system administrator.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Endpoint Configuration") {
                TextField("API Base URL", text: $viewModel.config.apiBaseUrl)
                    .textFieldStyle(.roundedBorder)

                TextField("Public Base URL", text: $viewModel.config.publicBaseUrl)
                    .textFieldStyle(.roundedBorder)
            }

            Section("Connection Status") {
                HStack {
                    Text("API Status:")
                    Spacer()
                    Text(viewModel.healthStatus)
                        .foregroundColor(viewModel.healthStatus.contains("OK") ? .green : .red)
                        .fontWeight(.semibold)
                }

                Button("Test Connection") {
                    Task {
                        await viewModel.checkHealth()
                    }
                }
                .controlSize(.small)
            }

            HStack {
                Spacer()
                Button("Save Settings") {
                    viewModel.saveSettings()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.top, 8)
        }
        .padding(20)
        .frame(width: 420)
    }
}

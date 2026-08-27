import SwiftUI
import StaticReKit

struct ContentView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                // Top Header & Tab Navigation Bar
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        Image(systemName: "cloud.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.accentColor)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("my.static.re")
                                .font(.headline)
                                .fontWeight(.bold)
                            Text("Asset Ingestion Service")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        // Health Indicator Badge
                        HStack(spacing: 5) {
                            Circle()
                                .fill(healthColor)
                                .frame(width: 7, height: 7)
                            Text(viewModel.healthStatus.contains("OK") ? (viewModel.latencyMs != nil ? "\(viewModel.latencyMs!)ms" : "Online") : "Offline")
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.08))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)

                    // Segmented Tab Picker
                    Picker("Navigation", selection: $viewModel.selectedTab) {
                        ForEach(AppTab.allCases) { tab in
                            Label(tab.rawValue, systemImage: tab.icon).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)

                    Divider()
                }
                .background(.ultraThinMaterial)

                // Main Tab Content
                VStack {
                    switch viewModel.selectedTab {
                    case .upload:
                        DropZoneView(viewModel: viewModel)
                            .padding(16)
                    case .library:
                        AssetLibraryView(viewModel: viewModel)
                            .padding(16)
                    case .settings:
                        SettingsView(viewModel: viewModel)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            // Floating Toast Notification Overlay
            if let toast = viewModel.activeToast {
                ToastView(toast: toast) {
                    withAnimation {
                        viewModel.activeToast = nil
                    }
                }
                .padding(.top, 80)
            }
        }
        .frame(minWidth: 440, idealWidth: 480, minHeight: 520, idealHeight: 580)
    }

    private var healthColor: Color {
        if viewModel.healthStatus.contains("OK") { return .green }
        if viewModel.healthStatus.contains("Testing") || viewModel.healthStatus.contains("Checking") { return .orange }
        return .red
    }
}

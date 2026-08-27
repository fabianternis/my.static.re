import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    var viewModel: AppViewModel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        if let vm = viewModel {
            StatusBarManager.shared.setup(viewModel: vm)
        }
    }
}

@main
struct StaticReApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var viewModel = AppViewModel()

    init() {
        // Wire view model to app delegate for status bar integration
    }

    var body: some Scene {
        WindowGroup("my.static.re - Ingestion & Delivery", id: "main-window") {
            ContentView(viewModel: viewModel)
                .frame(minWidth: 440, minHeight: 560)
                .onAppear {
                    appDelegate.viewModel = viewModel
                    StatusBarManager.shared.setup(viewModel: viewModel)
                }
        }
        .windowResizability(.contentSize)
    }
}

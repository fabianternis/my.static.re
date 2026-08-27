import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}

@main
struct StaticReApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var viewModel = AppViewModel()

    var body: some Scene {
        WindowGroup("my.static.re - Asset Ingestion", id: "main-window") {
            ContentView(viewModel: viewModel)
                .frame(minWidth: 420, minHeight: 560)
        }
        .windowResizability(.contentSize)

        MenuBarExtra("my.static.re", systemImage: "cloud.fill") {
            ContentView(viewModel: viewModel)
                .frame(width: 380)
        }
        .menuBarExtraStyle(.window)
    }
}

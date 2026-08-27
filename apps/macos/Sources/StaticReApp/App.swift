import SwiftUI
import AppKit

@main
struct StaticReApp: App {
    @StateObject private var viewModel = AppViewModel()

    var body: some Scene {
        MenuBarExtra("my.static.re", systemImage: "cloud.fill") {
            ContentView(viewModel: viewModel)
        }
        .menuBarExtraStyle(.window)

        Window("my.static.re Assets", id: "main-window") {
            ContentView(viewModel: viewModel)
                .frame(minWidth: 400, minHeight: 520)
        }
        .windowResizability(.contentSize)
    }
}

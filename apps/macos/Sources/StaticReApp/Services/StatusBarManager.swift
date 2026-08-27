import Foundation
import AppKit
import SwiftUI

@MainActor
public final class StatusBarManager: NSObject {
    public static let shared = StatusBarManager()

    private var statusItem: NSStatusItem?
    private var dropView: StatusItemDropView?
    private weak var viewModel: AppViewModel?

    public func setup(viewModel: AppViewModel) {
        self.viewModel = viewModel

        guard statusItem == nil else { return }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        self.statusItem = item

        let view = StatusItemDropView(frame: NSRect(x: 0, y: 0, width: 24, height: 24))
        view.onDrop = { [weak self] url in
            Task { @MainActor in
                await self?.viewModel?.uploadFile(url: url)
            }
        }
        view.onClick = { [weak self] in
            self?.showStatusMenu()
        }

        item.button?.addSubview(view)
        view.frame = item.button?.bounds ?? NSRect(x: 0, y: 0, width: 24, height: 24)
        view.autoresizingMask = [.width, .height]
        self.dropView = view
    }

    public func showStatusMenu() {
        guard let item = statusItem, let button = item.button, let vm = viewModel else { return }

        let menu = NSMenu()

        // 1. Screenshot Capture
        let screenshotItem = NSMenuItem(
            title: "📸  Capture Screenshot Selection",
            action: #selector(captureScreenshotAction),
            keyEquivalent: "s"
        )
        screenshotItem.keyEquivalentModifierMask = [.command, .shift]
        screenshotItem.target = self
        menu.addItem(screenshotItem)

        // 2. Paste from Clipboard
        let pasteItem = NSMenuItem(
            title: "📋  Upload from Clipboard (⌘V)",
            action: #selector(pasteClipboardAction),
            keyEquivalent: "v"
        )
        pasteItem.keyEquivalentModifierMask = [.command]
        pasteItem.target = self
        menu.addItem(pasteItem)

        menu.addItem(NSMenuItem.separator())

        // 3. Open Main Window
        let openWindowItem = NSMenuItem(
            title: "🪟  Open StaticRe Window",
            action: #selector(openMainWindowAction),
            keyEquivalent: "o"
        )
        openWindowItem.target = self
        menu.addItem(openWindowItem)

        // 4. Connection Status
        let statusTitle = vm.healthStatus.contains("OK") ? "🟢  Connected (\(vm.config.apiBaseUrl))" : "🔴  API Offline"
        let statusMenuItem = NSMenuItem(title: statusTitle, action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)

        menu.addItem(NSMenuItem.separator())

        // 5. Recent Uploads Submenu
        if !vm.recentUploads.isEmpty {
            let recentMenu = NSMenu()
            for asset in vm.recentUploads.prefix(5) {
                let name = asset.key.components(separatedBy: "/").last ?? asset.key
                let subItem = NSMenuItem(title: name, action: #selector(copyRecentAssetAction(_:)), keyEquivalent: "")
                subItem.representedObject = asset.publicUrl
                subItem.target = self
                recentMenu.addItem(subItem)
            }
            let recentParent = NSMenuItem(title: "📂  Recent Uploads", action: nil, keyEquivalent: "")
            recentParent.submenu = recentMenu
            menu.addItem(recentParent)
        }

        // 6. Settings
        let settingsItem = NSMenuItem(
            title: "⚙️  Settings...",
            action: #selector(openSettingsAction),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        // 7. Quit
        let quitItem = NSMenuItem(
            title: "Quit StaticRe",
            action: #selector(quitAppAction),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        item.menu = menu
        button.performClick(nil)
        item.menu = nil // Reset so drop view continues working on next drag/click
    }

    @objc private func captureScreenshotAction() {
        ScreenshotManager.shared.captureInteractiveScreenshot { [weak self] tempUrl in
            Task { @MainActor in
                await self?.viewModel?.uploadFile(url: tempUrl)
                try? FileManager.default.removeItem(at: tempUrl)
            }
        }
    }

    @objc private func pasteClipboardAction() {
        Task { @MainActor in
            await viewModel?.uploadFromClipboard()
        }
    }

    @objc private func openMainWindowAction() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { $0.title.contains("my.static.re") || $0.canBecomeKey }) {
            window.makeKeyAndOrderFront(nil)
        }
    }

    @objc private func openSettingsAction() {
        viewModel?.selectedTab = .settings
        openMainWindowAction()
    }

    @objc private func copyRecentAssetAction(_ sender: NSMenuItem) {
        if let url = sender.representedObject as? String {
            viewModel?.copyToClipboard(url, formatName: "Recent Link")
        }
    }

    @objc private func quitAppAction() {
        NSApplication.shared.terminate(nil)
    }
}

// MARK: - Custom Top-Bar Drop View for Drag & Drop Ingestion

final class StatusItemDropView: NSView {
    var onDrop: ((URL) -> Void)?
    var onClick: (() -> Void)?
    private var isHighlighted: Bool = false {
        didSet { needsDisplay = true }
    }

    override init(frame: NSRect) {
        super.init(frame: frame)
        registerForDraggedTypes([.fileURL])
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes([.fileURL])
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        if isHighlighted {
            NSColor.selectedControlColor.withAlphaComponent(0.3).setFill()
            let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 2, dy: 2), xRadius: 4, yRadius: 4)
            path.fill()
        }

        let symbolConfig = NSImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
        let iconName = isHighlighted ? "arrow.down.doc.fill" : "cloud.fill"

        if let image = NSImage(systemSymbolName: iconName, accessibilityDescription: "my.static.re")?.withSymbolConfiguration(symbolConfig) {
            image.isTemplate = true
            let iconRect = NSRect(
                x: (bounds.width - image.size.width) / 2,
                y: (bounds.height - image.size.height) / 2,
                width: image.size.width,
                height: image.size.height
            )
            image.draw(in: iconRect)
        }
    }

    override func mouseDown(with event: NSEvent) {
        onClick?()
    }

    // MARK: - Dragging Destination

    override func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
        isHighlighted = true
        return .copy
    }

    override func draggingUpdated(_ sender: any NSDraggingInfo) -> NSDragOperation {
        return .copy
    }

    override func draggingExited(_ sender: (any NSDraggingInfo)?) {
        isHighlighted = false
    }

    override func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        isHighlighted = false
        let pasteboard = sender.draggingPasteboard

        guard let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
              let firstUrl = urls.first else {
            return false
        }

        onDrop?(firstUrl)
        return true
    }
}

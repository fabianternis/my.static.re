import Foundation
import AppKit
import CoreGraphics
@preconcurrency import ScreenCaptureKit

@MainActor
public final class ScreenSelectionOverlay {
    public static let shared = ScreenSelectionOverlay()

    private var overlayWindows: [NSWindow] = []
    private var completionHandler: ((Data?) -> Void)?

    private init() {}

    public func startInteractiveCapture(completion: @escaping (Data?) -> Void) {
        self.completionHandler = completion
        self.closeOverlays()

        Task { @MainActor in
            do {
                let shareableContent = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                let screens = NSScreen.screens

                guard !screens.isEmpty else {
                    self.completionHandler?(nil)
                    return
                }

                for screen in screens {
                    let screenRect = screen.frame
                    guard let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID,
                          let scDisplay = shareableContent.displays.first(where: { $0.displayID == displayID }) ?? shareableContent.displays.first else {
                        continue
                    }

                    let filter = SCContentFilter(display: scDisplay, excludingWindows: [])
                    let config = SCStreamConfiguration()
                    config.width = scDisplay.width
                    config.height = scDisplay.height
                    config.showsCursor = false

                    let cgImage = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)

                    let overlayWindow = NSWindow(
                        contentRect: screenRect,
                        styleMask: [.borderless],
                        backing: .buffered,
                        defer: false
                    )
                    overlayWindow.level = .screenSaver
                    overlayWindow.isOpaque = false
                    overlayWindow.backgroundColor = .clear
                    overlayWindow.ignoresMouseEvents = false
                    overlayWindow.hasShadow = false

                    let view = SelectionCanvasView(
                        frame: NSRect(origin: .zero, size: screenRect.size),
                        fullScreenImage: cgImage,
                        screenRect: screenRect
                    ) { [weak self] croppedImageData in
                        self?.closeOverlays()
                        self?.completionHandler?(croppedImageData)
                        self?.completionHandler = nil
                    } onCancel: { [weak self] in
                        self?.closeOverlays()
                        self?.completionHandler?(nil)
                        self?.completionHandler = nil
                    }

                    overlayWindow.contentView = view
                    overlayWindow.makeKeyAndOrderFront(nil)
                    self.overlayWindows.append(overlayWindow)
                }

                NSCursor.crosshair.push()
                NSApp.activate(ignoringOtherApps: true)
            } catch {
                print("ScreenCaptureKit capture error: \(error)")
                self.closeOverlays()
                self.completionHandler?(nil)
                self.completionHandler = nil
            }
        }
    }

    private func closeOverlays() {
        NSCursor.pop()
        for window in overlayWindows {
            window.orderOut(nil)
        }
        overlayWindows.removeAll()
    }
}

// MARK: - Canvas View for Interactive Drag-to-Select

final class SelectionCanvasView: NSView {
    private let fullScreenImage: CGImage
    private let screenRect: CGRect
    private let onComplete: (Data?) -> Void
    private let onCancel: () -> Void

    private var startPoint: CGPoint?
    private var currentPoint: CGPoint?
    private var isDragging: Bool = false

    init(
        frame: NSRect,
        fullScreenImage: CGImage,
        screenRect: CGRect,
        onComplete: @escaping (Data?) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.fullScreenImage = fullScreenImage
        self.screenRect = screenRect
        self.onComplete = onComplete
        self.onCancel = onCancel
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var acceptsFirstResponder: Bool {
        return true
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        // Draw captured image
        context.draw(fullScreenImage, in: bounds)

        // Draw dark translucent veil over entire screen
        context.setFillColor(NSColor.black.withAlphaComponent(0.35).cgColor)
        context.fill(bounds)

        // If user is dragging a selection rectangle, reveal the original bright image inside
        if let rect = currentSelectionRect() {
            context.saveGState()
            context.addRect(rect)
            context.clip()

            // Draw clean bright image inside selection
            context.draw(fullScreenImage, in: bounds)

            context.restoreGState()

            // Draw sharp border around selection
            context.setStrokeColor(NSColor.controlAccentColor.cgColor)
            context.setLineWidth(2.0)
            context.stroke(rect)

            // Draw dimension label tooltip
            let dimensionText = "\(Int(rect.width)) × \(Int(rect.height))"
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .bold),
                .foregroundColor: NSColor.white,
                .backgroundColor: NSColor.black.withAlphaComponent(0.75)
            ]
            let attrString = NSAttributedString(string: " \(dimensionText) ", attributes: attributes)
            let textRect = CGRect(
                x: rect.origin.x + 4,
                y: max(rect.origin.y - 20, 10),
                width: attrString.size().width,
                height: attrString.size().height
            )
            attrString.draw(in: textRect)
        }
    }

    private func currentSelectionRect() -> CGRect? {
        guard let start = startPoint, let current = currentPoint else { return nil }

        let x = min(start.x, current.x)
        let y = min(start.y, current.y)
        let width = abs(current.x - start.x)
        let height = abs(current.y - start.y)

        guard width > 2 && height > 2 else { return nil }
        return CGRect(x: x, y: y, width: width, height: height)
    }

    // MARK: - Mouse Events

    override func mouseDown(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        self.startPoint = location
        self.currentPoint = location
        self.isDragging = true
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard isDragging else { return }
        let location = convert(event.locationInWindow, from: nil)
        self.currentPoint = location
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard isDragging, let rect = currentSelectionRect() else {
            self.isDragging = false
            self.startPoint = nil
            self.currentPoint = nil
            needsDisplay = true
            return
        }

        self.isDragging = false

        // Calculate crop rectangle in CGImage coordinate space (pixel coordinates)
        let scaleX = CGFloat(fullScreenImage.width) / bounds.width
        let scaleY = CGFloat(fullScreenImage.height) / bounds.height

        let cropRect = CGRect(
            x: rect.origin.x * scaleX,
            y: (bounds.height - rect.maxY) * scaleY, // Flip Y for CGImage
            width: rect.width * scaleX,
            height: rect.height * scaleY
        )

        guard let croppedCGImage = fullScreenImage.cropping(to: cropRect) else {
            onCancel()
            return
        }

        // Convert CGImage to PNG Data
        let bitmapRep = NSBitmapImageRep(cgImage: croppedCGImage)
        guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            onCancel()
            return
        }

        onComplete(pngData)
    }

    override func keyDown(with event: NSEvent) {
        // Escape key cancels capture
        if event.keyCode == 53 {
            onCancel()
        }
    }
}

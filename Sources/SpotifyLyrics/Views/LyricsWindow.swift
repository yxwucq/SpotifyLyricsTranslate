import AppKit
import SwiftUI

final class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }

    init(contentView: some View) {
        super.init(
            contentRect: NSRect(
                x: AppSettings.windowX,
                y: AppSettings.windowY,
                width: AppSettings.windowWidth,
                height: AppSettings.windowHeight
            ),
            styleMask: [.titled, .closable, .resizable, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        self.contentView = NSHostingView(rootView: contentView)
        self.titlebarAppearsTransparent = true
        self.titleVisibility = .hidden
        self.isMovableByWindowBackground = true
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true

        NotificationCenter.default.addObserver(
            self, selector: #selector(windowDidMove),
            name: NSWindow.didMoveNotification, object: self
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(windowDidResize),
            name: NSWindow.didResizeNotification, object: self
        )
    }

    @objc private func windowDidMove(_ notification: Notification) {
        AppSettings.windowX = frame.origin.x
        AppSettings.windowY = frame.origin.y
    }

    @objc private func windowDidResize(_ notification: Notification) {
        AppSettings.windowWidth = frame.width
        AppSettings.windowHeight = frame.height
    }
}

final class LyricsWindowController {
    private var panel: FloatingPanel?

    func show(with view: some View) {
        if let panel {
            panel.orderFront(nil)
            return
        }
        let panel = FloatingPanel(contentView: view)
        panel.orderFront(nil)
        self.panel = panel
    }

    func hide() {
        panel?.orderOut(nil)
    }

    var isVisible: Bool {
        panel?.isVisible ?? false
    }

    func close() {
        panel?.close()
        panel = nil
    }
}

// MARK: - Floating Bar (single-line overlay)

final class FloatingBarPanel: NSPanel {
    override var canBecomeKey: Bool { true }

    init(contentView: some View) {
        let width = AppSettings.barWidth
        let barX = AppSettings.barX
        let barY = AppSettings.barY

        // If barX is -1, center horizontally on the main screen
        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let x = barX < 0 ? screenFrame.midX - width / 2 : barX

        super.init(
            contentRect: NSRect(x: x, y: barY, width: width, height: 70),
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: false
        )

        self.contentView = NSHostingView(rootView: contentView)
        self.titlebarAppearsTransparent = true
        self.titleVisibility = .hidden
        self.isMovableByWindowBackground = true
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true

        NotificationCenter.default.addObserver(
            self, selector: #selector(barDidMove),
            name: NSWindow.didMoveNotification, object: self
        )
    }

    @objc private func barDidMove(_ notification: Notification) {
        AppSettings.barX = frame.origin.x
        AppSettings.barY = frame.origin.y
    }
}

final class FloatingBarController {
    private var panel: FloatingBarPanel?

    func show(with view: some View) {
        if let panel {
            panel.orderFront(nil)
            return
        }
        let panel = FloatingBarPanel(contentView: view)
        panel.orderFront(nil)
        self.panel = panel
    }

    func hide() {
        panel?.orderOut(nil)
    }

    var isVisible: Bool {
        panel?.isVisible ?? false
    }

    func close() {
        panel?.close()
        panel = nil
    }
}

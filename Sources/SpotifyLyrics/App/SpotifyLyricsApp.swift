import SwiftUI

enum DisplayMode: String {
    case window    // Full lyrics window
    case bar       // Single-line floating bar
    case hidden    // Both hidden
}

@main
struct SpotifyLyricsApp: App {
    @State private var appState = AppState()
    @State private var windowController = LyricsWindowController()
    @State private var barController = FloatingBarController()
    @State private var settingsWindowController = SettingsWindowController()
    @State private var uiTimer: Timer?
    @State private var started = false
    @State private var displayMode: DisplayMode = .window

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(
                appState: appState,
                displayMode: displayMode,
                onSetDisplayMode: setDisplayMode,
                onOpenSettings: openSettings
            )
            .onAppear {
                if !started {
                    started = true
                    startApp()
                }
            }
        } label: {
            Image(systemName: "music.note")
        }
    }

    private func startApp() {
        appState.start()

        uiTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            appState.updateActiveLine()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            setDisplayMode(.window)
        }
    }

    private func setDisplayMode(_ mode: DisplayMode) {
        // Hide everything first
        windowController.hide()
        barController.hide()

        displayMode = mode
        appState.showLyricsWindow = mode == .window
        appState.showFloatingBar = mode == .bar

        switch mode {
        case .window:
            let contentView = LyricsContentView(appState: appState)
            windowController.show(with: contentView)
        case .bar:
            let barView = FloatingBarView(appState: appState)
            barController.show(with: barView)
        case .hidden:
            break
        }
    }

    private func openSettings() {
        settingsWindowController.show()
    }
}

final class SettingsWindowController {
    private var window: NSWindow?

    func show() {
        if let window, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsView = SettingsView()
        let hostingView = NSHostingView(rootView: settingsView)
        hostingView.frame = NSRect(x: 0, y: 0, width: 450, height: 400)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 450, height: 400),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "SpotifyLyrics 设置"
        window.contentView = hostingView
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = window
    }
}

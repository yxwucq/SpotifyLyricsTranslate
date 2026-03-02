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
    @State private var meaningWindowController = SongMeaningWindowController()
    @State private var uiTimer: Timer?
    @State private var started = false
    @State private var displayMode: DisplayMode = .window

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(
                appState: appState,
                displayMode: displayMode,
                onSetDisplayMode: setDisplayMode,
                onOpenSettings: openSettings,
                onShowMeaning: showMeaning
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

    private func showMeaning() {
        meaningWindowController.show(appState: appState)
    }
}

final class SongMeaningWindowController {
    private var window: NSWindow?

    func show(appState: AppState) {
        if let window, window.isVisible {
            // Update content with latest meaning
            let view = SongMeaningView(appState: appState)
            window.contentView = NSHostingView(rootView: view)
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let view = SongMeaningView(appState: appState)
        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = NSRect(x: 0, y: 0, width: 400, height: 400)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 400),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "歌词大意"
        window.titlebarAppearsTransparent = true
        window.isOpaque = false
        window.backgroundColor = .clear
        window.contentView = hostingView
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = window
    }
}

struct SongMeaningView: View {
    let appState: AppState
    @State private var showBackground = false
    @State private var showMetaphors = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let track = appState.playerMonitor.currentTrack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(track.name)
                            .font(.title2)
                            .fontWeight(.bold)
                        Text(track.artist)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 20)
                }

                if appState.isFetchingMeaning {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text("正在解读…")
                            .foregroundStyle(.secondary)
                    }
                } else if let meaning = appState.songMeaning {
                    Text(meaning.summary)
                        .textSelection(.enabled)

                    if !meaning.background.isEmpty {
                        VStack(alignment: .leading, spacing: 0) {
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    showBackground.toggle()
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .rotationEffect(.degrees(showBackground ? 90 : 0))
                                    Text("创作背景")
                                        .fontWeight(.medium)
                                    Spacer()
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            if showBackground {
                                Text(meaning.background)
                                    .textSelection(.enabled)
                                    .padding(.top, 8)
                            }
                        }
                        .padding(12)
                        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
                    }

                    if !meaning.metaphors.isEmpty {
                        VStack(alignment: .leading, spacing: 0) {
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    showMetaphors.toggle()
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .rotationEffect(.degrees(showMetaphors ? 90 : 0))
                                    Text("意象与隐喻")
                                        .fontWeight(.medium)
                                    Spacer()
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            if showMetaphors {
                                Text(meaning.metaphors)
                                    .textSelection(.enabled)
                                    .padding(.top, 8)
                            }
                        }
                        .padding(12)
                        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
                    }
                } else {
                    Text("暂无解读内容")
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(.ultraThinMaterial)
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
        hostingView.frame = NSRect(x: 0, y: 0, width: 450, height: 520)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 450, height: 520),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
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

import SwiftUI

struct MenuBarView: View {
    let appState: AppState
    let displayMode: DisplayMode
    let onSetDisplayMode: (DisplayMode) -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let track = appState.playerMonitor.currentTrack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(track.name)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                    Text(track.artist)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

                Divider()
            } else {
                Text("Spotify 未在播放")
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)

                Divider()
            }

            Button {
                onSetDisplayMode(.window)
            } label: {
                HStack {
                    Text("歌词窗口")
                    Spacer()
                    if displayMode == .window {
                        Image(systemName: "checkmark")
                    }
                }
            }
            .keyboardShortcut("l", modifiers: [.command, .shift])
            .padding(.horizontal, 4)

            Button {
                onSetDisplayMode(.bar)
            } label: {
                HStack {
                    Text("悬浮歌词条")
                    Spacer()
                    if displayMode == .bar {
                        Image(systemName: "checkmark")
                    }
                }
            }
            .keyboardShortcut("b", modifiers: [.command, .shift])
            .padding(.horizontal, 4)

            Button {
                onSetDisplayMode(.hidden)
            } label: {
                HStack {
                    Text("隐藏歌词")
                    Spacer()
                    if displayMode == .hidden {
                        Image(systemName: "checkmark")
                    }
                }
            }
            .padding(.horizontal, 4)

            Divider()

            Button(appState.isTranslating ? "正在翻译…" : (AppSettings.translationEnabled ? "关闭翻译" : "开启翻译")) {
                Task { await appState.toggleTranslation() }
            }
            .disabled(appState.isTranslating)
            .padding(.horizontal, 4)

            Divider()

            Button("设置…") {
                onOpenSettings()
            }
            .keyboardShortcut(",", modifiers: .command)
            .padding(.horizontal, 4)

            Divider()

            Button("退出") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
            .padding(.horizontal, 4)
        }
        .frame(width: 250)
    }
}

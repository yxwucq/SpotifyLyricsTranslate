import SwiftUI

struct MenuBarView: View {
    let appState: AppState
    let displayMode: DisplayMode
    let onSetDisplayMode: (DisplayMode) -> Void
    let onOpenSettings: () -> Void
    let onShowMeaning: () -> Void

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
                Text(L.spotifyNotPlaying)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)

                Divider()
            }

            Button {
                onSetDisplayMode(.window)
            } label: {
                HStack {
                    Text(L.lyricsWindow)
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
                    Text(L.floatingBar)
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
                    Text(L.hideLyrics)
                    Spacer()
                    if displayMode == .hidden {
                        Image(systemName: "checkmark")
                    }
                }
            }
            .padding(.horizontal, 4)

            Divider()

            Button(appState.isTranslating ? L.translating : (AppSettings.translationEnabled ? L.disableTranslation : L.enableTranslation)) {
                Task { await appState.toggleTranslation() }
            }
            .disabled(appState.isTranslating)
            .padding(.horizontal, 4)

            Button(appState.isFetchingMeaning ? L.interpreting : L.songMeaning) {
                Task {
                    await appState.fetchSongMeaning()
                    onShowMeaning()
                }
            }
            .disabled(appState.isFetchingMeaning || appState.playerMonitor.currentTrack == nil || appState.lyrics.isEmpty)
            .padding(.horizontal, 4)

            Divider()

            Button(L.settings) {
                onOpenSettings()
            }
            .keyboardShortcut(",", modifiers: .command)
            .padding(.horizontal, 4)

            Divider()

            Button(L.quit) {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
            .padding(.horizontal, 4)
        }
        .frame(width: 250)
    }
}

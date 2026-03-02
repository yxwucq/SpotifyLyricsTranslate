import SwiftUI

struct LyricsContentView: View {
    let appState: AppState

    @AppStorage("backgroundOpacity") private var backgroundOpacity: Double = 0.75

    var body: some View {
        ZStack {
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                .opacity(backgroundOpacity)

            if appState.lyrics.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 40, weight: .light))
                        .foregroundStyle(
                            .linearGradient(
                                colors: [.purple, .blue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    if !appState.statusMessage.isEmpty {
                        Text(appState.statusMessage)
                            .foregroundStyle(.secondary)
                            .font(.title3)
                            .multilineTextAlignment(.center)
                    }
                    if appState.isTranslating {
                        HStack(spacing: 8) {
                            ProgressView()
                                .scaleEffect(0.7)
                            Text(L.translating)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(.white.opacity(0.08), in: Capsule())
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 0) {
                    // Track info bar — opaque, not transparent
                    if let track = appState.playerMonitor.currentTrack {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(track.name)
                                    .font(.callout)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                Text(track.artist)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            if appState.isTranslating {
                                ProgressView()
                                    .scaleEffect(0.6)
                            }
                            Text(appState.lyricsSource)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.thickMaterial)
                    }

                    // Lyrics scroll area
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                Spacer().frame(height: 20)

                                ForEach(appState.lyrics) { line in
                                    LyricLineView(line: line, isActive: line.id == appState.activeLineIndex)
                                        .id(line.id)
                                }

                                Spacer().frame(height: 200)
                            }
                        }
                        .onChange(of: appState.activeLineIndex) { _, newIndex in
                            withAnimation(.easeInOut(duration: 0.3)) {
                                proxy.scrollTo(newIndex, anchor: .center)
                            }
                        }
                    }
                }
            }
        }
    }
}

struct VisualEffectBlur: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

import SwiftUI

struct FloatingBarView: View {
    let appState: AppState

    @AppStorage("fontFamily") private var fontFamily = "System"
    @AppStorage("fontSize") private var fontSize: Double = 20
    @AppStorage("currentLineColor") private var currentLineColorHex = "#FFFFFF"
    @AppStorage("translationColor") private var translationColorHex = "#88CCFF"
    @AppStorage("backgroundOpacity") private var backgroundOpacity: Double = 0.75
    @AppStorage("translationFontScale") private var translationFontScale: Double = 0.8

    var body: some View {
        let activeLine = currentLine

        VStack(spacing: 2) {
            if let line = activeLine, !line.isEmpty {
                Text(line.text)
                    .font(barFont(size: fontSize))
                    .foregroundStyle(Color(hex: currentLineColorHex) ?? .white)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)

                if let translation = line.translation {
                    Text(translation)
                        .font(barFont(size: fontSize * translationFontScale))
                        .foregroundStyle(Color(hex: translationColorHex) ?? .blue)
                        .lineLimit(1)
                        .multilineTextAlignment(.center)
                }
            } else if !appState.statusMessage.isEmpty {
                Text(appState.statusMessage)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            } else {
                Text("♪")
                    .font(.system(size: fontSize))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(
            VisualEffectBlur(material: .popover, blendingMode: .behindWindow)
                .opacity(backgroundOpacity)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.2), radius: 12)
        .animation(.easeInOut(duration: 0.25), value: appState.activeLineIndex)
    }

    private var currentLine: LyricLine? {
        guard !appState.lyrics.isEmpty,
              appState.activeLineIndex >= 0,
              appState.activeLineIndex < appState.lyrics.count else { return nil }
        return appState.lyrics[appState.activeLineIndex]
    }

    private func barFont(size: Double) -> Font {
        if fontFamily == "System" {
            return .system(size: size, weight: .semibold)
        }
        return .custom(fontFamily, size: size)
    }
}

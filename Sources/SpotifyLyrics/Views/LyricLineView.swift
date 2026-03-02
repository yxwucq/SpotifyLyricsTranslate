import SwiftUI

struct LyricLineView: View {
    let line: LyricLine
    let isActive: Bool

    @AppStorage("fontFamily") private var fontFamily = "System"
    @AppStorage("fontSize") private var fontSize: Double = 20
    @AppStorage("currentLineColor") private var currentLineColorHex = "#FFFFFF"
    @AppStorage("otherLineColor") private var otherLineColorHex = "#AAAAAA"
    @AppStorage("translationColor") private var translationColorHex = "#88CCFF"

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(line.text)
                .font(lyricFont(size: isActive ? fontSize * 1.15 : fontSize))
                .foregroundStyle(isActive ? (Color(hex: currentLineColorHex) ?? .white) : (Color(hex: otherLineColorHex) ?? .gray))
                .opacity(isActive ? 1.0 : 0.6)

            if let translation = line.translation {
                Text(translation)
                    .font(lyricFont(size: fontSize * 0.8))
                    .foregroundStyle(Color(hex: translationColorHex) ?? .blue)
                    .opacity(isActive ? 0.9 : 0.5)
                    .transition(.opacity)
            }
        }
        .padding(.vertical, isActive ? 8 : 4)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.easeInOut(duration: 0.3), value: isActive)
    }

    private func lyricFont(size: Double) -> Font {
        if fontFamily == "System" {
            return .system(size: size, weight: isActive ? .bold : .regular)
        }
        return .custom(fontFamily, size: size)
    }
}

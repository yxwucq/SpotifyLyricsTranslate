import SwiftUI

struct LyricLineView: View {
    let line: LyricLine
    let isActive: Bool

    @AppStorage("fontFamily") private var fontFamily = "System"
    @AppStorage("fontSize") private var fontSize: Double = 20
    @AppStorage("currentLineColor") private var currentLineColorHex = "#FFFFFF"
    @AppStorage("otherLineColor") private var otherLineColorHex = "#AAAAAA"
    @AppStorage("translationColor") private var translationColorHex = "#88CCFF"

    @AppStorage("lyricAlignment") private var lyricAlignment = "leading"
    @AppStorage("translationFontScale") private var translationFontScale: Double = 0.8
    @AppStorage("lineSpacing") private var lineSpacing: Double = 0
    @AppStorage("activeLineScale") private var activeLineScale: Double = 1.15
    @AppStorage("activeLineHighlight") private var activeLineHighlight: Bool = true
    @AppStorage("activeLineHighlightColorHex") private var activeLineHighlightColorHex = "#FFFFFF"
    @AppStorage("activeLineHighlightOpacity") private var activeLineHighlightOpacity: Double = 0.08
    @AppStorage("inactiveLineOpacity") private var inactiveLineOpacity: Double = 0.4

    private var alignment: HorizontalAlignment {
        switch lyricAlignment {
        case "center": return .center
        case "trailing": return .trailing
        default: return .leading
        }
    }

    private var textAlignment: TextAlignment {
        switch lyricAlignment {
        case "center": return .center
        case "trailing": return .trailing
        default: return .leading
        }
    }

    private var frameAlignment: Alignment {
        switch lyricAlignment {
        case "center": return .center
        case "trailing": return .trailing
        default: return .leading
        }
    }

    var body: some View {
        VStack(alignment: alignment, spacing: 4) {
            Text(line.text)
                .font(lyricFont(size: isActive ? fontSize * activeLineScale : fontSize))
                .foregroundStyle(isActive ? (Color(hex: currentLineColorHex) ?? .white) : (Color(hex: otherLineColorHex) ?? .gray))
                .opacity(isActive ? 1.0 : inactiveLineOpacity)
                .multilineTextAlignment(textAlignment)

            if let translation = line.translation {
                Text(translation)
                    .font(lyricFont(size: fontSize * translationFontScale))
                    .foregroundStyle(Color(hex: translationColorHex) ?? .blue)
                    .opacity(isActive ? 0.9 : inactiveLineOpacity)
                    .multilineTextAlignment(textAlignment)
                    .transition(.opacity)
            }
        }
        .padding(.vertical, isActive ? 10 : 6)
        .padding(.bottom, lineSpacing)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: frameAlignment)
        .background(
            isActive && activeLineHighlight
                ? AnyShapeStyle((Color(hex: activeLineHighlightColorHex) ?? .white).opacity(activeLineHighlightOpacity))
                : AnyShapeStyle(.clear),
            in: RoundedRectangle(cornerRadius: 8)
        )
        .padding(.horizontal, 4)
        .animation(.easeInOut(duration: 0.3), value: isActive)
    }

    private func lyricFont(size: Double) -> Font {
        if fontFamily == "System" {
            return .system(size: size, weight: isActive ? .bold : .regular)
        }
        return .custom(fontFamily, size: size)
    }
}

import SwiftUI

enum TranslationProvider: String, CaseIterable {
    case claude = "Claude"
    case openai = "OpenAI"
}

enum LyricsSource: String, CaseIterable {
    case spotify = "Spotify"
    case lrclib = "LRCLIB"
    case auto = "Auto"
}

struct AppSettings {
    @AppStorage("appLanguage") static var appLanguage: String = "en"
    @AppStorage("fontFamily") static var fontFamily: String = "System"
    @AppStorage("fontSize") static var fontSize: Double = 20
    @AppStorage("currentLineColor") static var currentLineColorHex: String = "#FFFFFF"
    @AppStorage("otherLineColor") static var otherLineColorHex: String = "#AAAAAA"
    @AppStorage("translationColor") static var translationColorHex: String = "#88CCFF"
    @AppStorage("backgroundOpacity") static var backgroundOpacity: Double = 0.75
    @AppStorage("targetLanguage") static var targetLanguage: String = "zh-Hans"
    @AppStorage("translationEnabled") static var translationEnabled: Bool = true
    @AppStorage("translationProvider") static var translationProviderRaw: String = TranslationProvider.claude.rawValue
    @AppStorage("lyricsSource") static var lyricsSourceRaw: String = LyricsSource.auto.rawValue
    @AppStorage("claudeModel") static var claudeModel: String = "claude-sonnet-4-20250514"
    @AppStorage("claudeBaseURL") static var claudeBaseURL: String = "https://api.anthropic.com"
    @AppStorage("openaiModel") static var openaiModel: String = "gpt-4o-mini"
    @AppStorage("openaiBaseURL") static var openaiBaseURL: String = "https://api.openai.com"
    @AppStorage("windowX") static var windowX: Double = 100
    @AppStorage("windowY") static var windowY: Double = 100
    @AppStorage("windowWidth") static var windowWidth: Double = 400
    @AppStorage("windowHeight") static var windowHeight: Double = 600
    @AppStorage("barX") static var barX: Double = -1  // -1 means center
    @AppStorage("barY") static var barY: Double = 80
    @AppStorage("barWidth") static var barWidth: Double = 600
    @AppStorage("translationCachePath") static var translationCachePath: String = ""

    // 歌词排版
    @AppStorage("lyricAlignment") static var lyricAlignment: String = "leading"  // leading / center / trailing
    @AppStorage("translationFontScale") static var translationFontScale: Double = 0.8
    @AppStorage("lineSpacing") static var lineSpacing: Double = 0

    // 当前行效果
    @AppStorage("activeLineScale") static var activeLineScale: Double = 1.15
    @AppStorage("activeLineHighlight") static var activeLineHighlight: Bool = true
    @AppStorage("activeLineHighlightColorHex") static var activeLineHighlightColorHex: String = "#FFFFFF"
    @AppStorage("activeLineHighlightOpacity") static var activeLineHighlightOpacity: Double = 0.08
    @AppStorage("inactiveLineOpacity") static var inactiveLineOpacity: Double = 0.4

    static var defaultCacheDir: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            .appendingPathComponent("SpotifyLyrics/translations", isDirectory: true)
    }

    static var effectiveCacheDir: URL {
        if translationCachePath.isEmpty {
            return defaultCacheDir
        }
        return URL(fileURLWithPath: translationCachePath, isDirectory: true)
    }

    static var translationProviderEnum: TranslationProvider {
        get { TranslationProvider(rawValue: translationProviderRaw) ?? .claude }
        set { translationProviderRaw = newValue.rawValue }
    }

    static var lyricsSourceEnum: LyricsSource {
        get { LyricsSource(rawValue: lyricsSourceRaw) ?? .auto }
        set { lyricsSourceRaw = newValue.rawValue }
    }

    static var currentLineColor: Color {
        Color(hex: currentLineColorHex) ?? .white
    }
    static var otherLineColor: Color {
        Color(hex: otherLineColorHex) ?? .gray
    }
    static var translationLineColor: Color {
        Color(hex: translationColorHex) ?? .blue
    }

    static let supportedLanguages: [(code: String, name: String)] = [
        ("zh-Hans", "简体中文"),
        ("zh-Hant", "繁體中文"),
        ("ja", "日本語"),
        ("ko", "한국어"),
        ("en", "English"),
        ("es", "Español"),
        ("fr", "Français"),
        ("de", "Deutsch"),
    ]
}

extension Color {
    init?(hex: String) {
        var h = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if h.hasPrefix("#") { h.removeFirst() }
        guard h.count == 6, let val = UInt64(h, radix: 16) else { return nil }
        self.init(
            red: Double((val >> 16) & 0xFF) / 255.0,
            green: Double((val >> 8) & 0xFF) / 255.0,
            blue: Double(val & 0xFF) / 255.0
        )
    }

    var hexString: String {
        guard let c = NSColor(self).usingColorSpace(.sRGB) else { return "#FFFFFF" }
        return String(format: "#%02X%02X%02X",
                      Int(c.redComponent * 255),
                      Int(c.greenComponent * 255),
                      Int(c.blueComponent * 255))
    }
}

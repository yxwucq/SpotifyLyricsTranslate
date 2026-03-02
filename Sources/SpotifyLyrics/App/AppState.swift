import SwiftUI

@Observable
final class AppState {
    let playerMonitor = SpotifyPlayerMonitor()
    let authService = SpotifyAuthService()
    let translationCache = TranslationCache()

    private(set) var lyricsService: LyricsService!

    func setup() {
        lyricsService = LyricsService(
            spotifyProvider: SpotifyLyricsProvider(authService: authService),
            lrclibProvider: LRCLIBProvider()
        )
    }

    var lyrics: [LyricLine] = []
    var activeLineIndex: Int = 0
    var lyricsSource: String = ""
    var statusMessage: String = "等待 Spotify 播放…"
    var isTranslating: Bool = false
    var showLyricsWindow: Bool = true
    var showFloatingBar: Bool = false

    private var trackObserver: Any?

    func start() {
        if lyricsService == nil { setup() }
        playerMonitor.startMonitoring()
        trackObserver = NotificationCenter.default.addObserver(
            forName: .trackChanged, object: nil, queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { await self.onTrackChanged() }
        }
    }

    func stop() {
        playerMonitor.stopMonitoring()
        if let obs = trackObserver {
            NotificationCenter.default.removeObserver(obs)
        }
    }

    func onTrackChanged() async {
        guard let track = playerMonitor.currentTrack else {
            lyrics = []
            statusMessage = "Spotify 未在播放"
            return
        }

        statusMessage = "正在获取歌词…"
        lyrics = []
        activeLineIndex = 0

        let result = await lyricsService.fetchLyrics(for: track)

        switch result {
        case .success(let lines, let source):
            lyrics = lines
            lyricsSource = source
            statusMessage = ""
            if AppSettings.translationEnabled {
                await translateLyrics(track: track)
            }
        case .noLyrics:
            statusMessage = "该曲目无歌词"
        case .error(let msg):
            statusMessage = "获取歌词失败: \(msg)"
        }
    }

    func updateActiveLine() {
        let posMs = playerMonitor.positionMs
        guard !lyrics.isEmpty else { return }

        // Binary search for the last line with timestampMs <= posMs
        var lo = 0, hi = lyrics.count - 1
        var result = 0
        while lo <= hi {
            let mid = (lo + hi) / 2
            if lyrics[mid].timestampMs <= posMs {
                result = mid
                lo = mid + 1
            } else {
                hi = mid - 1
            }
        }
        activeLineIndex = result
    }

    func translateLyrics(track: Track) async {
        let language = AppSettings.targetLanguage

        // Check cache first
        if let cached = await translationCache.get(trackId: track.id, language: language) {
            applyTranslations(cached)
            return
        }

        let textsToTranslate = lyrics.map(\.text)
        guard !textsToTranslate.isEmpty else { return }

        isTranslating = true
        defer { isTranslating = false }

        let provider: TranslationProviderProtocol = switch AppSettings.translationProviderEnum {
        case .claude: ClaudeTranslationProvider()
        case .openai: OpenAITranslationProvider()
        }

        do {
            let translations = try await provider.translate(lines: textsToTranslate, to: language)
            await translationCache.set(trackId: track.id, language: language, translations: translations)
            applyTranslations(translations)
        } catch {
            statusMessage = "翻译失败: \(error.localizedDescription)"
        }
    }

    private func applyTranslations(_ translations: [String]) {
        for i in 0..<min(lyrics.count, translations.count) {
            lyrics[i].translation = translations[i].isEmpty ? nil : translations[i]
        }
    }

    func retryLyrics() async {
        await onTrackChanged()
    }

    func toggleTranslation() async {
        AppSettings.translationEnabled.toggle()
        if AppSettings.translationEnabled, let track = playerMonitor.currentTrack {
            await translateLyrics(track: track)
        } else {
            for i in lyrics.indices {
                lyrics[i].translation = nil
            }
        }
    }
}

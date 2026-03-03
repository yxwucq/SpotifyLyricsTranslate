import SwiftUI
import NaturalLanguage

@Observable
final class AppState {
    static weak var shared: AppState?

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
    var statusMessage: String = L.waitingForSpotify
    var isTranslating: Bool = false
    var songMeaning: SongMeaning?
    var isFetchingMeaning: Bool = false
    var showLyricsWindow: Bool = true
    var showFloatingBar: Bool = false

    private var trackObserver: Any?

    func start() {
        AppState.shared = self
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
            statusMessage = L.spotifyNotPlaying
            return
        }

        statusMessage = L.fetchingLyrics
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
            statusMessage = L.noLyricsForTrack
        case .error(let msg):
            statusMessage = L.fetchLyricsFailed(msg)
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

        // Skip translation if lyrics are already in the target language
        if lyricsMatchTargetLanguage(language) { return }

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

        let maxRetries = 3
        var lastError: Error?

        for attempt in 1...maxRetries {
            do {
                var translations = Array(repeating: "", count: textsToTranslate.count)
                let stream = provider.streamTranslate(lines: textsToTranslate, to: language)

                for try await (index, text) in stream {
                    guard index >= 0, index < lyrics.count else { continue }
                    translations[index] = text
                    lyrics[index].translation = text.isEmpty ? nil : text
                }

                await translationCache.set(trackId: track.id, language: language, translations: translations)
                return
            } catch {
                lastError = error
                // Clear partial translations on failure before retry
                for i in lyrics.indices { lyrics[i].translation = nil }
                if attempt < maxRetries {
                    statusMessage = L.translationRetrying(attempt, maxRetries)
                    try? await Task.sleep(for: .seconds(Double(attempt)))
                }
            }
        }

        statusMessage = L.translationFailed(lastError?.localizedDescription ?? L.unknownError)
    }

    private func lyricsMatchTargetLanguage(_ target: String) -> Bool {
        // Sample non-empty lines for detection
        let sampleLines = lyrics
            .map(\.text)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .prefix(20)

        guard !sampleLines.isEmpty else { return false }

        let text = sampleLines.joined(separator: " ")

        let targetPrefix = target.components(separatedBy: "-").first ?? target  // "zh-Hans" -> "zh"

        // Use NLLanguageRecognizer for detection
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        guard let detected = recognizer.dominantLanguage else { return false }

        let detectedCode = detected.rawValue  // e.g. "zh", "en", "ja", "ko"

        // Match: "zh" covers both "zh-Hans" and "zh-Hant"
        return detectedCode == targetPrefix
    }

    private func applyTranslations(_ translations: [String]) {
        for i in 0..<min(lyrics.count, translations.count) {
            lyrics[i].translation = translations[i].isEmpty ? nil : translations[i]
        }
    }

    func retryLyrics() async {
        await onTrackChanged()
    }

    func fetchSongMeaning() async {
        guard let track = playerMonitor.currentTrack, !lyrics.isEmpty else { return }

        isFetchingMeaning = true
        defer { isFetchingMeaning = false }

        let searchContext = await DuckDuckGoSearch.search(track: track)

        let maxRetries = 3
        var lastError: Error?

        for attempt in 1...maxRetries {
            do {
                let raw = try await SongMeaningGenerator.generate(
                    track: track, lyrics: lyrics, searchContext: searchContext
                )
                songMeaning = SongMeaning.parse(raw)
                return
            } catch {
                lastError = error
                if attempt < maxRetries {
                    statusMessage = L.meaningRetrying(attempt, maxRetries)
                    try? await Task.sleep(for: .seconds(Double(attempt)))
                }
            }
        }

        songMeaning = SongMeaning(summary: L.meaningFailed(lastError?.localizedDescription ?? L.unknownError))
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

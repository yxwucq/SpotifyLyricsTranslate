import Foundation

final class LyricsService {
    private let spotifyProvider: SpotifyLyricsProvider
    private let lrclibProvider: LRCLIBProvider

    init(spotifyProvider: SpotifyLyricsProvider, lrclibProvider: LRCLIBProvider) {
        self.spotifyProvider = spotifyProvider
        self.lrclibProvider = lrclibProvider
    }

    func fetchLyrics(for track: Track) async -> LyricsResult {
        let source = AppSettings.lyricsSourceEnum

        switch source {
        case .spotify:
            return await fetchFromSpotify(track: track)
        case .lrclib:
            return await fetchFromLRCLIB(track: track)
        case .auto:
            let result = await fetchFromSpotify(track: track)
            if case .success = result { return result }
            return await fetchFromLRCLIB(track: track)
        }
    }

    private func fetchFromSpotify(track: Track) async -> LyricsResult {
        do {
            let lines = try await spotifyProvider.fetchLyrics(trackId: track.id)
            return lines.isEmpty ? .noLyrics : .success(lines, source: "Spotify")
        } catch {
            return .error(error.localizedDescription)
        }
    }

    private func fetchFromLRCLIB(track: Track) async -> LyricsResult {
        do {
            let lines = try await lrclibProvider.fetchLyrics(
                trackName: track.name,
                artistName: track.artist,
                duration: track.durationMs
            )
            return lines.isEmpty ? .noLyrics : .success(lines, source: "LRCLIB")
        } catch {
            return .error(error.localizedDescription)
        }
    }
}

enum LyricsResult {
    case success([LyricLine], source: String)
    case noLyrics
    case error(String)
}

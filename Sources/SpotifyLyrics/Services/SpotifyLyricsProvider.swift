import Foundation

final class SpotifyLyricsProvider {
    private let authService: SpotifyAuthService

    init(authService: SpotifyAuthService) {
        self.authService = authService
    }

    func fetchLyrics(trackId: String) async throws -> [LyricLine] {
        let token = try await authService.getAccessToken()

        var request = URLRequest(url: URL(string: "https://spclient.wg.spotify.com/color-lyrics/v2/track/\(trackId)?format=json&market=from_token")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("com.spotify.music", forHTTPHeaderField: "App-Platform")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LyricsError.networkError
        }

        if httpResponse.statusCode == 401 {
            await authService.invalidateToken()
            throw LyricsError.unauthorized
        }

        guard httpResponse.statusCode == 200 else {
            throw LyricsError.noLyrics
        }

        return try parseLyrics(data)
    }

    private func parseLyrics(_ data: Data) throws -> [LyricLine] {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let lyrics = json["lyrics"] as? [String: Any],
              let lines = lyrics["lines"] as? [[String: Any]] else {
            throw LyricsError.parseError
        }

        return lines.enumerated().compactMap { index, line in
            guard let startMs = line["startTimeMs"] as? String,
                  let ms = Int(startMs),
                  let words = line["words"] as? String else { return nil }
            return LyricLine(id: index, timestampMs: ms, text: words)
        }
    }

    enum LyricsError: LocalizedError {
        case networkError, unauthorized, noLyrics, parseError

        var errorDescription: String? {
            switch self {
            case .networkError: "网络错误"
            case .unauthorized: "Spotify 认证失败"
            case .noLyrics: "该曲目无歌词"
            case .parseError: "歌词解析失败"
            }
        }
    }
}

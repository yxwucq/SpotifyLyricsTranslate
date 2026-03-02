import Foundation

final class LRCLIBProvider {
    func fetchLyrics(trackName: String, artistName: String, duration: Int) async throws -> [LyricLine] {
        var components = URLComponents(string: "https://lrclib.net/api/get")!
        components.queryItems = [
            URLQueryItem(name: "track_name", value: trackName),
            URLQueryItem(name: "artist_name", value: artistName),
            URLQueryItem(name: "duration", value: String(duration / 1000)),
        ]

        guard let url = components.url else {
            throw LRCLIBError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("SpotifyLyrics/1.0", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw LRCLIBError.noLyrics
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        // Prefer synced lyrics (LRC format with timestamps)
        if let syncedLyrics = json?["syncedLyrics"] as? String, !syncedLyrics.isEmpty {
            let lines = LRCParser.parse(syncedLyrics)
            if !lines.isEmpty { return lines }
        }

        // Fall back to plain lyrics (no timestamps)
        if let plainLyrics = json?["plainLyrics"] as? String, !plainLyrics.isEmpty {
            return plainLyrics.components(separatedBy: "\n").enumerated().map { index, line in
                LyricLine(id: index, timestampMs: 0, text: line)
            }
        }

        throw LRCLIBError.noLyrics
    }

    enum LRCLIBError: LocalizedError {
        case invalidURL, noLyrics

        var errorDescription: String? {
            switch self {
            case .invalidURL: "URL 构造失败"
            case .noLyrics: "LRCLIB 未找到歌词"
            }
        }
    }
}

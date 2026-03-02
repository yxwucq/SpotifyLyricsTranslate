import Foundation

final class LRCLIBProvider {
    func fetchLyrics(trackName: String, artistName: String, duration: Int) async throws -> [LyricLine] {
        let durationSec = duration / 1000

        // Step 1: exact match with original name
        if let lines = try? await fetchExact(trackName: trackName, artistName: artistName, duration: durationSec) {
            return lines
        }

        // Step 2: exact match with cleaned name
        let cleanedTrack = cleanTrackName(trackName)
        let cleanedArtist = cleanArtistName(artistName)
        let nameChanged = cleanedTrack != trackName || cleanedArtist != artistName
        if nameChanged {
            if let lines = try? await fetchExact(trackName: cleanedTrack, artistName: cleanedArtist, duration: durationSec) {
                return lines
            }
        }

        // Step 3: fuzzy search + best match
        if let lines = try? await fetchViaSearch(trackName: cleanedTrack, artistName: cleanedArtist, durationSec: durationSec) {
            return lines
        }

        throw LRCLIBError.noLyrics
    }

    // MARK: - Exact match

    private func fetchExact(trackName: String, artistName: String, duration: Int) async throws -> [LyricLine] {
        var components = URLComponents(string: "https://lrclib.net/api/get")!
        components.queryItems = [
            URLQueryItem(name: "track_name", value: trackName),
            URLQueryItem(name: "artist_name", value: artistName),
            URLQueryItem(name: "duration", value: String(duration)),
        ]

        guard let url = components.url else { throw LRCLIBError.invalidURL }

        let (data, response) = try await makeRequest(url: url)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw LRCLIBError.noLyrics
        }

        return try parseSingleResult(data: data)
    }

    // MARK: - Search fallback

    private func fetchViaSearch(trackName: String, artistName: String, durationSec: Int) async throws -> [LyricLine] {
        let query = "\(trackName) \(artistName)"
        var components = URLComponents(string: "https://lrclib.net/api/search")!
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
        ]

        guard let url = components.url else { throw LRCLIBError.invalidURL }

        let (data, response) = try await makeRequest(url: url)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw LRCLIBError.noLyrics
        }

        guard let results = try JSONSerialization.jsonObject(with: data) as? [[String: Any]], !results.isEmpty else {
            throw LRCLIBError.noLyrics
        }

        // Score and rank candidates
        let targetTrack = trackName.lowercased()
        let targetArtist = artistName.lowercased()

        var bestScore = -1.0
        var bestResult: [String: Any]?

        for item in results {
            let name = (item["trackName"] as? String ?? "").lowercased()
            let artist = (item["artistName"] as? String ?? "").lowercased()
            let dur = item["duration"] as? Int ?? 0
            let hasSynced = (item["syncedLyrics"] as? String)?.isEmpty == false
            let hasPlain = (item["plainLyrics"] as? String)?.isEmpty == false

            guard hasSynced || hasPlain else { continue }

            let nameScore = stringSimilarity(name, targetTrack)
            let artistScore = stringSimilarity(artist, targetArtist)
            let durationDiff = abs(dur - durationSec)
            let durationScore = durationDiff <= 3 ? 1.0 : (durationDiff <= 10 ? 0.5 : 0.0)
            let syncBonus = hasSynced ? 0.1 : 0.0

            let score = nameScore * 0.5 + artistScore * 0.3 + durationScore * 0.1 + syncBonus

            if score > bestScore {
                bestScore = score
                bestResult = item
            }
        }

        // Require a minimum quality threshold
        guard let best = bestResult, bestScore >= 0.3 else {
            throw LRCLIBError.noLyrics
        }

        return parseSearchItem(best)
    }

    // MARK: - Parsing

    private func parseSingleResult(data: Data) throws -> [LyricLine] {
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        if let syncedLyrics = json?["syncedLyrics"] as? String, !syncedLyrics.isEmpty {
            let lines = LRCParser.parse(syncedLyrics)
            if !lines.isEmpty { return lines }
        }

        if let plainLyrics = json?["plainLyrics"] as? String, !plainLyrics.isEmpty {
            return plainLyrics.components(separatedBy: "\n").enumerated().map { index, line in
                LyricLine(id: index, timestampMs: 0, text: line)
            }
        }

        throw LRCLIBError.noLyrics
    }

    private func parseSearchItem(_ item: [String: Any]) -> [LyricLine] {
        if let syncedLyrics = item["syncedLyrics"] as? String, !syncedLyrics.isEmpty {
            let lines = LRCParser.parse(syncedLyrics)
            if !lines.isEmpty { return lines }
        }

        if let plainLyrics = item["plainLyrics"] as? String, !plainLyrics.isEmpty {
            return plainLyrics.components(separatedBy: "\n").enumerated().map { index, line in
                LyricLine(id: index, timestampMs: 0, text: line)
            }
        }

        return []
    }

    // MARK: - Name cleaning

    private func cleanTrackName(_ name: String) -> String {
        var cleaned = name
        // Remove parenthetical suffixes: (feat. ...), (Remastered ...), (Deluxe ...), etc.
        cleaned = cleaned.replacingOccurrences(
            of: #"\s*[\(\[（](?:feat\.?|ft\.?|with|remaster(?:ed)?|deluxe|bonus|live|demo|acoustic|remix|version|edit|radio).*?[\)\]）]"#,
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )
        // Remove " - Remastered 2009" style suffixes
        cleaned = cleaned.replacingOccurrences(
            of: #"\s*-\s*(?:remaster(?:ed)?|deluxe|bonus|live|demo|acoustic|remix|version|edit|radio).*$"#,
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )
        return cleaned.trimmingCharacters(in: .whitespaces)
    }

    private func cleanArtistName(_ name: String) -> String {
        // Take only the first artist when multiple are listed
        let separators = [", ", " & ", " and ", "；", "、", " feat. ", " feat ", " ft. ", " ft "]
        var cleaned = name
        for sep in separators {
            if let range = cleaned.range(of: sep, options: .caseInsensitive) {
                cleaned = String(cleaned[..<range.lowerBound])
                break
            }
        }
        return cleaned.trimmingCharacters(in: .whitespaces)
    }

    // MARK: - String similarity (Dice coefficient on bigrams)

    private func stringSimilarity(_ a: String, _ b: String) -> Double {
        if a == b { return 1.0 }
        if a.isEmpty || b.isEmpty { return 0.0 }

        let bigramsA = bigrams(a)
        let bigramsB = bigrams(b)

        if bigramsA.isEmpty || bigramsB.isEmpty {
            return a.first == b.first ? 0.5 : 0.0
        }

        let intersection = bigramsA.intersection(bigramsB).count
        return 2.0 * Double(intersection) / Double(bigramsA.count + bigramsB.count)
    }

    private func bigrams(_ s: String) -> Set<String> {
        let chars = Array(s)
        guard chars.count >= 2 else { return [] }
        return Set((0..<chars.count - 1).map { String(chars[$0]) + String(chars[$0 + 1]) })
    }

    // MARK: - Network

    private func makeRequest(url: URL) async throws -> (Data, URLResponse) {
        var request = URLRequest(url: url)
        request.setValue("SpotifyLyrics/1.0", forHTTPHeaderField: "User-Agent")
        return try await URLSession.shared.data(for: request)
    }

    // MARK: - Errors

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

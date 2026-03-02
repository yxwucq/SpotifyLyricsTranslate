import Foundation

actor TranslationCache {
    private var memoryCache: [String: [String]] = [:]
    private let cacheDir: URL

    init() {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            .appendingPathComponent("SpotifyLyrics/translations", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.cacheDir = dir
    }

    func get(trackId: String, language: String) -> [String]? {
        let key = "\(trackId)_\(language)"

        // Check memory cache
        if let cached = memoryCache[key] {
            return cached
        }

        // Check disk cache
        let file = cacheDir.appendingPathComponent("\(key).json")
        if let data = try? Data(contentsOf: file),
           let lines = try? JSONDecoder().decode([String].self, from: data) {
            memoryCache[key] = lines
            return lines
        }

        return nil
    }

    func set(trackId: String, language: String, translations: [String]) {
        let key = "\(trackId)_\(language)"
        memoryCache[key] = translations

        // Write to disk
        let file = cacheDir.appendingPathComponent("\(key).json")
        if let data = try? JSONEncoder().encode(translations) {
            try? data.write(to: file)
        }
    }
}

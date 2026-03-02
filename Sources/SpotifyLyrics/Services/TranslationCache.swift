import Foundation

actor TranslationCache {
    private var memoryCache: [String: [String]] = [:]
    private var cacheDir: URL

    init() {
        self.cacheDir = AppSettings.effectiveCacheDir
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
    }

    func updateCacheDir() {
        let newDir = AppSettings.effectiveCacheDir
        if newDir != cacheDir {
            cacheDir = newDir
            memoryCache.removeAll()
            try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        }
    }

    func get(trackId: String, language: String) -> [String]? {
        let key = "\(trackId)_\(language)"

        if let cached = memoryCache[key] {
            return cached
        }

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

        let file = cacheDir.appendingPathComponent("\(key).json")
        if let data = try? JSONEncoder().encode(translations) {
            try? data.write(to: file)
        }
    }

    func cacheSize() -> (fileCount: Int, totalBytes: Int64) {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: [.fileSizeKey]) else {
            return (0, 0)
        }
        var total: Int64 = 0
        var count = 0
        for file in files where file.pathExtension == "json" {
            count += 1
            if let attrs = try? fm.attributesOfItem(atPath: file.path),
               let size = attrs[.size] as? Int64 {
                total += size
            }
        }
        return (count, total)
    }

    func clearCache() {
        memoryCache.removeAll()
        let fm = FileManager.default
        if let files = try? fm.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: nil) {
            for file in files where file.pathExtension == "json" {
                try? fm.removeItem(at: file)
            }
        }
    }
}

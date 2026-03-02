import Foundation

enum LRCParser {
    // Parses LRC format: [mm:ss.xx] text
    static func parse(_ lrc: String) -> [LyricLine] {
        let pattern = #"\[(\d{1,3}):(\d{2})\.(\d{2,3})\]\s*(.*)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }

        var lines: [LyricLine] = []

        lrc.enumerateLines { line, _ in
            let range = NSRange(location: 0, length: line.utf16.count)
            let nsLine = line as NSString
            for match in regex.matches(in: line, range: range) {
                guard match.numberOfRanges >= 5 else { continue }
                let min = nsLine.substring(with: match.range(at: 1))
                let sec = nsLine.substring(with: match.range(at: 2))
                let ms  = nsLine.substring(with: match.range(at: 3))
                let text = nsLine.substring(with: match.range(at: 4))

                if let m = Int(min), let s = Int(sec), var millis = Int(ms) {
                    // Handle both .xx (centiseconds) and .xxx (milliseconds)
                    if ms.count == 2 { millis *= 10 }
                    let totalMs = (m * 60 + s) * 1000 + millis
                    lines.append(LyricLine(id: lines.count, timestampMs: totalMs, text: text))
                }
            }
        }

        return lines.sorted { $0.timestampMs < $1.timestampMs }
            .enumerated()
            .map { LyricLine(id: $0.offset, timestampMs: $0.element.timestampMs, text: $0.element.text, translation: nil) }
    }
}

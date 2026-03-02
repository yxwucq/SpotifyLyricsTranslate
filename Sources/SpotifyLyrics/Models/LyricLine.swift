import Foundation

struct LyricLine: Identifiable, Equatable {
    let id: Int              // line index
    let timestampMs: Int     // milliseconds from start
    let text: String         // original lyric text
    var translation: String? // translated text

    var isEmpty: Bool { text.trimmingCharacters(in: .whitespaces).isEmpty }
}

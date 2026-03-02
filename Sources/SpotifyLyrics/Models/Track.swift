import Foundation

struct Track: Equatable {
    let id: String        // Spotify track ID
    let name: String
    let artist: String
    let album: String
    let durationMs: Int

    var displayTitle: String {
        "\(name) — \(artist)"
    }
}

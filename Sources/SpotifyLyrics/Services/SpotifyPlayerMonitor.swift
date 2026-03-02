import AppKit
import Combine

@Observable
final class SpotifyPlayerMonitor {
    var currentTrack: Track?
    var positionMs: Int = 0
    var isPlaying: Bool = false

    private var pollTimer: Timer?
    private var interpolationTimer: Timer?
    private var lastPollTime: Date = .now
    private var lastPollPositionMs: Int = 0

    init() {
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(playbackStateChanged(_:)),
            name: NSNotification.Name("com.spotify.client.PlaybackStateChanged"),
            object: nil
        )
    }

    func startMonitoring() {
        fetchCurrentTrack()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.pollPosition()
        }
        interpolationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.interpolatePosition()
        }
    }

    func stopMonitoring() {
        pollTimer?.invalidate()
        pollTimer = nil
        interpolationTimer?.invalidate()
        interpolationTimer = nil
    }

    @objc private func playbackStateChanged(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            self?.fetchCurrentTrack()
        }
    }

    private func fetchCurrentTrack() {
        let script = """
        tell application "System Events"
            if not (exists process "Spotify") then return "NOT_RUNNING"
        end tell
        tell application "Spotify"
            if player state is not stopped then
                set tid to id of current track
                set tname to name of current track
                set tartist to artist of current track
                set talbum to album of current track
                set tdur to duration of current track
                set ppos to player position
                set pstate to player state
                return tid & "||" & tname & "||" & tartist & "||" & talbum & "||" & (tdur as text) & "||" & (ppos as text) & "||" & (pstate as text)
            else
                return "STOPPED"
            end if
        end tell
        """

        runAppleScript(script) { [weak self] result in
            guard let self, let result, result != "NOT_RUNNING", result != "STOPPED" else {
                DispatchQueue.main.async {
                    self?.currentTrack = nil
                    self?.isPlaying = false
                }
                return
            }
            let parts = result.components(separatedBy: "||")
            guard parts.count >= 7 else { return }

            let rawId = parts[0] // "spotify:track:XXXX"
            let trackId = rawId.replacingOccurrences(of: "spotify:track:", with: "")
            let durationMs = Int(parts[4]) ?? 0
            let posMs = Int(Double(parts[5]) ?? 0) * 1000
            let playing = parts[6] == "playing"

            let track = Track(id: trackId, name: parts[1], artist: parts[2], album: parts[3], durationMs: durationMs)

            DispatchQueue.main.async {
                let trackChanged = self.currentTrack?.id != track.id
                self.currentTrack = track
                self.positionMs = posMs
                self.isPlaying = playing
                self.lastPollTime = .now
                self.lastPollPositionMs = posMs

                if trackChanged {
                    NotificationCenter.default.post(name: .trackChanged, object: nil)
                }
            }
        }
    }

    private func pollPosition() {
        guard isPlaying else { return }
        let script = """
        tell application "Spotify"
            return (player position as text) & "||" & (player state as text)
        end tell
        """
        runAppleScript(script) { [weak self] result in
            guard let self, let result else { return }
            let parts = result.components(separatedBy: "||")
            guard parts.count >= 2 else { return }
            let posMs = Int((Double(parts[0]) ?? 0) * 1000)
            let playing = parts[1] == "playing"
            DispatchQueue.main.async {
                self.positionMs = posMs
                self.isPlaying = playing
                self.lastPollTime = .now
                self.lastPollPositionMs = posMs
            }
        }
    }

    private func interpolatePosition() {
        guard isPlaying else { return }
        let elapsed = Date.now.timeIntervalSince(lastPollTime)
        positionMs = lastPollPositionMs + Int(elapsed * 1000)
    }

    private func runAppleScript(_ source: String, completion: @escaping (String?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            var error: NSDictionary?
            let script = NSAppleScript(source: source)
            let result = script?.executeAndReturnError(&error)
            completion(result?.stringValue)
        }
    }
}

extension Notification.Name {
    static let trackChanged = Notification.Name("SpotifyLyrics.trackChanged")
}

import Foundation

/// What one player reported at a moment in time.
struct PlayerSnapshot: Equatable, Sendable {
    var isPlaying: Bool
    var title: String
    var artist: String
    var album: String
    /// Seconds; 0 when unknown (e.g. a stream).
    var duration: TimeInterval
    /// Seconds into the track at `capturedAt`; nil when the source didn't say.
    var position: TimeInterval?
    var capturedAt: Date
    /// Changes whenever the track does.
    var trackID: String
    /// Spotify only: where to download the cover.
    var artworkURL: URL?
}

extension PlayerSnapshot {
    /// Parses a playback notification. Returns nil when the player stopped.
    init?(notification userInfo: [AnyHashable: Any], app: MediaApp, at date: Date = .now) {
        guard let state = userInfo["Player State"] as? String, state != "Stopped" else { return nil }
        func text(_ key: String) -> String { userInfo[key] as? String ?? "" }
        func number(_ key: String) -> Double? { (userInfo[key] as? NSNumber)?.doubleValue }

        switch app {
        case .spotify:
            self.init(isPlaying: state == "Playing",
                      title: text("Name"), artist: text("Artist"), album: text("Album"),
                      duration: (number("Duration") ?? 0) / 1000,  // milliseconds
                      position: number("Playback Position"),
                      capturedAt: date,
                      trackID: text("Track ID"))
        case .music:
            // Same format AppleScript uses for `persistent ID`, so both sources agree.
            let persistentID = (userInfo["PersistentID"] as? NSNumber).map {
                String(format: "%016llX", UInt64(bitPattern: $0.int64Value))
            }
            self.init(isPlaying: state == "Playing",
                      title: text("Name"), artist: text("Artist"), album: text("Album"),
                      duration: (number("Total Time") ?? 0) / 1000,  // milliseconds
                      position: nil,  // Music doesn't include it
                      capturedAt: date,
                      trackID: persistentID ?? text("Name") + "\u{1F}" + text("Artist"))
        }
    }

    /// Parses the list returned by `MediaScripts.status`:
    /// {state, position, name, artist, album, duration, id, artwork url (Spotify)}.
    /// Returns nil when the player is stopped.
    init?(script value: ScriptValue, app: MediaApp, at date: Date = .now) {
        guard case .list(let items) = value, case .text(let state)? = items.first,
              ["playing", "paused", "fast forwarding", "rewinding"].contains(state) else { return nil }
        func text(_ index: Int) -> String {
            if items.indices.contains(index), case .text(let string) = items[index] { return string }
            return ""
        }
        func number(_ index: Int) -> Double? {
            if items.indices.contains(index), case .number(let number) = items[index] { return number }
            return nil
        }

        let duration = number(5) ?? 0
        self.init(isPlaying: state != "paused",
                  title: text(2), artist: text(3), album: text(4),
                  duration: app == .spotify ? duration / 1000 : duration,  // Spotify: milliseconds
                  position: number(1),
                  capturedAt: date,
                  trackID: text(6),
                  artworkURL: app == .spotify ? URL(string: text(7)) : nil)
    }
}

enum SourcePicker {
    /// Which player to show: playing beats paused, and among equals the most
    /// recently updated wins.
    static func pick<Source: Hashable>(_ candidates: [Source: (isPlaying: Bool, updatedAt: Date)]) -> Source? {
        candidates.max { a, b in
            if a.value.isPlaying != b.value.isPlaying { return !a.value.isPlaying }
            return a.value.updatedAt < b.value.updatedAt
        }?.key
    }
}

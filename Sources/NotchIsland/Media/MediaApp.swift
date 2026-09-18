import AppKit

/// The player apps NotchIsland follows. Both post a distributed notification on
/// every play, pause and track change, and both are scriptable.
enum MediaApp: String, CaseIterable, Sendable {
    case spotify = "com.spotify.client"
    case music = "com.apple.Music"

    var bundleID: String { rawValue }

    var name: String {
        switch self {
        case .spotify: "Spotify"
        case .music: "Music"
        }
    }

    /// Observing this needs no permission.
    var playbackNotification: Notification.Name {
        switch self {
        case .spotify: Notification.Name("com.spotify.client.PlaybackStateChanged")
        case .music: Notification.Name("com.apple.Music.playerInfo")
        }
    }

    var isRunning: Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty
    }
}

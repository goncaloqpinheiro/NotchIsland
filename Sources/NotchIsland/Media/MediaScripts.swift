import Foundation

enum MediaCommand: Sendable, Equatable {
    case togglePlayPause
    case next
    case previous
    case seek(TimeInterval)
}

/// AppleScript sources. Every script addresses its app by bundle ID and is only
/// run while the app is already running, since an Apple Event would launch it.
enum MediaScripts {
    /// One round trip for everything the island shows. See `PlayerSnapshot(script:)`.
    static func status(_ app: MediaApp) -> String {
        switch app {
        case .spotify:
            """
            with timeout of 3 seconds
                tell application id "com.spotify.client"
                    set playerState to player state as string
                    if playerState is "stopped" then return {playerState}
                    set t to current track
                    set artworkURL to ""
                    try
                        set artworkURL to artwork url of t
                    end try
                    return {playerState, player position, name of t, artist of t, album of t, duration of t, id of t, artworkURL}
                end tell
            end timeout
            """
        case .music:
            """
            with timeout of 3 seconds
                tell application id "com.apple.Music"
                    set playerState to player state as string
                    if playerState is "stopped" then return {playerState}
                    set t to current track
                    return {playerState, player position, name of t, artist of t, album of t, duration of t, persistent ID of t}
                end tell
            end timeout
            """
        }
    }

    /// Music hands over the cover itself (Spotify gives a URL in `status`).
    static let musicArtwork = """
        with timeout of 5 seconds
            tell application id "com.apple.Music" to return raw data of artwork 1 of current track
        end timeout
        """

    static func command(_ command: MediaCommand, app: MediaApp) -> String {
        let verb = switch command {
        case .togglePlayPause: "playpause"
        case .next: "next track"
        // Music's "back track" restarts the song first, like the media key.
        case .previous: app == .music ? "back track" : "previous track"
        case .seek(let seconds): "set player position to \(String(format: "%.2f", max(0, seconds)))"
        }
        return """
            with timeout of 3 seconds
                tell application id "\(app.bundleID)" to \(verb)
            end timeout
            """
    }

    /// Each window's tab URLs, tab titles and active tab index, front window
    /// first: three Apple Events per window, however many tabs are open.
    static func browserTabs(_ browser: Browser) -> String {
        let (titles, activeTab) = switch browser {
        case .chrome: ("title of tabs of w", "active tab index of w")
        case .safari: ("name of tabs of w", "index of current tab of w")
        }
        return """
            with timeout of 3 seconds
                tell application id "\(browser.bundleID)"
                    set windowTabs to {}
                    repeat with w in windows
                        try
                            set end of windowTabs to {URL of tabs of w, \(titles), \(activeTab)}
                        end try
                    end repeat
                    return windowTabs
                end tell
            end timeout
            """
    }

    /// Brings the tab showing `url` to the front.
    static func showTab(url: String, in browser: Browser) -> String {
        let escaped = url.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        let select = switch browser {
        case .chrome: "set active tab index of w to tabIndex"
        case .safari: "set current tab of w to tab tabIndex of w"
        }
        return """
            with timeout of 3 seconds
                tell application id "\(browser.bundleID)"
                    repeat with w in windows
                        try
                            set tabIndex to 0
                            repeat with tabURL in (URL of tabs of w)
                                set tabIndex to tabIndex + 1
                                if contents of tabURL is "\(escaped)" then
                                    \(select)
                                    set index of w to 1
                                    activate
                                    return
                                end if
                            end repeat
                        end try
                    end repeat
                    activate
                end tell
            end timeout
            """
    }

    /// Every script, for the compile-only self-check in `make snapshots`.
    static var all: [String] {
        let apps = MediaApp.allCases.flatMap { app in
            [status(app)] + [MediaCommand.togglePlayPause, .next, .previous, .seek(30)].map { command($0, app: app) }
        }
        let browsers = Browser.allCases.flatMap { browser in
            [browserTabs(browser), showTab(url: "https://www.youtube.com/watch?v=aqz-KE-bpKQ", in: browser)]
        }
        return apps + [musicArtwork] + browsers
    }
}

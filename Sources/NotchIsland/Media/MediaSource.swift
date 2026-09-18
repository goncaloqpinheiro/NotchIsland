import AppKit

/// A browser whose YouTube tabs can show as now playing.
enum Browser: String, CaseIterable, Sendable {
    case chrome = "com.google.Chrome"
    case safari = "com.apple.Safari"

    var bundleID: String { rawValue }

    var name: String {
        switch self {
        case .chrome: "Chrome"
        case .safari: "Safari"
        }
    }

    /// Whether a process belongs to this browser: Chrome works through helper
    /// processes, Safari through WebKit's (e.g. its GPU process plays the sound).
    func owns(bundleID id: String) -> Bool {
        switch self {
        case .chrome: id == bundleID || id.hasPrefix(bundleID + ".")
        case .safari: id == bundleID || id.hasPrefix("com.apple.WebKit.")
        }
    }
}

/// Where the island's now-playing information comes from.
enum MediaSource: Hashable, Sendable {
    case app(MediaApp)
    case browser(Browser)

    var bundleID: String {
        switch self {
        case .app(let app): app.bundleID
        case .browser(let browser): browser.bundleID
        }
    }

    var name: String {
        switch self {
        case .app(let app): app.name
        case .browser(let browser): browser.name
        }
    }

    var isRunning: Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty
    }
}

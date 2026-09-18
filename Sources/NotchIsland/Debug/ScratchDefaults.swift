import Foundation

/// Settings for the dev tools and the tests, kept apart from the app's own.
/// They live in a temporary folder instead of ~/Library/Preferences (a path as
/// the suite name keeps the file there), so nothing is left behind.
enum ScratchDefaults {
    private static let folder: URL = {
        let folder = FileManager.default.temporaryDirectory
            .appending(path: "NotchIsland-\(getpid())", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }()

    /// A fresh, empty settings store.
    static func make(_ name: String) -> UserDefaults {
        let defaults = reopen(name)
        defaults.removePersistentDomain(forName: path(name))
        return defaults
    }

    /// The same store again, the way a relaunched app would read it.
    static func reopen(_ name: String) -> UserDefaults {
        UserDefaults(suiteName: path(name))!
    }

    /// Deletes every store, folder included.
    static func removeAll() {
        try? FileManager.default.removeItem(at: folder)
    }

    private static func path(_ name: String) -> String {
        folder.appending(path: name).path
    }
}

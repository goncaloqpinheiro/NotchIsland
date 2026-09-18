import AppKit

/// Full Disk Access can't be requested with a prompt; the user adds the app in
/// System Settings. These open the right places.
@MainActor
enum FullDiskAccess {
    static func openSettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!)
    }

    /// Shows NotchIsland.app in Finder, to drag into the Full Disk Access list.
    static func revealApp() {
        NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL])
    }
}

import AppKit

/// Reports whether the notched display is showing a full-screen app. Checked
/// when the active Space changes (entering or leaving full screen switches
/// Spaces), so there's no polling.
@MainActor
final class FullScreenMonitor {
    var onChange: ((Bool) -> Void)?
    private(set) var isFullScreen = false
    private let displayID: () -> CGDirectDisplayID?
    private var observer: NSObjectProtocol?

    init(displayID: @escaping () -> CGDirectDisplayID?) {
        self.displayID = displayID
    }

    func start() {
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        refresh()
    }

    func refresh() {
        let fullScreen = displayID().map(SpaceInspector.isFullScreen(displayID:)) ?? false
        guard fullScreen != isFullScreen else { return }
        isFullScreen = fullScreen
        Log.notch.debug("Full screen: \(fullScreen, privacy: .public)")
        onChange?(fullScreen)
    }
}

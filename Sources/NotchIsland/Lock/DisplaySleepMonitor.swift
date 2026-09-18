import AppKit

/// Displays going to sleep and waking up (closing and opening the lid, idle
/// sleep, the Mac sleeping), announced by NSWorkspace; no permission needed.
@MainActor
final class DisplaySleepMonitor {
    var onSleep: (() -> Void)?
    var onWake: (() -> Void)?
    /// Whether the main display is asleep right now. Tests replace it, so they
    /// don't depend on the state of the Mac's own screen.
    var isAsleep: () -> Bool = { CGDisplayIsAsleep(CGMainDisplayID()) != 0 }
    private var observers: [NSObjectProtocol] = []

    func start() {
        let center = NSWorkspace.shared.notificationCenter
        observers = [
            center.addObserver(forName: NSWorkspace.screensDidSleepNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.onSleep?() }
            },
            center.addObserver(forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.onWake?() }
            },
        ]
    }
}

import AppKit

/// Streams cursor positions from event monitors instead of a timer, so it does
/// no work while the mouse is still. The global monitor sees moves delivered to
/// other apps; the local one sees moves delivered to this app. Mouse monitors
/// need no permission (only key monitors require Accessibility).
@MainActor
final class MouseTracker {
    /// Called with the cursor position in global screen coordinates.
    var onMove: ((CGPoint) -> Void)?
    private var monitors: [Any] = []

    func start() {
        guard monitors.isEmpty else { return refresh() }
        let events: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged]
        if let global = NSEvent.addGlobalMonitorForEvents(matching: events, handler: { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }) {
            monitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: events, handler: { [weak self] event in
            MainActor.assumeIsolated { self?.refresh() }
            return event
        }) {
            monitors.append(local)
        }
        refresh()
    }

    func stop() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors.removeAll()
    }

    /// Reports the current position now, e.g. after the layout changed under a still cursor.
    func refresh() {
        onMove?(NSEvent.mouseLocation)
    }
}

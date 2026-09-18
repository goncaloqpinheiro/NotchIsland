import AppKit
import SwiftUI

/// Shows the island on the lock screen, in a second window placed in a space
/// above it. Kept deliberately harmless: the window ignores the mouse, never
/// becomes key (so it can't take focus from the password field), covers only
/// the top of the screen around the notch, and exists only from lock until the
/// unlock animation ends.
@MainActor
final class LockScreenMirror {
    private let model: NotchViewModel
    private let space = LockScreenSpace()
    private var panel: NotchPanel?
    private(set) var isShowing = false

    init(model: NotchViewModel) {
        self.model = model
    }

    func show() {
        guard LockScreenSpace.isAvailable, let geometry = NotchGeometry.current() else { return }
        let panel = self.panel ?? makePanel()
        if panel.contentView == nil {
            panel.contentView = makeHost()
        }
        panel.setFrame(geometry.rect(for: NotchWindowController.canvasSize), display: true)
        panel.orderFrontRegardless()
        isShowing = space.add(panel)
        if !isShowing {
            panel.orderOut(nil)
        }
        Log.notch.info("Lock screen copy \(self.isShowing ? "shown" : "unavailable", privacy: .public)")
    }

    func hide() {
        panel?.orderOut(nil)
        // Drop the copy's content, so it doesn't keep following the island (and
        // redrawing countdowns) while nobody can see it.
        panel?.contentView = nil
        isShowing = false
    }

    private func makePanel() -> NotchPanel {
        let panel = NotchPanel()  // ignores mouse events and never becomes key
        self.panel = panel
        return panel
    }

    private func makeHost() -> NSView {
        let host = NSHostingView(rootView: NotchRootView(model: model, actions: NowPlayingActions()))
        host.sizingOptions = []
        return host
    }
}

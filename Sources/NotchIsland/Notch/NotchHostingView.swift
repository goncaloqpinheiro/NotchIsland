import AppKit
import SwiftUI

/// Hosts the SwiftUI notch content inside the panel.
final class NotchHostingView<Content: View>: NSHostingView<Content> {
    var contextMenu: NSMenu?
    var onMouseDown: (() -> Void)?

    // The panel is never key; make the first click act instead of just focusing the window.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        onMouseDown?()
        super.mouseDown(with: event)  // SwiftUI still gets the click (buttons, gestures)
    }

    override func rightMouseDown(with event: NSEvent) {
        guard let contextMenu else { return super.rightMouseDown(with: event) }
        NSMenu.popUpContextMenu(contextMenu, with: event, for: self)
    }
}

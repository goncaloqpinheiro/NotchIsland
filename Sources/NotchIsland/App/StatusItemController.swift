import AppKit

/// Menu bar icon whose menu holds Quit (and later, settings).
@MainActor
final class StatusItemController {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

    init(menu: NSMenu) {
        if let button = statusItem.button {
            let image = NSImage(systemSymbolName: "rectangle.topthird.inset.filled",
                                accessibilityDescription: "NotchIsland")
            image?.isTemplate = true
            button.image = image
        }
        statusItem.menu = menu
    }
}

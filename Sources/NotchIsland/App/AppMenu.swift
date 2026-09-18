import AppKit

/// Builds the menu used by both the status item and a right-click on the notch.
@MainActor
final class AppMenu: NSObject, NSMenuDelegate {
    private let onOpenSettings: () -> Void
    private let timerMenu: TimerMenu
    /// Focus is on in Settings but macOS hasn't given access to the Focus files yet.
    private let needsFocusAccess: () -> Bool
    private static let focusAccessTag = 1

    init(onOpenSettings: @escaping () -> Void, timerMenu: TimerMenu, needsFocusAccess: @escaping () -> Bool = { false }) {
        self.onOpenSettings = onOpenSettings
        self.timerMenu = timerMenu
        self.needsFocusAccess = needsFocusAccess
    }

    func makeMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self

        let header = NSMenuItem(title: "NotchIsland", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(.separator())

        let focusAccess = NSMenuItem(title: "Turn On Focus Alerts…", action: #selector(openFullDiskAccess), keyEquivalent: "")
        focusAccess.target = self
        focusAccess.tag = Self.focusAccessTag
        focusAccess.isHidden = !needsFocusAccess()
        menu.addItem(focusAccess)

        menu.addItem(timerMenu.makeItem())
        menu.addItem(.separator())

        let settings = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)
        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit NotchIsland", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quit.target = NSApp
        menu.addItem(quit)
        return menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.item(withTag: Self.focusAccessTag)?.isHidden = !needsFocusAccess()
    }

    @objc private func openSettings() {
        onOpenSettings()
    }

    @objc private func openFullDiskAccess() {
        FullDiskAccess.openSettings()
    }
}

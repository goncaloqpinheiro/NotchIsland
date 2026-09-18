import AppKit
import SwiftUI

/// The Settings window, with one toolbar tab per area.
@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    enum Tab: Int {
        case notch, indicators, clock
    }

    private let settings: AppSettings
    private let model: NotchViewModel
    /// Called whenever Settings comes forward, to re-check permissions and shortcuts added meanwhile.
    private let onShow: () -> Void
    private let onCheckClockControls: () -> Void
    /// Built on first use.
    private(set) lazy var window: NSWindow = makeWindow()

    init(settings: AppSettings, model: NotchViewModel, onShow: @escaping () -> Void = {},
         onCheckClockControls: @escaping () -> Void = {}) {
        self.settings = settings
        self.model = model
        self.onShow = onShow
        self.onCheckClockControls = onCheckClockControls
    }

    func show(tab: Tab? = nil) {
        onShow()
        model.isCalibrating = true
        if let tab {
            (window.contentViewController as? NSTabViewController)?.selectedTabViewItemIndex = tab.rawValue
        }
        // A menu-bar-only app isn't active, so the window would open behind others.
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    func windowDidBecomeKey(_ notification: Notification) {
        onShow()
    }

    func windowWillClose(_ notification: Notification) {
        model.isCalibrating = false
        // Hand focus back to the app that had it before Settings opened.
        NSApp.deactivate()
    }

    private func makeWindow() -> NSWindow {
        let tabs = NSTabViewController()
        tabs.tabStyle = .toolbar
        tabs.addTabViewItem(tab("Notch", symbol: "rectangle.topthird.inset.filled",
                                pane: NotchSettingsPane(settings: settings, model: model)))
        tabs.addTabViewItem(tab("Indicators", symbol: "speaker.wave.2",
                                pane: IndicatorsSettingsPane(settings: settings, model: model)))
        tabs.addTabViewItem(tab("Clock", symbol: "timer",
                                pane: ClockSettingsPane(timer: model.timer, stopwatch: model.stopwatch,
                                                        onCheckAgain: onCheckClockControls)))

        let window = SettingsWindow(contentRect: .zero,
                                    styleMask: [.titled, .closable],
                                    backing: .buffered,
                                    defer: false)
        window.contentViewController = tabs
        window.toolbarStyle = .preference
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        return window
    }

    private func tab(_ label: String, symbol: String, pane: some View) -> NSTabViewItem {
        let host = NSHostingController(rootView: pane)
        host.sizingOptions = .preferredContentSize
        let item = NSTabViewItem(viewController: host)
        item.label = label
        item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: label)
        return item
    }
}

/// Closes on ⌘W, which would otherwise need a main menu the app doesn't have.
private final class SettingsWindow: NSWindow {
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command,
           event.charactersIgnoringModifiers == "w" {
            performClose(nil)
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}

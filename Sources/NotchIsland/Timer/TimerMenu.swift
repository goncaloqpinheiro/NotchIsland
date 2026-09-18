import AppKit

/// The Timer submenu, shared by the menu bar icon and a right-click on the
/// notch. Rebuilt each time it opens, so it matches Clock's timer.
@MainActor
final class TimerMenu: NSObject, NSMenuDelegate {
    private let timer: TimerModel
    private let controller: TimerController
    private let onSetUp: () -> Void

    init(timer: TimerModel, controller: TimerController, onSetUp: @escaping () -> Void) {
        self.timer = timer
        self.controller = controller
        self.onSetUp = onSetUp
    }

    func makeItem() -> NSMenuItem {
        let item = NSMenuItem(title: "Timer", action: nil, keyEquivalent: "")
        item.image = NSImage(systemSymbolName: "timer", accessibilityDescription: nil)
        let submenu = NSMenu(title: "Timer")
        submenu.delegate = self
        item.submenu = submenu
        rebuild(submenu)
        return item
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        rebuild(menu)
    }

    private func rebuild(_ menu: NSMenu) {
        menu.removeAllItems()
        let name = timer.title ?? "Timer"
        switch timer.phase {
        case .running, .paused:
            let remaining = TimerFormat.clock(timer.remaining())
            menu.addItem(disabled(timer.isPaused ? "\(name) paused, \(remaining) left" : "\(name): \(remaining) left"))
            if timer.canToggle {
                menu.addItem(timer.isPaused ? item("Resume", #selector(resume)) : item("Pause", #selector(pause)))
            }
            if timer.canCancel {
                menu.addItem(item("Cancel Timer", #selector(cancel)))
            }
            menu.addItem(.separator())
        case .done:
            menu.addItem(disabled("\(name) done"))
            menu.addItem(item("Stop", #selector(stop)))
            if timer.canStart {
                menu.addItem(item("Repeat", #selector(repeatLast)))
            }
            menu.addItem(.separator())
        case .idle:
            break
        }
        if timer.canStart {
            if timer.phase != .idle {
                menu.addItem(disabled("New Timer"))
            }
            for minutes in TimerFormat.presetMinutes {
                let preset = item(TimerFormat.spoken(TimeInterval(minutes * 60)), #selector(startPreset(_:)))
                preset.tag = minutes * 60
                menu.addItem(preset)
            }
            menu.addItem(item("Custom…", #selector(startCustom)))
            menu.addItem(.separator())
        }
        menu.addItem(item("Open Clock", #selector(openClock)))
        if timer.controls != Set(TimerCommand.allCases) {
            menu.addItem(item("Set Up Timer Controls…", #selector(setUp)))
        }
    }

    private func item(_ title: String, _ action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    private func disabled(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    @objc private func startPreset(_ sender: NSMenuItem) {
        controller.start(TimeInterval(sender.tag))
    }

    @objc private func startCustom() {
        if let duration = CustomTimerPrompt.run() {
            controller.start(duration)
        }
    }

    @objc private func pause() { controller.pause() }
    @objc private func resume() { controller.resume() }
    @objc private func cancel() { controller.cancel() }
    @objc private func stop() { controller.stop() }
    @objc private func repeatLast() { controller.repeatLast() }
    @objc private func openClock() { controller.actions.openClock() }
    @objc private func setUp() { onSetUp() }
}

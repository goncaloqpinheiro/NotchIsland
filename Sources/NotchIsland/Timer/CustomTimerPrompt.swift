import AppKit

/// Asks for a custom timer length. The island can't take typing (it never
/// becomes key, so it can't steal focus), so this is a small dialog instead.
@MainActor
enum CustomTimerPrompt {
    static func run() -> TimeInterval? {
        let alert = NSAlert()
        alert.messageText = "Custom Timer"
        alert.informativeText = "How long? For example 25 (minutes), 1:30 (a minute and a half) or 1h 15m."
        alert.addButton(withTitle: "Start")
        alert.addButton(withTitle: "Cancel")
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 24))
        field.placeholderString = "25"
        alert.accessoryView = field
        alert.window.initialFirstResponder = field

        // A menu bar app isn't active, so the dialog would open behind other windows.
        NSApp.activate()
        defer { NSApp.deactivate() }
        while alert.runModal() == .alertFirstButtonReturn {
            if let duration = TimerFormat.parse(field.stringValue) {
                return duration
            }
            NSSound.beep()
            alert.informativeText = "That isn't a length NotchIsland understands. Try 25, 1:30 or 1h 15m (up to 24 hours)."
        }
        return nil
    }
}

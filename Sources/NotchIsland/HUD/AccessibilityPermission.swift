import AppKit
import ApplicationServices

/// Intercepting the volume and brightness keys needs Accessibility access.
enum AccessibilityPermission {
    static var isGranted: Bool {
        AXIsProcessTrusted()
    }

    /// macOS's "allow Accessibility" alert, which links to System Settings.
    static func request() {
        _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
    }

    static func openSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Posted system-wide when the Accessibility list changes.
    static let changedNotification = Notification.Name("com.apple.accessibility.api")
}

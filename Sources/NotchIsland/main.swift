import AppKit

// Top-level code runs on the main thread, but Swift 5 mode doesn't treat it as
// main-actor isolated, so say so explicitly.
MainActor.assumeIsolated {
    let app = NSApplication.shared
    if DebugSnapshots.runIfRequested() || DocsImages.runIfRequested() || DocsDemo.runIfRequested()
        || FocusDiagnostics.runIfRequested() || GlassPreview.runIfRequested() {
        exit(0)
    }
    let delegate = AppDelegate()
    app.delegate = delegate
    // LSUIElement in Info.plist hides the Dock icon; this keeps it hidden even
    // if the raw binary is launched outside the .app bundle.
    app.setActivationPolicy(.accessory)
    // NSApplication holds its delegate weakly.
    withExtendedLifetime(delegate) {
        app.run()
    }
}

import AppKit
import SwiftUI

/// Dev tool: `NotchIsland --glass-preview` (or `make glass-preview`) shows
/// Natural and Adaptive glass side by side over colorful backgrounds, for 20
/// seconds. The window server draws the glass, which snapshots can't capture,
/// so this is the way to see and tune it. Uses the Strength from Settings.
@MainActor
enum GlassPreview {
    static let size = CGSize(width: 640, height: 340)

    static func runIfRequested() -> Bool {
        guard CommandLine.arguments.contains("--glass-preview"), let screen = NSScreen.main else { return false }
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let strength = AppSettings().blurStrength
        let origin = CGPoint(x: screen.frame.midX - size.width / 2, y: screen.frame.midY - size.height / 2)
        // The backgrounds in one window, the glass in another above it: the
        // glass blurs what's behind its own window, as the island's does.
        let backgrounds = window(PreviewBackgrounds(), at: origin, level: .floating, opaque: true)
        let glass = window(PreviewSamples(strength: strength), at: origin, level: NSWindow.Level(NSWindow.Level.floating.rawValue + 1), opaque: false)
        withExtendedLifetime((backgrounds, glass)) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 20) { app.terminate(nil) }
            app.run()
        }
        return true
    }

    private static func window(_ content: some View, at origin: CGPoint, level: NSWindow.Level, opaque: Bool) -> NSPanel {
        let panel = NSPanel(contentRect: CGRect(origin: origin, size: size), styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        panel.level = level
        panel.isOpaque = opaque
        panel.backgroundColor = opaque ? .black : .clear
        panel.hasShadow = false
        panel.contentView = NSHostingView(rootView: content.frame(width: size.width, height: size.height))
        panel.orderFrontRegardless()
        return panel
    }
}

/// Two rows of vivid backgrounds, the same under both columns.
private struct PreviewBackgrounds: View {
    var body: some View {
        VStack(spacing: 0) {
            row(LinearGradient(colors: [.orange, .pink, .purple], startPoint: .leading, endPoint: .trailing))
            row(LinearGradient(colors: [.teal, .blue, .green], startPoint: .leading, endPoint: .trailing))
        }
    }

    private func row(_ gradient: LinearGradient) -> some View {
        HStack(spacing: 0) {
            gradient
            gradient
        }
    }
}

/// An island on each background: Natural glass on the left, Adaptive on the right.
private struct PreviewSamples: View {
    let strength: Double

    var body: some View {
        VStack(spacing: 0) {
            row
            row
        }
    }

    private var row: some View {
        HStack(spacing: 0) {
            sample("Natural", adapts: false)
            sample("Adaptive", adapts: true)
        }
    }

    private func sample(_ title: String, adapts: Bool) -> some View {
        let island = CGSize(width: 200, height: 60)
        let spread = IslandGlass.frosted.spread
        return ZStack {
            IslandBackdrop(glass: .frosted, strength: strength, cornerRadius: 22 + spread, adapts: adapts)
                .frame(width: island.width + 2 * spread, height: island.height + 2 * spread)
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.black)
                .frame(width: island.width, height: island.height)
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

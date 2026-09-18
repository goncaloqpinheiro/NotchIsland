import AppKit
import SwiftUI

/// Hosts a view offscreen and moves SwiftUI's clock on one frame at a time, so
/// every animation is captured evenly, however long a frame takes to draw.
/// The renderer draws in software, which keeps blurs and glows in the capture.
@MainActor
final class FrameStepper {
    private let host: NSHostingView<AnyView>
    private let window: NSWindow

    init(_ view: some View, size: CGSize) {
        host = NSHostingView(rootView: AnyView(view))
        var options = _RendererConfiguration.RasterizationOptions()
        options.rendersAsynchronously = false
        options.isOpaque = true
        host._rendererConfiguration = .rasterized(options)
        host.frame = CGRect(origin: .zero, size: size)
        // Far off any screen: it has to be in a window to draw, not to be seen.
        window = NSWindow(contentRect: CGRect(origin: CGPoint(x: -30_000, y: -30_000), size: size),
                          styleMask: .borderless, backing: .buffered, defer: false)
        window.contentView = host
        window.orderFrontRegardless()
        host._renderForTest(interval: 0)
    }

    /// Moves the clock on by `interval` and returns the frame, at the screen's scale.
    func step(by interval: TimeInterval) -> CGImage? {
        host._renderForTest(interval: interval)
        guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return nil }
        host.cacheDisplay(in: host.bounds, to: rep)
        return rep.cgImage
    }

    func close() {
        window.orderOut(nil)
    }
}

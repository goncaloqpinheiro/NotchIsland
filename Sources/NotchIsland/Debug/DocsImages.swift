import AppKit
import SwiftUI

/// Dev tool: `NotchIsland --docs-images <dir>` (or `make docs-images`) renders the
/// README's pictures: island states over a wallpaper and a menu bar, the way they
/// look at the top of a Mac's screen. The wallpaper is an original gradient, and
/// the renders use their own settings, so they don't depend on this Mac's setup.
@MainActor
enum DocsImages {
    static func runIfRequested() -> Bool {
        let args = CommandLine.arguments
        guard let flag = args.firstIndex(of: "--docs-images"), args.indices.contains(flag + 1) else {
            return false
        }
        let dir = URL(fileURLWithPath: args[flag + 1], isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let defaults = ScratchDefaults.make("docs-images")
        defer { ScratchDefaults.removeAll() }
        let settings = AppSettings(defaults: defaults)
        settings.notchWidthOffset = 12  // a calibrated 15" MacBook Air
        let nowPlaying = NowPlayingModel()
        let timer = TimerModel()
        let stopwatch = StopwatchModel()
        let model = NotchViewModel(settings: settings, nowPlaying: nowPlaying, timer: timer, stopwatch: stopwatch)
        model.detectedNotchSize = CGSize(width: 156, height: 32)

        func render(_ name: String, height: CGFloat, width: CGFloat = DocsFrame.fullWidth) {
            save(DocsFrame(model: model, width: width, height: height), to: dir.appending(path: "\(name).png"))
        }
        let pair = DocsFrame.pairWidth

        // Music
        nowPlaying.apply(source: .app(.spotify), snapshot: PlayerSnapshot(
            isPlaying: true, title: "Golden Hour", artist: "Seaside Club", album: "Summer Tapes",
            duration: 214, position: 83, capturedAt: .now, trackID: "docs"))
        nowPlaying.setArtwork(artwork(), accent: NSColor(hue: 0.9, saturation: 0.55, brightness: 1, alpha: 1))
        render("now-playing", height: 76)
        model.state = .expanded
        settings.glassTint = GlassTint(red: 0.62, green: 0.45, blue: 1.0)
        render("hero", height: 214)
        model.state = .peeking
        render("glass-color", height: 120)
        settings.glassTint = nil
        model.state = .collapsed

        // Timer and stopwatch, with the music moving to the bubble
        timer.controls = Set(TimerCommand.allCases)
        timer.show(.running(endDate: .now.addingTimeInterval(12 * 60 - 1)), duration: 720)
        render("timer", height: 76, width: pair)
        nowPlaying.apply(source: nil, snapshot: nil)
        model.state = .expanded
        timer.show(.running(endDate: .now.addingTimeInterval(4 * 60 + 59)), duration: 300)
        render("timer-open", height: 128, width: pair)
        model.state = .collapsed
        timer.show(.done, duration: 300)
        render("timer-done", height: 128, width: pair)
        timer.show(.idle, duration: 0)
        stopwatch.show(.running(start: .now.addingTimeInterval(-(3 * 60 + 42))))
        render("stopwatch", height: 76, width: pair)
        stopwatch.show(.idle)

        // AirPods
        let airPods = HeadphonesInfo(name: "AirPods Pro", productID: 0x2014, left: 85, right: 80, chargingCase: 60)
        model.alert = .headphones(airPods, isCompact: false)
        render("airpods", height: 150, width: pair)
        model.alert = .headphones(airPods, isCompact: true)
        render("airpods-pill", height: 76, width: pair)

        // Focus, volume, battery
        model.alert = .focus(FocusAlert(mode: .builtIn("com.apple.donotdisturb.mode.default"), isOn: true))
        render("focus", height: 76)
        model.alert = .power(.charging(level: 82))
        render("battery", height: 76)
        model.alert = nil
        model.hud = NotchViewModel.HUD(kind: .volume, level: 0.6)
        render("volume", height: 76)
        model.hud = nil

        // Lock
        model.lockIndicator = NotchViewModel.LockIndicator()
        render("lock", height: 100, width: pair)
        model.lockIndicator = NotchViewModel.LockIndicator(isUnlocked: true, placement: .leading)
        render("lock-side", height: 76, width: pair)
        model.lockIndicator = nil
        return true
    }

    /// Stand-in album art: abstract, and ours.
    static func artwork() -> NSImage {
        NSImage(size: NSSize(width: 160, height: 160), flipped: false) { rect in
            NSGradient(colors: [NSColor(red: 1.0, green: 0.55, blue: 0.35, alpha: 1),
                                NSColor(red: 0.85, green: 0.25, blue: 0.55, alpha: 1),
                                NSColor(red: 0.35, green: 0.25, blue: 0.75, alpha: 1)])?.draw(in: rect, angle: -60)
            NSColor(white: 1, alpha: 0.85).setFill()
            NSBezierPath(ovalIn: NSRect(x: 52, y: 64, width: 56, height: 56)).fill()
            return true
        }
    }

    private static func save(_ view: some View, to url: URL) {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        guard let image = renderer.cgImage,
              let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]),
              (try? png.write(to: url)) != nil else {
            return print("Failed to render \(url.lastPathComponent)")
        }
        print("Wrote \(url.path)")
    }
}

/// The top of a Mac's screen: wallpaper, menu bar, and the island.
private struct DocsFrame: View {
    /// The README column is about 830 px wide: full width pictures show near
    /// actual size, and the narrower ones stay legible two to a table row.
    nonisolated static let fullWidth: CGFloat = 720
    nonisolated static let pairWidth: CGFloat = 440

    let model: NotchViewModel
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        ZStack(alignment: .top) {
            DocsWallpaper()
            // Cropped, the menu items would be cut off on one side only.
            DocsMenuBar(height: model.notchSize.height, showsItems: width == Self.fullWidth)
            NotchRootView(model: model, actions: NowPlayingActions())
                .environment(\.isRenderingSnapshot, true)
                .frame(width: Self.fullWidth, height: 300, alignment: .top)
        }
        .frame(width: Self.fullWidth, height: height, alignment: .top)
        .frame(width: width)  // narrower pictures keep the middle
        .clipped()
    }
}

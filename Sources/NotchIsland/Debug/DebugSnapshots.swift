import AppKit
import SwiftUI

/// Dev tool: `NotchIsland --snapshots <dir>` (or `make snapshots`) renders the
/// island states and the Settings pane to PNGs, then exits, so layouts can be
/// checked without screen recording permission.
@MainActor
enum DebugSnapshots {
    static func runIfRequested() -> Bool {
        let args = CommandLine.arguments
        guard let flag = args.firstIndex(of: "--snapshots"), args.indices.contains(flag + 1) else {
            return false
        }
        let dir = URL(fileURLWithPath: args[flag + 1], isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let settings = AppSettings()
        let nowPlaying = NowPlayingModel()
        let timer = TimerModel()
        let stopwatch = StopwatchModel()
        let model = NotchViewModel(settings: settings, nowPlaying: nowPlaying, timer: timer, stopwatch: stopwatch)
        model.detectedNotchSize = NotchGeometry.current()?.notchSize ?? CGSize(width: 156, height: 28)
        func island(_ name: String) {
            renderIsland(model, to: dir.appending(path: "\(name).png"))
        }

        island("island-collapsed")
        model.isCalibrating = true
        island("island-calibrating")
        model.isCalibrating = false
        model.state = .peeking
        island("island-peeking")
        // A colored glass, then back to whatever this Mac has set.
        let savedTint = settings.glassTint
        settings.glassTint = GlassTint(red: 1, green: 0.35, blue: 0.65)
        island("island-peeking-tinted")
        settings.glassTint = savedTint
        model.state = .expanded
        island("island-expanded-idle")
        nowPlaying.setPermissionDenied(true, for: .app(.spotify))
        island("island-expanded-denied")
        nowPlaying.setPermissionDenied(false, for: .app(.spotify))
        model.state = .collapsed
        model.lockIndicator = NotchViewModel.LockIndicator()
        island("lock-locked")
        model.lockIndicator?.placement = .leading
        island("lock-locked-left")
        model.lockIndicator = NotchViewModel.LockIndicator(isUnlocked: true)
        island("lock-unlocked")
        model.lockIndicator?.placement = .leading
        island("lock-unlocked-left")
        model.lockIndicator = nil
        model.hud = NotchViewModel.HUD(kind: .volume, level: 0.6)
        island("hud-volume")
        model.hud = NotchViewModel.HUD(kind: .brightness, level: 0.3)
        island("hud-brightness")
        model.hud = NotchViewModel.HUD(kind: .volume, level: 0.5, isMuted: true)
        island("hud-muted")
        model.hud = nil
        model.alert = .power(.charging(level: 82))
        island("alert-charging")
        model.alert = .power(.low(level: 18))
        island("alert-low-battery")
        let airPods = HeadphonesInfo(name: "AirPods de Gonçalo", productID: 0x2019, left: 80, right: 85, chargingCase: 60)
        model.alert = .headphones(airPods, isCompact: false)
        island("alert-airpods")
        model.alert = .headphones(airPods, isCompact: true)
        island("alert-airpods-compact")
        let airPodsMax = HeadphonesInfo(name: "AirPods Max", productID: 0x200A, single: 18)
        model.alert = .headphones(airPodsMax, isCompact: false)
        island("alert-airpods-max")
        model.alert = .headphones(airPodsMax, isCompact: true)
        island("alert-airpods-max-compact")
        let other = HeadphonesInfo(name: "Sony WH-1000XM5", productID: 0)
        model.alert = .headphones(other, isCompact: false)
        island("alert-other-headphones")
        model.alert = .headphones(other, isCompact: true)
        island("alert-other-headphones-compact")
        model.alert = .focus(FocusAlert(mode: .builtIn("com.apple.donotdisturb.mode.default"), isOn: true))
        island("focus-dnd-on")
        model.alert = .focus(FocusAlert(mode: .builtIn("com.apple.donotdisturb.mode.default"), isOn: false))
        island("focus-dnd-off")
        model.alert = .focus(FocusAlert(mode: .builtIn("com.apple.focus.work"), isOn: true))
        island("focus-work-on")
        model.alert = .focus(FocusAlert(mode: FocusMode(identifier: "custom", name: "Gym", symbol: "flame", tintName: "systemOrangeColor"), isOn: true))
        island("focus-custom-on")
        model.alert = nil

        timer.controls = Set(TimerCommand.allCases)
        timer.show(.running(endDate: .now.addingTimeInterval(5 * 60 - 1)), duration: 300)
        island("timer-compact")
        model.state = .expanded
        island("timer-expanded")
        timer.show(.paused(remaining: 299), duration: 300)
        island("timer-expanded-paused")
        timer.controls = []
        timer.show(.running(endDate: .now.addingTimeInterval(5 * 60 - 1)), duration: 300, title: "Pasta")
        island("timer-expanded-no-controls")
        timer.controls = Set(TimerCommand.allCases)
        model.state = .collapsed
        timer.show(.paused(remaining: 299), duration: 300)
        island("timer-compact-paused")
        timer.show(.running(endDate: .now.addingTimeInterval(3600 + 2 * 60 + 3)), duration: 3723)
        island("timer-compact-hours")
        timer.show(.done, duration: 300)
        island("timer-done")
        timer.controls = []
        island("timer-done-no-controls")
        timer.controls = Set(TimerCommand.allCases)
        timer.show(.idle, duration: 0)

        stopwatch.show(.running(start: .now.addingTimeInterval(-(2 * 60 + 7))), lapCount: 0)
        island("stopwatch-compact")
        stopwatch.show(.paused(elapsed: 3600 + 4 * 60 + 9.87), lapCount: 2)
        island("stopwatch-compact-paused")
        model.state = .expanded
        island("stopwatch-expanded-paused-no-controls")
        stopwatch.controls = Set(StopwatchCommand.allCases)
        stopwatch.show(.running(start: .now.addingTimeInterval(-(42.6))), lapCount: 1)
        island("stopwatch-expanded")
        model.state = .collapsed
        stopwatch.show(.idle)
        stopwatch.controls = []

        nowPlaying.apply(source: .app(.spotify), snapshot: PlayerSnapshot(
            isPlaying: true, title: "Midnight City", artist: "M83", album: "Hurry Up, We're Dreaming",
            duration: 243, position: 71, capturedAt: .now, trackID: "preview"))
        nowPlaying.setArtwork(previewArtwork(), accent: NSColor(hue: 0.83, saturation: 0.6, brightness: 0.95, alpha: 1))
        model.state = .collapsed
        island("media-live-activity")
        model.state = .peeking
        island("media-peeking")
        model.state = .expanded
        island("media-expanded")
        timer.show(.running(endDate: .now.addingTimeInterval(12 * 60)), duration: 720)
        island("media-expanded-with-timer")
        model.state = .collapsed
        island("media-with-timer-bubble")
        model.state = .peeking
        island("media-with-timer-bubble-peeking")
        timer.show(.idle, duration: 0)
        stopwatch.show(.running(start: .now.addingTimeInterval(-75)))
        island("media-with-stopwatch-bubble")
        stopwatch.show(.idle)
        checkScripts()
        save(BackdropBlurView.featheredMask.cgImage(forProposedRect: nil, context: nil, hints: nil),
             to: dir.appending(path: "backdrop-mask.png"))
        renderSettings(NotchSettingsPane(settings: settings, model: model), to: dir.appending(path: "settings-notch.png"))
        renderSettings(IndicatorsSettingsPane(settings: settings, model: model), to: dir.appending(path: "settings-indicators.png"))
        timer.controls = [.pause, .cancel]
        stopwatch.controls = [.stop]
        renderSettings(ClockSettingsPane(timer: timer, stopwatch: stopwatch, onCheckAgain: {}), to: dir.appending(path: "settings-clock.png"))
        let settingsWindow = SettingsWindowController(settings: settings, model: model).window
        render(settingsWindow.contentView?.superview, to: dir.appending(path: "settings-window.png"))
        return true
    }

    private static func renderIsland(_ model: NotchViewModel, to url: URL) {
        let view = NotchRootView(model: model, actions: NowPlayingActions())
            .environment(\.isRenderingSnapshot, true)
            .frame(width: NotchWindowController.canvasSize.width, height: NotchWindowController.canvasSize.height)
            .background(Color(white: 0.82))  // stand-in for a light menu bar and wallpaper
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        save(renderer.cgImage, to: url)
    }

    /// Settings uses AppKit-backed controls, which ImageRenderer can't draw,
    /// so render it through an offscreen window instead.
    private static func renderSettings(_ pane: some View, to url: URL) {
        let host = NSHostingView(rootView: pane)
        let window = NSWindow(contentRect: CGRect(origin: .zero, size: host.fittingSize),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = host
        render(host, to: url)
    }

    /// Draws a view hierarchy that lives in a window that is never shown.
    private static func render(_ view: NSView?, to url: URL) {
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.3))  // let SwiftUI finish its first pass
        guard let view else { return save(nil, to: url) }
        view.layoutSubtreeIfNeeded()
        guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
            return save(nil, to: url)
        }
        view.cacheDisplay(in: view.bounds, to: rep)
        save(rep.cgImage, to: url)
    }

    private static func previewArtwork() -> NSImage {
        NSImage(size: NSSize(width: 120, height: 120), flipped: false) { rect in
            NSGradient(colors: [.systemPink, .systemIndigo])?.draw(in: rect, angle: -45)
            return true
        }
    }

    /// Compiles every media script without running it (no Apple Events are sent).
    private static func checkScripts() {
        let failures = MediaScripts.all.filter { source in
            var error: NSDictionary?
            let compiled = NSAppleScript(source: source)?.compileAndReturnError(&error) ?? false
            if !compiled {
                print("Script failed to compile: \(error ?? [:])\n\(source)")
            }
            return !compiled
        }
        print(failures.isEmpty ? "All \(MediaScripts.all.count) media scripts compile" : "\(failures.count) scripts failed to compile")
    }

    private static func save(_ image: CGImage?, to url: URL) {
        guard let image,
              let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]),
              (try? png.write(to: url)) != nil else {
            return print("Failed to render \(url.lastPathComponent)")
        }
        print("Wrote \(url.path)")
    }
}

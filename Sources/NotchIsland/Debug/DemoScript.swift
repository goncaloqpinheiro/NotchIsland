import SwiftUI

/// Everything the rendered demo shows: the island's model, plus the pointer and
/// the captions around it.
@MainActor @Observable
final class DemoStage {
    let model: NotchViewModel
    /// Seconds since the demo began; drives the parts that move on their own.
    var time: TimeInterval = 0
    var caption: DemoCaption?
    /// The pointer's tip, from the top center of the screen.
    var pointer = CGPoint(x: 170, y: 150)
    var showsPointer = false
    var isClicking = false

    init() {
        let settings = AppSettings(defaults: ScratchDefaults.make("docs-demo"))
        settings.notchWidthOffset = 12  // a calibrated 15" MacBook Air
        let nowPlaying = NowPlayingModel()
        model = NotchViewModel(settings: settings, nowPlaying: nowPlaying, timer: TimerModel(), stopwatch: StopwatchModel())
        model.detectedNotchSize = CGSize(width: 156, height: 32)
        nowPlaying.apply(source: .app(.spotify), snapshot: PlayerSnapshot(
            isPlaying: true, title: "Golden Hour", artist: "Seaside Club", album: "Summer Tapes",
            duration: 214, position: 83, capturedAt: .now, trackID: "docs"))
        nowPlaying.setArtwork(DocsImages.artwork(), accent: NSColor(hue: 0.9, saturation: 0.55, brightness: 1, alpha: 1))
    }

    func say(_ title: String, _ detail: String) {
        withAnimation(.easeInOut(duration: 0.4)) {
            caption = DemoCaption(title: title, detail: detail)
        }
    }
}

struct DemoCaption: Hashable {
    let title: String
    let detail: String
}

/// The demo, second by second. Each moment changes the island the way the
/// app's own controllers do, with the same animations.
@MainActor
enum DemoScript {
    struct Moment {
        let time: TimeInterval
        let action: @MainActor (DemoStage) -> Void
    }

    /// The whole film, captions included.
    static let length: TimeInterval = 30
    /// The part the README's picture loops through: every feature, no captions.
    static let loop: ClosedRange<TimeInterval> = 1.3...26.9

    static let moments: [Moment] = {
        let airPods = HeadphonesInfo(name: "AirPods Pro", productID: 0x2014, left: 85, right: 80, chargingCase: 60)
        func at(_ time: TimeInterval, _ action: @escaping @MainActor (DemoStage) -> Void) -> Moment {
            Moment(time: time, action: action)
        }
        func animate(_ animation: Animation, _ change: @escaping @MainActor (DemoStage) -> Void) -> @MainActor (DemoStage) -> Void {
            { stage in withAnimation(animation) { change(stage) } }
        }
        func volume(_ level: Float) -> @MainActor (DemoStage) -> Void {
            { $0.model.hud = NotchViewModel.HUD(kind: .volume, level: level) }
        }
        return [
            at(0) { $0.say("NotchIsland", "A free and open source Dynamic Island for the MacBook notch") },

            // Music: hover to peek, click to open, move away to close.
            at(1.4, animate(.easeOut(duration: 0.3)) { $0.showsPointer = true }),
            at(1.8) { $0.say("Music", "Hover to peek, click to open") },
            at(2.0, animate(.easeInOut(duration: 0.6)) { $0.pointer = CGPoint(x: 0, y: 14) }),
            at(2.6, animate(NotchStyle.peek) { $0.model.state = .peeking }),
            at(3.2, animate(.easeOut(duration: 0.08)) { $0.isClicking = true }),
            at(3.3, animate(.easeOut(duration: 0.12)) { $0.isClicking = false }),
            at(3.3, animate(NotchStyle.expand) { $0.model.state = .expanded }),
            at(5.4, animate(.easeInOut(duration: 0.5)) { $0.pointer = CGPoint(x: 170, y: 175) }),
            at(5.6, animate(NotchStyle.collapse) { $0.model.state = .collapsed }),
            at(6.0, animate(.easeOut(duration: 0.3)) { $0.showsPointer = false }),

            // AirPods: the card as they connect, the pill once they're in.
            at(6.4) { $0.say("AirPods", "Battery levels, with the same 3D animation as macOS") },
            at(6.6, animate(NotchStyle.expand) { $0.model.alert = .headphones(airPods, isCompact: false) }),
            at(9.0, animate(NotchStyle.expand) { $0.model.alert = .headphones(airPods, isCompact: true) }),
            at(10.8, animate(NotchStyle.collapse) { $0.model.alert = nil }),

            // Volume: a few presses of the volume up key.
            at(11.3) { $0.say("Volume and brightness", "A level bar beside the notch") },
            at(11.5, animate(NotchStyle.expand) { $0.model.hud = NotchViewModel.HUD(kind: .volume, level: 0.4375) }),
            at(11.8, volume(0.5)),
            at(12.1, volume(0.5625)),
            at(12.4, volume(0.625)),
            at(12.7, volume(0.6875)),
            at(14.2, animate(NotchStyle.collapse) { $0.model.hud = nil }),

            // Focus.
            at(14.6) { $0.say("Focus", "Your own Focus modes, with their symbols") },
            at(14.8, animate(NotchStyle.expand) {
                $0.model.alert = .focus(FocusAlert(mode: .builtIn("com.apple.donotdisturb.mode.default"), isOn: true))
            }),
            at(17.3, animate(NotchStyle.collapse) { $0.model.alert = nil }),

            // A Clock timer: the music steps aside into its bubble.
            at(17.8) { $0.say("Timers", "Straight from the Clock app") },
            at(18.0, animate(NotchStyle.expand) { $0.model.timer.show(.running(endDate: .now.addingTimeInterval(5 * 60)), duration: 300) }),
            at(21.3, animate(NotchStyle.collapse) { $0.model.timer.show(.idle, duration: 0) }),

            // Locking and unlocking right away, as with Touch ID.
            at(21.8) { $0.say("Lock screen", "It shows on the lock screen too") },
            at(22.0, animate(NotchStyle.expand) { $0.model.lockIndicator = NotchViewModel.LockIndicator() }),
            at(23.4, animate(NotchStyle.unlock) { $0.model.lockIndicator?.isUnlocked = true }),
            at(24.9, animate(NotchStyle.expand) { $0.model.lockIndicator?.placement = .leading }),
            at(26.1, animate(NotchStyle.collapse) { $0.model.lockIndicator = nil }),

            at(26.8) { $0.say("Free and open source", "github.com/goncaloqpinheiro/NotchIsland") },
        ]
    }()
}

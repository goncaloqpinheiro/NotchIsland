import CoreGraphics
import Observation

/// UI state shared by the notch window and its SwiftUI content.
@MainActor
@Observable
final class NotchViewModel {
    enum State {
        /// Idle: the shape hides behind the camera housing.
        case collapsed
        /// Hovered: slightly larger, with the backdrop blur.
        case peeking
        /// Clicked: full size with content.
        case expanded
    }

    /// The lock shown while the screen is locked and just after unlocking.
    struct LockIndicator: Equatable {
        enum Placement {
            /// Below the camera housing.
            case center
            /// In the ear left of the camera housing.
            case leading
        }

        var isUnlocked = false
        var placement = Placement.center
    }

    /// A volume or brightness level being shown.
    struct HUD: Equatable {
        enum Kind: Equatable {
            case volume, brightness
        }

        var kind: Kind
        var level: Float
        var isMuted = false
    }

    /// A short notification: headphones connecting, a battery moment, or a Focus change.
    enum Alert: Equatable {
        /// A card below the notch first, then a compact pill beside it.
        case headphones(HeadphonesInfo, isCompact: Bool)
        case power(PowerAlert)
        case focus(FocusAlert)
    }

    /// What the island shows when not hovered or open, highest priority first.
    enum Resting: Equatable {
        case lock, hud, headphones, power, focus, timerDone, timer, stopwatch, liveActivity, notch
    }

    var state = State.collapsed
    var hud: HUD?
    var alert: Alert?
    /// Whether macOS lets the app intercept the volume and brightness keys.
    var isAccessibilityGranted = false
    /// Whether the Focus files can be read (they need Full Disk Access).
    var isFocusAccessGranted = false
    var lockIndicator: LockIndicator?
    /// The notched display is showing a full-screen app.
    var isFullScreen = false
    /// Notch size reported by the screen, in points.
    var detectedNotchSize = CGSize(width: 180, height: 32)
    /// True while Settings is open: outlines the collapsed shape for calibration.
    var isCalibrating = false
    /// A media interaction just happened (see `MediaGlassController`), so the
    /// music activity gets the glass for a moment.
    var showsMediaGlass = false

    let nowPlaying: NowPlayingModel
    let timer: TimerModel
    let stopwatch: StopwatchModel
    private let settings: AppSettings

    init(settings: AppSettings, nowPlaying: NowPlayingModel, timer: TimerModel? = nil, stopwatch: StopwatchModel? = nil) {
        self.settings = settings
        self.nowPlaying = nowPlaying
        self.timer = timer ?? TimerModel()
        self.stopwatch = stopwatch ?? StopwatchModel()
    }

    var isExpanded: Bool { state == .expanded }

    /// Opacity of the glass behind the island, from Settings.
    var blurStrength: Double { settings.blurStrength }

    /// Which material shows behind the island, from Settings.
    var glass: IslandGlass { settings.glass }

    /// The glass's color from Settings, or nil for its natural look.
    /// Adaptive glass takes its color from what's behind it, so it has no tint of its own.
    var glassTint: GlassTint? { settings.glassAdapts ? nil : settings.glassTint }
    var glassAdapts: Bool { settings.glassAdapts }

    /// Whether the backdrop blur shows around the island.
    var showsHalo: Bool {
        guard blurStrength > 0 else { return false }
        // Hovered or open, or showing something that came and goes on its own.
        return state != .collapsed || restingShowsGlass
    }

    /// Alerts get the same glass a hover does. What sits on screen for hours
    /// (music, a timer or stopwatch counting down) stays plain, so the window
    /// server isn't blurring all day.
    private var restingShowsGlass: Bool {
        switch resting {
        case .lock, .hud, .headphones, .power, .focus, .timerDone: true
        // Only just after a media interaction, not for the whole song.
        case .liveActivity, .timer, .stopwatch: showsMediaGlass
        case .notch: false
        }
    }

    /// Collapsed size: the detected notch plus the adjustment from Settings.
    var notchSize: CGSize {
        CGSize(width: max(1, detectedNotchSize.width + settings.notchWidthOffset),
               height: max(1, detectedNotchSize.height + settings.notchHeightOffset))
    }

    /// The compact Now Playing activity, kept out of the way of full-screen apps.
    var showsLiveActivity: Bool {
        nowPlaying.showsLiveActivity && !isFullScreen
    }

    /// The compact countdown, also kept out of the way of full-screen apps.
    var showsTimerActivity: Bool {
        timer.isActive && !isFullScreen
    }

    /// The compact stopwatch, also kept out of the way of full-screen apps.
    var showsStopwatchActivity: Bool {
        stopwatch.isActive && !isFullScreen
    }

    /// With the timer or stopwatch in the island, playing music moves to a small bubble beside it.
    var showsMusicBubble: Bool {
        (resting == .timer || resting == .stopwatch) && showsLiveActivity && state != .expanded
    }

    /// The open island shows the timer's controls while one runs or rings.
    var showsTimerSection: Bool {
        timer.isActive || timer.isDone
    }

    /// Or, with no timer, the stopwatch's.
    var showsStopwatchSection: Bool {
        !showsTimerSection && stopwatch.isActive
    }

    var resting: Resting {
        if lockIndicator != nil { return .lock }
        if hud != nil { return .hud }
        switch alert {
        case .headphones?: return .headphones
        case .power?: return .power
        case .focus?: return .focus
        case nil: break
        }
        if timer.isDone { return .timerDone }
        if showsTimerActivity { return .timer }
        if showsStopwatchActivity { return .stopwatch }
        return showsLiveActivity ? .liveActivity : .notch
    }

    // MARK: - Sizes

    /// The notch widened for the art and audio bars while music plays.
    var liveActivitySize: CGSize { widenedNotch(by: NotchStyle.liveActivityEarWidth) }

    /// Room below the camera housing for the lock icon, or the left ear once it moves there.
    var lockSize: CGSize {
        if lockIndicator?.placement == .leading {
            return widenedNotch(by: NotchStyle.lockEarWidth)
        }
        return CGSize(width: notchSize.width, height: notchSize.height + NotchStyle.lockIndicatorHeight)
    }

    /// The notch widened for a volume or brightness level.
    var hudSize: CGSize { widenedNotch(by: NotchStyle.hudEarWidth) }

    var powerAlertSize: CGSize { widenedNotch(by: NotchStyle.powerAlertEarWidth) }

    var headphonesAlertSize: CGSize { NotchStyle.headphonesAlertSize(forNotch: notchSize) }

    var headphonesCompactSize: CGSize { widenedNotch(by: NotchStyle.headphonesCompactEarWidth) }

    var focusAlertSize: CGSize { widenedNotch(by: NotchStyle.focusEarWidth) }

    var timerActivitySize: CGSize { widenedNotch(by: NotchStyle.timerEarWidth) }

    var timerAlertSize: CGSize { NotchStyle.timerAlertSize(forNotch: notchSize) }

    /// Size when not hovered or open.
    var restingSize: CGSize {
        switch resting {
        case .lock: lockSize
        case .hud: hudSize
        case .headphones: isHeadphonesAlertCompact ? headphonesCompactSize : headphonesAlertSize
        case .power: powerAlertSize
        case .focus: focusAlertSize
        case .timerDone: timerAlertSize
        case .timer, .stopwatch: timerActivitySize
        case .liveActivity: liveActivitySize
        case .notch: notchSize
        }
    }

    var expandedSize: CGSize {
        let player = NotchStyle.playerSize(forNotch: notchSize)
        switch (showsTimerSection || showsStopwatchSection, nowPlaying.hasTrack) {
        case (true, true): return CGSize(width: player.width, height: player.height + NotchStyle.timerSectionHeight)
        case (true, false): return timerAlertSize
        case (false, true): return player
        case (false, false): return NotchStyle.idleSize(forNotch: notchSize)
        }
    }

    var shapeSize: CGSize {
        switch state {
        case .collapsed: restingSize
        case .peeking: CGSize(width: restingSize.width + NotchStyle.peekGrowth.width,
                              height: restingSize.height + NotchStyle.peekGrowth.height)
        case .expanded: expandedSize
        }
    }

    var topCornerRadius: CGFloat {
        switch state {
        case .collapsed: restsAsCard ? NotchStyle.alertTopRadius : NotchStyle.collapsedTopRadius
        case .peeking: NotchStyle.peekTopRadius
        case .expanded: NotchStyle.expandedTopRadius
        }
    }

    var bottomCornerRadius: CGFloat {
        switch state {
        case .collapsed:
            if restsAsCard { return NotchStyle.alertBottomRadius }
            if resting == .lock && lockIndicator?.placement == .center { return NotchStyle.lockBottomRadius }
            return NotchStyle.collapsedBottomRadius
        case .peeking: return NotchStyle.peekBottomRadius
        case .expanded: return NotchStyle.expandedBottomRadius
        }
    }

    private var isHeadphonesAlertCompact: Bool {
        if case .headphones(_, true)? = alert { return true }
        return false
    }

    /// Tall resting content (the AirPods card, a finished timer) gets rounder corners.
    private var restsAsCard: Bool {
        switch resting {
        case .headphones: !isHeadphonesAlertCompact
        case .timerDone: true
        default: false
        }
    }

    private func widenedNotch(by earWidth: CGFloat) -> CGSize {
        CGSize(width: notchSize.width + 2 * earWidth, height: notchSize.height)
    }
}

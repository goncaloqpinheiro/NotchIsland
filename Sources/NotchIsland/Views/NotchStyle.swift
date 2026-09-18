import SwiftUI

/// Sizes, shapes and motion in one place, so the feel can be tuned by eye.
enum NotchStyle {
    // MARK: Collapsed (matches the camera housing)

    /// Concave flare where the shape meets the top edge of the screen.
    static let collapsedTopRadius: CGFloat = 6
    static let collapsedBottomRadius: CGFloat = 10

    // MARK: Peeking (hovered)

    /// Growth while hovered: 6 pt per side and 6 pt down, about 1.5 mm on a 15" Air.
    static let peekGrowth = CGSize(width: 12, height: 6)
    static let peekTopRadius: CGFloat = 7
    static let peekBottomRadius: CGFloat = 13

    // MARK: Live activity (compact, while music plays)

    /// Room added on each side of the notch for the art and the audio bars.
    static let liveActivityEarWidth: CGFloat = 40
    /// With a timer in the island, music moves to a bubble this far to its right.
    static let bubbleGap: CGFloat = 6

    // MARK: Volume and brightness

    /// Room added on each side of the notch for the symbol and the level bar,
    /// wide enough to read the level at a glance.
    static let hudEarWidth: CGFloat = 90
    /// The symbol and the bar sit this far from their outer edges, so the two
    /// sides mirror each other instead of the bar hugging the right edge.
    static let hudEdgePadding: CGFloat = 14
    /// Space between the bar and the camera housing.
    static let hudNotchGap: CGFloat = 8
    /// How long the level stays after the last key press.
    static let hudDuration: TimeInterval = 1.5

    // MARK: Alerts (AirPods, battery, Focus)

    /// Room on each side of the notch for "Charging" and the battery level.
    static let powerAlertEarWidth: CGFloat = 92
    static let powerAlertDuration: TimeInterval = 3.5
    static let alertTopRadius: CGFloat = 10
    static let alertBottomRadius: CGFloat = 24

    /// Room below the camera housing for the 3D model, name and batteries.
    static func headphonesAlertSize(forNotch notch: CGSize) -> CGSize {
        CGSize(width: max(340, notch.width + 180), height: notch.height + 84)
    }

    /// Headphones connecting: the card until they go in an ear (at most this
    /// long), then the compact pill, then gone.
    static let headphonesCardDuration: TimeInterval = 6
    static let headphonesCompactDuration: TimeInterval = 3
    /// Taking AirPods out and back in within this long doesn't show the pill again.
    static let headphonesInEarCooldown: TimeInterval = 10
    /// Room on each side of the notch for the small model and the battery ring.
    static let headphonesCompactEarWidth: CGFloat = 80

    /// Room on each side of the notch for the Focus symbol and "On" or "Off".
    static let focusEarWidth: CGFloat = 44
    static let focusAlertDuration: TimeInterval = 2.5

    // MARK: Lock indicator

    /// Height added below the camera housing for the lock icon.
    static let lockIndicatorHeight: CGFloat = 30
    static let lockBottomRadius: CGFloat = 18
    /// Room on each side of the notch once the lock tucks into the left ear.
    static let lockEarWidth: CGFloat = 34
    /// How long the lock stays centered before moving to the left ear.
    static let lockCenterHold: TimeInterval = 2
    /// The lock screen takes a moment to light up after the display wakes.
    static let lockWakeDelay: TimeInterval = 0.3
    /// After unlocking: wait for the lock screen to fade, open the shackle,
    /// hold in the center, move left, hold, then tuck away.
    static let unlockRevealDelay: TimeInterval = 0.4
    /// When the lock is already visible on the lock screen, open it right away.
    static let unlockRevealDelayOnLockScreen: TimeInterval = 0.1
    static let unlockCenterHold: TimeInterval = 1.5
    static let unlockLeadingHold: TimeInterval = 1.2
    /// With the side style, the open lock holds in the ear this long before tucking away.
    static let unlockSideHold: TimeInterval = 1.4
    static let unlock = Animation.spring(duration: 0.45, bounce: 0.4)

    // MARK: Timer

    /// Room on each side of the notch for the timer symbol and the countdown.
    static let timerEarWidth: CGFloat = 56
    /// Pause and cancel (or Repeat and Stop) with the countdown, below the camera housing.
    static let timerSectionHeight: CGFloat = 64
    /// A finished timer shows until it's stopped (in the island or in Clock), or this long.
    static let timerDoneTimeout: TimeInterval = 120

    /// A finished timer, or the open island with a timer and no music.
    static func timerAlertSize(forNotch notch: CGSize) -> CGSize {
        CGSize(width: max(360, notch.width + 192), height: notch.height + timerSectionHeight + 4)
    }

    // MARK: Expanded (clicked)

    static let expandedTopRadius: CGFloat = 14
    static let expandedBottomRadius: CGFloat = 32

    /// Open with a track: art, title, progress and controls below the camera housing.
    static func playerSize(forNotch notch: CGSize) -> CGSize {
        CGSize(width: max(400, notch.width + 200), height: notch.height + 136)
    }

    /// Open with nothing playing.
    static func idleSize(forNotch notch: CGSize) -> CGSize {
        CGSize(width: max(300, notch.width + 120), height: notch.height + 64)
    }

    // MARK: Backdrop blur

    /// How far the blur reaches past the island's edges before fading out.
    static let haloSpread: CGFloat = 24
    /// Liquid Glass has a hard edge, so it only peeks out from behind the island.
    static let glassEdgeSpread: CGFloat = 5
    /// The light along the island's outline with frosted glass: brightest at the
    /// top, where the screen's edge is, fading down the curve. Drawn at twice
    /// this width and clipped to the shape, so it lies just inside the edge.
    static let rimWidth: CGFloat = 2
    static let rimOpacity: (top: Double, bottom: Double) = (0.38, 0.12)

    // MARK: Hover

    /// Extra room beside (width, each side) and below (height) the island that
    /// still counts as hovering it.
    static let hoverSlop = CGSize(width: 8, height: 0)
    /// How far the cursor can stray outside the open island before it closes.
    static let leaveSlop: CGFloat = 12
    static let exitDelay: TimeInterval = 0.15

    // MARK: Motion

    /// Hover: a small, lively bump.
    static let peek = Animation.spring(duration: 0.35, bounce: 0.35)
    /// Click: opening overshoots slightly and settles, like the Dynamic Island.
    /// Also moves content from one layout to another (lock to the left, AirPods card to compact).
    static let expand = Animation.spring(duration: 0.5, bounce: 0.3)
    static let collapse = Animation.spring(duration: 0.4, bounce: 0.15)
    /// Content waits for the island to start growing, then un-blurs into place.
    static let contentIn = Animation.spring(duration: 0.35, bounce: 0.1).delay(0.08)
    /// Content is gone before the island finishes shrinking.
    static let contentOut = Animation.easeOut(duration: 0.12)
    /// The glass fades out quickly as the island closes; lingering would drag a
    /// visible outline along with the shrinking shape.
    static let glassOut = Animation.easeOut(duration: 0.14)
    /// How long the glass stays after a media interaction (a track starting,
    /// pausing, resuming, or changing).
    static let mediaGlassDuration: TimeInterval = 2.5
}

import SwiftUI

/// The lock sequence, in one of two styles (see `LockStyle`).
///
/// Centered (the default): when the screen locks, or the display wakes on the
/// lock screen, a closed lock appears below the camera housing and after a
/// moment moves into the ear on its left. On unlock it comes back to the center,
/// the shackle springs open, and after a moment it moves left again before the
/// island tucks away.
///
/// Side, like Alcove: the lock goes straight into the left ear, opens there on
/// unlock, and tucks away.
///
/// On the lock screen too, when the mirror is available.
@MainActor
final class LockIndicatorController {
    /// Called when the screen locks, so an open island can close.
    var onLock: (() -> Void)?

    private let model: NotchViewModel
    private let settings: AppSettings?
    private let monitor: ScreenLockMonitor
    private let displays: DisplaySleepMonitor
    private let mirror: LockScreenMirror?
    private let sounds: SoundPlayer?
    private var sequence: Task<Void, Never>?
    private var isLocked = false

    init(model: NotchViewModel, settings: AppSettings? = nil, monitor: ScreenLockMonitor? = nil,
         displays: DisplaySleepMonitor? = nil, mirror: LockScreenMirror? = nil, sounds: SoundPlayer? = nil) {
        self.model = model
        self.settings = settings
        self.monitor = monitor ?? ScreenLockMonitor()
        self.displays = displays ?? DisplaySleepMonitor()
        self.mirror = mirror
        self.sounds = sounds
    }

    private var style: LockStyle { settings?.lockStyle ?? .centered }

    func start() {
        monitor.onLock = { [weak self] in self?.screenLocked() }
        monitor.onUnlock = { [weak self] in self?.screenUnlocked() }
        displays.onSleep = { [weak self] in self?.displaySlept() }
        displays.onWake = { [weak self] in self?.displayWoke() }
        monitor.start()
        displays.start()
    }

    private func screenLocked() {
        isLocked = true
        onLock?()
        mirror?.show()
        // Locking by hand leaves the display on. When it locks because the display
        // slept, nobody would see the lock: show it when the display wakes instead.
        guard !displays.isAsleep() else {
            sequence?.cancel()
            model.lockIndicator = nil
            return
        }
        sounds?.play(.lock)
        showLock()
    }

    private func displaySlept() {
        guard isLocked else { return }
        sequence?.cancel()
        model.lockIndicator = nil  // no animation: the display is off
    }

    private func displayWoke() {
        guard isLocked else { return }
        showLock(after: NotchStyle.lockWakeDelay)
    }

    /// Centered, then after a moment into the left ear; or straight into the ear.
    private func showLock(after delay: TimeInterval = 0) {
        sequence?.cancel()
        let style = style
        if delay == 0 {
            appear(style)
        }
        sequence = Task { [weak self] in
            if delay > 0 {
                try? await Task.sleep(for: .seconds(delay))
                guard !Task.isCancelled else { return }
                self?.appear(style)
            }
            guard style == .centered else { return }
            try? await Task.sleep(for: .seconds(NotchStyle.lockCenterHold))
            guard !Task.isCancelled, let self else { return }
            withAnimation(NotchStyle.expand) {
                self.model.lockIndicator?.placement = .leading
            }
        }
    }

    private func appear(_ style: LockStyle) {
        withAnimation(NotchStyle.expand) {
            model.lockIndicator = NotchViewModel.LockIndicator(placement: style == .side ? .leading : .center)
        }
    }

    private func screenUnlocked() {
        isLocked = false
        sequence?.cancel()
        let style = style
        // With the lock visible on the lock screen it can open right away; without
        // it, wait for the lock screen to fade so the closed lock is seen opening.
        var revealDelay = mirror?.isShowing == true ? NotchStyle.unlockRevealDelayOnLockScreen : NotchStyle.unlockRevealDelay
        switch (model.lockIndicator?.placement, style) {
        case (nil, _):
            appear(style)
        case (.leading?, .centered):
            // Back to the center first, where the shackle opens.
            withAnimation(NotchStyle.expand) {
                model.lockIndicator?.placement = .center
            }
            revealDelay = max(revealDelay, 0.45)
        case (.center?, .side):
            // The style changed while locked: open in the ear, where this style lives.
            withAnimation(NotchStyle.expand) {
                model.lockIndicator?.placement = .leading
            }
            revealDelay = max(revealDelay, 0.45)
        case (.center?, .centered), (.leading?, .side):
            break
        }
        sequence = Task { [weak self] in
            try? await Task.sleep(for: .seconds(revealDelay))
            guard !Task.isCancelled, let self else { return }
            withAnimation(NotchStyle.unlock) {
                self.model.lockIndicator?.isUnlocked = true
            }
            self.sounds?.play(.unlock)
            if style == .centered {
                try? await Task.sleep(for: .seconds(NotchStyle.unlockCenterHold))
                guard !Task.isCancelled else { return }
                withAnimation(NotchStyle.expand) {
                    self.model.lockIndicator?.placement = .leading
                }
                try? await Task.sleep(for: .seconds(NotchStyle.unlockLeadingHold))
            } else {
                try? await Task.sleep(for: .seconds(NotchStyle.unlockSideHold))
            }
            guard !Task.isCancelled else { return }
            withAnimation(NotchStyle.collapse) {
                self.model.lockIndicator = nil
            }
            try? await Task.sleep(for: .seconds(0.6))  // let the copy finish collapsing
            guard !Task.isCancelled else { return }
            self.mirror?.hide()
        }
    }
}

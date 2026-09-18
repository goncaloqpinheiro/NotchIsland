import AppKit

/// A display monitor that says the screen is on, whatever this Mac's screen is doing.
@MainActor
private func awakeDisplays() -> DisplaySleepMonitor {
    let displays = DisplaySleepMonitor()
    displays.isAsleep = { false }
    return displays
}

@MainActor
func testLock() async {
    let (model, _, _, _) = makeModel("lock")
    let monitor = ScreenLockMonitor()
    let displays = awakeDisplays()
    let lock = LockIndicatorController(model: model, monitor: monitor, displays: displays)
    var closes = 0
    lock.onLock = { closes += 1 }
    lock.start()
    let notch = model.notchSize

    monitor.onLock?()
    check("locking closes the island", closes == 1)
    check("the lock appears centered below the notch", model.lockIndicator == .init(isUnlocked: false, placement: .center)
          && model.restingSize == CGSize(width: notch.width, height: notch.height + NotchStyle.lockIndicatorHeight))
    check("centered lock has the rounder bottom", model.bottomCornerRadius == NotchStyle.lockBottomRadius)
    await wait(NotchStyle.lockCenterHold - 0.4)
    check("it stays centered for a moment", model.lockIndicator?.placement == .center)
    await wait(0.8)
    check("then moves into the left ear", model.lockIndicator == .init(isUnlocked: false, placement: .leading))
    check("the island becomes a pill at notch height", model.restingSize == CGSize(width: notch.width + 2 * NotchStyle.lockEarWidth, height: notch.height)
          && model.bottomCornerRadius == NotchStyle.collapsedBottomRadius)

    displays.onSleep?()
    check("display sleep hides the lock", model.lockIndicator == nil)
    displays.onWake?()
    check("waking waits for the lock screen to light up", model.lockIndicator == nil)
    await wait(NotchStyle.lockWakeDelay + 0.2)
    check("waking shows the lock centered again", model.lockIndicator == .init(isUnlocked: false, placement: .center))
    await wait(NotchStyle.lockCenterHold + 0.3)
    check("and moves it left again", model.lockIndicator?.placement == .leading)

    monitor.onUnlock?()
    check("unlocking brings the lock back to the center first", model.lockIndicator == .init(isUnlocked: false, placement: .center))
    await wait(0.45 + 0.2)
    check("then the shackle opens", model.lockIndicator == .init(isUnlocked: true, placement: .center))
    await wait(NotchStyle.unlockCenterHold - 0.4)
    check("the open lock holds in the center", model.lockIndicator?.placement == .center)
    await wait(0.6)
    check("then moves into the left ear, still open", model.lockIndicator == .init(isUnlocked: true, placement: .leading))
    await wait(NotchStyle.unlockLeadingHold + 0.2)
    check("then the island tucks away", model.lockIndicator == nil && model.resting == .notch)

    displays.onWake?()
    await wait(NotchStyle.lockWakeDelay + 0.2)
    check("waking while unlocked shows nothing", model.lockIndicator == nil)

    // Unlocking while the lock is still centered (e.g. Touch ID right away).
    monitor.onLock?()
    await wait(0.3)
    monitor.onUnlock?()
    check("quick unlock keeps the lock centered and closed", model.lockIndicator == .init(isUnlocked: false, placement: .center))
    await wait(NotchStyle.unlockRevealDelay + 0.2)
    check("quick unlock opens in the center", model.lockIndicator == .init(isUnlocked: true, placement: .center))

    // Locking again mid-sequence cancels the pending steps.
    monitor.onLock?()
    await wait(NotchStyle.unlockCenterHold + 0.2)
    check("re-locking mid-sequence shows a closed lock", model.lockIndicator?.isUnlocked == false)
    await wait(NotchStyle.lockCenterHold + NotchStyle.unlockLeadingHold)
    check("and it stays until unlocked", model.lockIndicator == .init(isUnlocked: false, placement: .leading))
}

@MainActor
func testLockWhileAsleep() async {
    let (model, _, _, _) = makeModel("lock-asleep")
    let monitor = ScreenLockMonitor()
    let displays = DisplaySleepMonitor()
    displays.isAsleep = { true }
    let lock = LockIndicatorController(model: model, monitor: monitor, displays: displays)
    lock.start()

    // The Mac locked because its display went to sleep: nobody would see the lock.
    monitor.onLock?()
    check("locking with the display asleep shows nothing yet", model.lockIndicator == nil)
    displays.isAsleep = { false }
    displays.onWake?()
    await wait(NotchStyle.lockWakeDelay + 0.2)
    check("the lock appears once the display wakes", model.lockIndicator == .init(isUnlocked: false, placement: .center))
}

@MainActor
func testLockSide() async {
    let (model, _, _, settings) = makeModel("lockside")
    check("the centered style is the default", settings.lockStyle == .centered)
    settings.lockStyle = .side
    check("the choice is remembered", AppSettings(defaults: ScratchDefaults.reopen("lockside")).lockStyle == .side)
    let monitor = ScreenLockMonitor()
    let displays = awakeDisplays()
    let lock = LockIndicatorController(model: model, settings: settings, monitor: monitor, displays: displays)
    lock.start()
    let notch = model.notchSize

    monitor.onLock?()
    check("side: the lock goes straight into the left ear", model.lockIndicator == .init(isUnlocked: false, placement: .leading)
          && model.restingSize == CGSize(width: notch.width + 2 * NotchStyle.lockEarWidth, height: notch.height))
    await wait(NotchStyle.lockCenterHold + 0.4)
    check("and stays there, never visiting the middle", model.lockIndicator == .init(isUnlocked: false, placement: .leading))
    displays.onSleep?()
    displays.onWake?()
    await wait(NotchStyle.lockWakeDelay + 0.2)
    check("waking shows it in the ear again", model.lockIndicator == .init(isUnlocked: false, placement: .leading))

    monitor.onUnlock?()
    check("unlocking doesn't bring it to the center", model.lockIndicator?.placement == .leading)
    await wait(NotchStyle.unlockRevealDelay + 0.2)
    check("the shackle opens right there in the ear", model.lockIndicator == .init(isUnlocked: true, placement: .leading))
    await wait(NotchStyle.unlockSideHold + 0.4)
    check("then the island tucks away", model.lockIndicator == nil && model.resting == .notch)

    // Changing the style while the Mac is locked.
    settings.lockStyle = .centered
    monitor.onLock?()
    check("back on centered, it appears in the middle", model.lockIndicator?.placement == .center)
    settings.lockStyle = .side
    monitor.onUnlock?()
    check("switched to side while locked: it moves to the ear to open", model.lockIndicator?.placement == .leading)
    await wait(0.45 + 0.2)
    check("and opens there", model.lockIndicator == .init(isUnlocked: true, placement: .leading))
    await wait(NotchStyle.unlockSideHold + 0.4)
    check("then tucks away", model.lockIndicator == nil)
}

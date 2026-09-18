import AppKit

@MainActor
func testAlertsAndPriorities() async {
    let info = HeadphonesInfo(name: "AirPods", productID: 0x2019, left: 80, right: 72, chargingCase: 50)
    check("compact level is the lower earbud", info.headlineLevel == 72)
    check("single-battery headphones", HeadphonesInfo(name: "Max", productID: 0x200A, single: 40).headlineLevel == 40)
    check("case only", HeadphonesInfo(name: "AirPods", productID: 0x2019, chargingCase: 30).headlineLevel == 30)
    check("unknown battery", HeadphonesInfo(name: "AirPods", productID: 0x2019).headlineLevel == nil)
    check("Bluetooth address from a Core Audio UID", AudioOutputMonitor.bluetoothAddress(fromUID: "AC-90-85-12-34-5F:output") == "ac-90-85-12-34-5f"
          && AudioOutputMonitor.bluetoothAddress(fromUID: "BuiltInSpeakerDevice") == nil)

    let (model, nowPlaying, timer, settings) = makeModel("alerts")
    let alerts = AlertController(model: model, settings: settings, sounds: SoundPlayer(settings: settings))
    let notch = model.notchSize
    let compactSize = CGSize(width: notch.width + 2 * NotchStyle.headphonesCompactEarWidth, height: notch.height)

    // Connected (out of the case): the card. In the ears: the pill at once.
    alerts.presentHeadphones(HeadphonesInfo(name: "AirPods", productID: 0x2019))
    check("connecting shows the card", model.alert == .headphones(HeadphonesInfo(name: "AirPods", productID: 0x2019), isCompact: false)
          && model.restingSize == NotchStyle.headphonesAlertSize(forNotch: notch) && model.bottomCornerRadius == NotchStyle.alertBottomRadius)
    await wait(0.5)
    alerts.presentHeadphonesInEar(info)
    check("going in the ears shrinks it right away, with batteries", model.alert == .headphones(info, isCompact: true)
          && model.restingSize == compactSize && model.bottomCornerRadius == NotchStyle.collapsedBottomRadius)
    await wait(NotchStyle.headphonesCompactDuration + 0.2)
    check("then it disappears", model.alert == nil)
    alerts.presentHeadphonesInEar(info)
    check("taking them out and back in soon after stays quiet", model.alert == nil)

    // The output can switch before the connection is reported.
    let other = HeadphonesInfo(name: "Other AirPods", productID: 0x2014, left: 50, right: 50)
    alerts.presentHeadphonesInEar(other)
    check("in the ears without a card: the pill directly", model.alert == .headphones(other, isCompact: true))
    alerts.presentHeadphones(HeadphonesInfo(name: "Other AirPods", productID: 0x2014))
    check("a late connection doesn't bring the card back", model.alert == .headphones(other, isCompact: true))
    await wait(NotchStyle.headphonesCompactDuration + 0.2)

    // Never in an ear (e.g. listening on the speakers): the card shrinks after a while anyway.
    let third = HeadphonesInfo(name: "Beats", productID: 0x2012, single: 90)
    alerts.presentHeadphones(third)
    await wait(NotchStyle.headphonesCardDuration + 0.6)  // slack for a busy machine
    check("the card shrinks on its own after \(NotchStyle.headphonesCardDuration) s", model.alert == .headphones(third, isCompact: true))
    await wait(NotchStyle.headphonesCompactDuration + 0.2)
    check("then disappears", model.alert == nil)

    // Priorities, highest first: lock, HUD, alerts, finished timer, timer, music.
    play(nowPlaying)
    check("music alone", model.resting == .liveActivity)
    timer.show(.running(endDate: Date().addingTimeInterval(60)), duration: 60)
    check("timer over music", model.resting == .timer)
    timer.show(.done, duration: 60)
    check("finished timer over music", model.resting == .timerDone)
    model.alert = .focus(FocusAlert(mode: .builtIn("com.apple.focus.work"), isOn: false))
    check("alerts over a finished timer", model.resting == .focus)
    model.hud = NotchViewModel.HUD(kind: .volume, level: 0.5)
    check("volume over alerts", model.resting == .hud)
    model.lockIndicator = NotchViewModel.LockIndicator()
    check("lock over everything", model.resting == .lock)
    model.state = .expanded
    model.lockIndicator = nil
    model.hud = nil
    model.alert = nil
    check("open island with a finished timer shows its section", model.showsTimerSection)
}

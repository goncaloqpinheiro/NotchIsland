import AppKit

@MainActor
func testTimerFormat() {
    check("clock under an hour", TimerFormat.clock(299) == "4:59" && TimerFormat.clock(0) == "0:00" && TimerFormat.clock(59.2) == "1:00")
    check("clock with hours", TimerFormat.clock(3723) == "1:02:03")
    check("spoken", TimerFormat.spoken(60) == "1 Minute" && TimerFormat.spoken(300) == "5 Minutes"
          && TimerFormat.spoken(5400) == "1 Hour, 30 Minutes")
    let cases: [(String, TimeInterval?)] = [
        ("25", 1500), (" 1.5 ", 90), ("1:30", 90), ("1:00:00", 3600), ("1h 15m", 4500), ("1h30m", 5400),
        ("90s", 90), ("2 minutes", 120), ("1 hour and 5 minutes", 3900), ("45 sec", 45),
        ("", nil), ("abc", nil), ("0", nil), ("25 hours", nil), ("1:xx", nil), ("5m 30", nil), ("-5", nil), ("1:2:3:4", nil),
    ]
    for (input, expected) in cases {
        check("parse \"\(input)\" as \(expected.map { "\($0)" } ?? "nothing")", TimerFormat.parse(input) == expected)
    }
}

@MainActor
func testClockTimerParsing() {
    let now = Date()
    let fire = now.addingTimeInterval(240)
    let preference: [String: Any] = ["MTTimers": [
        ["$MTTimer": ["MTTimerID": "stopped", "MTTimerState": 1, "MTTimerDuration": 900.0, "MTTimerTitle": "CURRENT_TIMER",
                      "MTTimerFireTime": ["$MTTimerTimeInterval": ["MTTimerTimeInterval": 900.0]]]],
        ["$MTTimer": ["MTTimerID": "running", "MTTimerState": 3, "MTTimerDuration": 300.0, "MTTimerTitle": "Pasta",
                      "MTTimerFireTime": ["$MTTimerDate": ["MTTimerTimeDate": fire]]]],
        ["$MTTimer": ["MTTimerID": "paused", "MTTimerState": 2, "MTTimerDuration": 600.0, "MTTimerTitle": "",
                      "MTTimerFireTime": ["$MTTimerTimeInterval": ["MTTimerTimeInterval": 420.0]]]],
        ["$MTTimer": ["MTTimerID": "fired", "MTTimerState": 1, "MTTimerDuration": 60.0,
                      "MTTimerFiredDate": now.addingTimeInterval(-5)]],
        ["$MTTimer": ["MTTimerID": "timestamp", "MTTimerState": 3, "MTTimerDuration": 60.0,
                      "MTTimerFireTime": ["$MTTimerDate": ["MTTimerTimeDate": fire.timeIntervalSinceReferenceDate]]]],
        ["no id": true],
    ]]
    let timers = ClockTimer.timers(fromPreference: preference)
    check("reads every timer with an ID", timers.map(\.id) == ["stopped", "running", "paused", "fired", "timestamp"])
    check("stopped timer, default title hidden", timers[0].state == .stopped && timers[0].title == nil && timers[0].duration == 900)
    check("running timer's fire date and label", timers[1].state == .running(fireDate: fire) && timers[1].title == "Pasta")
    check("paused timer keeps what's left", timers[2].state == .paused(remaining: 420) && timers[2].title == nil)
    check("a fire date stored as a timestamp", timers[4].state == .running(fireDate: Date(timeIntervalSinceReferenceDate: fire.timeIntervalSinceReferenceDate)))
    check("a fired timer that wasn't stopped is ringing", timers[3].isRinging(at: now, limit: 120))
    var dismissed = timers[3]
    dismissed.dismissedDate = now
    check("once dismissed it isn't", !dismissed.isRinging(at: now, limit: 120))
    check("ringing stops counting after the limit", !timers[3].isRinging(at: now.addingTimeInterval(200), limit: 120))
    check("a running timer past its fire date is ringing", timers[1].isRinging(at: fire.addingTimeInterval(1), limit: 120))

    check("ringing beats running and paused", TimerDisplay.pick(from: timers, at: now, ringingLimit: 120).phase == .done)
    check("the next to go off comes first", TimerDisplay.pick(from: Array(timers.prefix(3)), at: now, ringingLimit: 120)
          == TimerDisplay(phase: .running(endDate: fire), timer: timers[1]))
    check("then a paused one", TimerDisplay.pick(from: [timers[0], timers[2]], at: now, ringingLimit: 120).phase == .paused(remaining: 420))
    check("stopped timers show nothing", TimerDisplay.pick(from: [timers[0]], at: now, ringingLimit: 120).phase == .idle)
    check("closed ringing timers are skipped", TimerDisplay.pick(from: [timers[3]], at: now, ringingLimit: 120, ignoring: ["fired"]).phase == .idle)

    // This Mac's own Clock records, read only. A Mac that never used Clock has none.
    let clock = UserDefaults(suiteName: "com.apple.mobiletimerd")
    func stored(_ key: String) -> [Any] {
        let value = clock?.object(forKey: key)
        return ((value as? [String: Any])?[key] as? [Any]) ?? (value as? [Any]) ?? []
    }
    let storedTimers = stored("MTTimers")
    let real = ClockTimer.timers(fromPreference: clock?.object(forKey: "MTTimers"))
    info("Clock timers on this Mac: \(real.map { "\($0.state)" })")
    check("reads this Mac's Clock timers", storedTimers.isEmpty == real.isEmpty)
    let storedStopwatches = stored("MTStopwatches")
    let realStopwatches = ClockStopwatch.stopwatches(fromPreference: clock?.object(forKey: "MTStopwatches"))
    info("Clock stopwatch on this Mac: \(realStopwatches.map { "\($0.state), \(TimerFormat.elapsed($0.elapsed(at: Date()))) on it, \($0.lapCount) laps" })")
    check("reads this Mac's Clock stopwatch", storedStopwatches.count == realStopwatches.count)
}

@MainActor
func testStopwatchParsing() {
    let now = Date()
    let since = now.addingTimeInterval(-10)
    let preference: [String: Any] = ["MTStopwatches": [
        ["$MTStopwatch": ["MTStopwatchIdentifier": "paused", "MTStopwatchState": 1, "MTStopwatchOffset": 1.353,
                          "MTStopwatchCurrentInterval": 1.327, "MTStopwatchPreviousLapsTotalInterval": 7.129, "MTStopwatchLaps": [7.129]]],
        ["$MTStopwatch": ["MTStopwatchIdentifier": "running", "MTStopwatchState": 2, "MTStopwatchOffset": 5.0,
                          "MTStopwatchPreviousLapsTotalInterval": 60.0, "MTStopwatchLaps": [30.0, 30.0], "MTStopwatchStartDate": since]],
        ["$MTStopwatch": ["MTStopwatchIdentifier": "reset", "MTStopwatchState": 0, "MTStopwatchOffset": 0]],
        ["$MTStopwatch": ["MTStopwatchIdentifier": "no start", "MTStopwatchState": 2, "MTStopwatchOffset": 3.0]],
    ]]
    let stopwatches = ClockStopwatch.stopwatches(fromPreference: preference)
    check("reads every stopwatch", stopwatches.map(\.id) == ["paused", "running", "reset", "no start"])
    check("paused: laps plus the current lap", stopwatches[0].state == .paused && abs(stopwatches[0].elapsed(at: now) - 8.482) < 0.001 && stopwatches[0].lapCount == 1)
    check("running: laps, offset and time since the start", stopwatches[1].state == .running(since: since) && abs(stopwatches[1].elapsed(at: now) - 75) < 0.001)
    check("reset stopwatch", stopwatches[2].state == .stopped && stopwatches[2].elapsed(at: now) == 0)
    check("running without a start date shows the time so far", stopwatches[3].state == .paused && stopwatches[3].elapsed(at: now) == 3)
    check("elapsed format drops fractions", TimerFormat.elapsed(8.99) == "0:08" && TimerFormat.elapsed(75.5) == "1:15" && TimerFormat.elapsed(3849.9) == "1:04:09")
    // Redraws land exactly on whole seconds; date arithmetic mustn't tip them into the wrong second.
    let reference = Date(timeIntervalSinceReferenceDate: 811_353_122.9605891)
    check("a stopwatch tick shows its own second", (0...3700).allSatisfy { n in
        TimerFormat.elapsed(reference.addingTimeInterval(TimeInterval(n)).timeIntervalSince(reference)) == TimerFormat.elapsed(TimeInterval(n)) })
    check("a countdown tick shows its own second", (0...3700).allSatisfy { k in
        TimerFormat.clock(reference.timeIntervalSince(reference.addingTimeInterval(-TimeInterval(k)))) == TimerFormat.clock(TimeInterval(k)) })
    check("near-whole values settle", TimerFormat.clock(4.9999999) == "0:05" && TimerFormat.clock(5.0000001) == "0:05"
          && TimerFormat.elapsed(6.9999999) == "0:07")
    check("countdown ticks start at the last whole-second boundary", TimerFormat.countdownTick(endDate: reference, now: reference.addingTimeInterval(-4.3))
          == reference.addingTimeInterval(-5) && TimerFormat.countdownTick(endDate: reference, now: reference.addingTimeInterval(1)) == reference)
}

@MainActor
func testTimerModel() {
    let timer = TimerModel()
    let end = Date().addingTimeInterval(200)
    check("starts idle without controls", timer.phase == .idle && !timer.canStart && !timer.canToggle && !timer.canCancel)
    timer.show(.running(endDate: end), duration: 300, title: "Tea")
    check("shows a running timer", timer.isRunning && timer.duration == 300 && timer.title == "Tea" && abs(timer.remaining() - 200) < 1)
    timer.controls = [.pause]
    check("pause alone toggles only while running", timer.canToggle)
    timer.show(.paused(remaining: 120), duration: 300)
    check("paused needs resume", !timer.canToggle && timer.isPaused && timer.remaining() == 120 && timer.title == nil)
    timer.controls = Set(TimerCommand.allCases)
    check("all controls", timer.canToggle && timer.canStart && timer.canCancel)
    check("timer shortcut names", TimerCommand.allCases.map(\.shortcutName) == ["NotchIsland Start Timer", "NotchIsland Pause Timer", "NotchIsland Resume Timer", "NotchIsland Cancel Timer"])
    check("stopwatch shortcut names", StopwatchCommand.allCases.map(\.shortcutName) == ["NotchIsland Start Stopwatch", "NotchIsland Stop Stopwatch", "NotchIsland Lap Stopwatch", "NotchIsland Reset Stopwatch"])
    check("available commands from shortcut names", TimerCommand.available(in: ["NotchIsland Pause Timer", "Other"]) == [.pause])
}

@MainActor
func testTimerMenu() {
    let (model, _, timer, _) = makeModel("menu")
    let clock = FakeClock()
    let shortcuts = FakeShortcuts()
    var opened = 0, setUp = 0
    let controller = TimerController(model: model, runner: shortcuts, source: clock, openClock: { opened += 1 })
    let timerMenu = TimerMenu(timer: timer, controller: controller, onSetUp: { setUp += 1 })
    let menu = timerMenu.makeItem().submenu!
    func titles() -> [String] { menu.items.map { $0.isSeparatorItem ? "|" : $0.title } }

    check("without shortcuts: open Clock and set up", titles() == ["Open Clock", "Set Up Timer Controls…"])
    menu.performActionForItem(at: 0)
    menu.performActionForItem(at: 1)
    check("those items work", opened == 1 && setUp == 1)

    timer.controls = Set(TimerCommand.allCases)
    timerMenu.menuNeedsUpdate(menu)
    check("with shortcuts: presets, Custom and Clock", titles() == ["1 Minute", "3 Minutes", "5 Minutes", "10 Minutes", "15 Minutes", "30 Minutes", "Custom…", "|", "Open Clock"])
    timer.show(.running(endDate: Date().addingTimeInterval(299.5)), duration: 300, title: "Tea")
    timerMenu.menuNeedsUpdate(menu)
    check("running: status, Pause, Cancel, then new timers", Array(titles().prefix(5)) == ["Tea: 5:00 left", "Pause", "Cancel Timer", "|", "New Timer"])
    timer.show(.done, duration: 300)
    timerMenu.menuNeedsUpdate(menu)
    check("done: Stop and Repeat", Array(titles().prefix(3)) == ["Timer done", "Stop", "Repeat"])

    var needsAccess = true
    let appMenuOwner = AppMenu(onOpenSettings: {}, timerMenu: timerMenu, needsFocusAccess: { needsAccess })  // the app keeps it too
    let appMenu = appMenuOwner.makeMenu()
    check("the app menu has the Timer submenu", appMenu.items.contains { $0.title == "Timer" && $0.submenu != nil })
    let focusItem = appMenu.items.first { $0.title == "Turn On Focus Alerts…" }
    check("the menu offers turning on Focus while access is missing", focusItem?.isHidden == false)
    needsAccess = false
    appMenu.delegate?.menuNeedsUpdate?(appMenu)
    check("and hides it once access is granted", focusItem?.isHidden == true)
    withExtendedLifetime(appMenuOwner) {}
}

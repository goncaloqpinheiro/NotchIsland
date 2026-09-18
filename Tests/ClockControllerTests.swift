import AppKit

@MainActor
func testTimerController() async {
    let (model, nowPlaying, timer, _) = makeModel("timer")
    let clock = FakeClock()
    let shortcuts = FakeShortcuts()
    var opened = 0
    let controller = TimerController(model: model, runner: shortcuts, source: clock, openClock: { opened += 1 })
    let actions = controller.actions
    let notch = model.notchSize

    controller.start()
    await wait(0.1)
    check("finds the shortcuts", timer.controls == Set(TimerCommand.allCases))
    check("no Clock timer, nothing shown", timer.phase == .idle && model.resting == .notch)

    // A timer started in the Clock app appears on its own.
    let fire = Date().addingTimeInterval(1.0)
    clock.change([ClockTimer(id: "a", state: .running(fireDate: fire), duration: 60)])
    check("a Clock timer shows as the compact countdown", timer.phase == .running(endDate: fire) && model.resting == .timer
          && model.restingSize == CGSize(width: notch.width + 2 * NotchStyle.timerEarWidth, height: notch.height))
    await wait(1.2)
    check("reaching zero shows it finished", timer.isDone && model.resting == .timerDone && model.restingSize == model.timerAlertSize)
    clock.change([ClockTimer(id: "a", state: .stopped, duration: 60, firedDate: fire)])
    check("still finished once Clock records it", timer.isDone)
    clock.change([ClockTimer(id: "a", state: .stopped, duration: 60, firedDate: fire, dismissedDate: Date())])
    check("stopping it in Clock clears the island", timer.phase == .idle)

    // Controls go through the shortcuts, with the island updated right away.
    shortcuts.onRun = { name, input in
        if name == TimerCommand.start.shortcutName, let seconds = input.flatMap(Double.init) {
            clock.records = [ClockTimer(id: "b", state: .running(fireDate: Date().addingTimeInterval(seconds)), duration: seconds)]
        }
    }
    actions.start(300)
    check("starting shows it immediately", timer.isRunning && timer.duration == 300)
    await wait(0.9)
    check("runs the Start shortcut with the length in seconds", shortcuts.ran.last.map { $0.0 == "NotchIsland Start Timer" && $0.1 == "300" } == true)
    check("then shows Clock's own record", timer.isRunning && abs(timer.remaining() - 300) < 2)

    shortcuts.onRun = { name, _ in
        switch name {
        case TimerCommand.pause.shortcutName: clock.records = [ClockTimer(id: "b", state: .paused(remaining: 299), duration: 300)]
        case TimerCommand.resume.shortcutName: clock.records = [ClockTimer(id: "b", state: .running(fireDate: Date().addingTimeInterval(299)), duration: 300)]
        case TimerCommand.cancel.shortcutName: clock.records = [ClockTimer(id: "b", state: .stopped, duration: 300)]
        default: break
        }
    }
    actions.pause()
    check("pause shows paused right away", timer.isPaused)
    clock.onChange?()  // a store change while the command runs doesn't flicker back
    check("no flicker while the shortcut runs", timer.isPaused)
    await wait(0.9)
    check("pause ran the shortcut", shortcuts.ran.last?.0 == "NotchIsland Pause Timer" && timer.phase == .paused(remaining: 299))
    actions.resume()
    await wait(0.9)
    check("resume", shortcuts.ran.last?.0 == "NotchIsland Resume Timer" && timer.isRunning)
    actions.cancel()
    check("cancel clears it right away", timer.phase == .idle)
    await wait(0.9)
    check("cancel ran the shortcut", shortcuts.ran.last?.0 == "NotchIsland Cancel Timer" && timer.phase == .idle)

    // A failed shortcut puts the real state back.
    shortcuts.onRun = nil
    shortcuts.succeeds = false
    clock.records = [ClockTimer(id: "c", state: .running(fireDate: Date().addingTimeInterval(500)), duration: 600)]
    clock.onChange?()
    actions.pause()
    check("optimistic pause", timer.isPaused)
    await wait(0.4)
    check("failure restores Clock's state", timer.isRunning)
    shortcuts.succeeds = true

    // Finished timers: Stop closes it; Repeat starts the same length again.
    let fired = Date().addingTimeInterval(-3)
    clock.change([ClockTimer(id: "d", state: .stopped, duration: 90, firedDate: fired)])
    check("a ringing Clock timer", timer.isDone && timer.duration == 90)
    actions.stop()
    check("Stop closes it in the island", timer.phase == .idle)
    await wait(0.9)
    check("and asks Clock to stop it", shortcuts.ran.last?.0 == "NotchIsland Cancel Timer")
    clock.change([ClockTimer(id: "e", state: .stopped, duration: 45, firedDate: Date())])
    shortcuts.ran = []
    actions.repeatLast()
    await wait(1.5)
    check("Repeat stops it and starts the same length", shortcuts.ran.map(\.0) == ["NotchIsland Cancel Timer", "NotchIsland Start Timer"] && shortcuts.ran.last?.1 == "45")

    // Without the shortcuts, buttons open Clock.
    shortcuts.names = []
    controller.refreshControls()
    await wait(0.1)
    clock.change([ClockTimer(id: "f", state: .running(fireDate: Date().addingTimeInterval(100)), duration: 100)])
    let before = shortcuts.ran.count
    actions.pause()
    actions.start(60)
    check("without shortcuts, controls open Clock", opened == 2 && shortcuts.ran.count == before && timer.isRunning)

    // With music: the timer holds the island and music moves to the bubble.
    play(nowPlaying)
    model.state = .collapsed
    check("timer outranks the music activity", model.resting == .timer && model.showsMusicBubble)
    model.state = .expanded
    check("no bubble when open; timer stacked above the player", !model.showsMusicBubble
          && model.expandedSize.height == NotchStyle.playerSize(forNotch: notch).height + NotchStyle.timerSectionHeight)
    model.state = .collapsed
    model.isFullScreen = true
    check("full screen hides the countdown and the bubble", model.resting == .notch && !model.showsMusicBubble)
    model.isFullScreen = false
}

@MainActor
func testStopwatchController() async {
    let (model, nowPlaying, timer, _) = makeModel("stopwatch")
    let store = FakeStopwatchStore()
    let shortcuts = FakeShortcuts()
    var opened = 0
    let controller = StopwatchController(model: model, runner: shortcuts, source: store, openClock: { opened += 1 })
    let actions = controller.actions
    let stopwatch = model.stopwatch
    let notch = model.notchSize

    store.records = [ClockStopwatch(id: "s", state: .stopped, offset: 0, previousLapsTotal: 0, lapCount: 0)]
    controller.start()
    await wait(0.1)
    check("finds the stopwatch shortcuts", stopwatch.controls == Set(StopwatchCommand.allCases))
    check("a reset stopwatch shows nothing", !stopwatch.isActive && model.resting == .notch)

    let since = Date().addingTimeInterval(-20)
    store.change([ClockStopwatch(id: "s", state: .running(since: since), offset: 2, previousLapsTotal: 40, lapCount: 1)])
    check("running in Clock: the compact stopwatch", stopwatch.isRunning && model.resting == .stopwatch
          && abs(stopwatch.elapsed() - 62) < 0.5 && stopwatch.lapCount == 1
          && model.restingSize == CGSize(width: notch.width + 2 * NotchStyle.timerEarWidth, height: notch.height))
    let started = stopwatch.phase
    store.onChange?()  // an unrelated write doesn't redraw
    check("the same record keeps the same display", stopwatch.phase == started)
    model.state = .expanded
    check("open island shows the stopwatch section", model.showsStopwatchSection && model.expandedSize == model.timerAlertSize)
    model.state = .collapsed

    shortcuts.onRun = { name, _ in
        switch name {
        case StopwatchCommand.stop.shortcutName: store.records = [ClockStopwatch(id: "s", state: .paused, offset: 23, previousLapsTotal: 40, lapCount: 1)]
        case StopwatchCommand.start.shortcutName: store.records = [ClockStopwatch(id: "s", state: .running(since: Date()), offset: 23, previousLapsTotal: 40, lapCount: 1)]
        case StopwatchCommand.lap.shortcutName: store.records = [ClockStopwatch(id: "s", state: .running(since: Date()), offset: 0, previousLapsTotal: 63, lapCount: 2)]
        case StopwatchCommand.reset.shortcutName: store.records = [ClockStopwatch(id: "s", state: .stopped, offset: 0, previousLapsTotal: 0, lapCount: 0)]
        default: break
        }
    }
    actions.toggle()
    check("stop pauses right away", stopwatch.isPaused)
    await wait(0.9)
    check("stop ran the shortcut and shows Clock's time", shortcuts.ran.last?.0 == "NotchIsland Stop Stopwatch" && stopwatch.phase == .paused(elapsed: 63))
    actions.toggle()
    await wait(0.9)
    check("start runs again from the same time", shortcuts.ran.last?.0 == "NotchIsland Start Stopwatch" && stopwatch.isRunning && abs(stopwatch.elapsed() - 63) < 1.5)
    actions.lapOrReset()
    check("lap counts right away", stopwatch.lapCount == 2)
    await wait(0.9)
    check("lap ran the shortcut", shortcuts.ran.last?.0 == "NotchIsland Lap Stopwatch" && stopwatch.lapCount == 2 && stopwatch.isRunning)
    actions.toggle()
    await wait(0.9)
    actions.lapOrReset()
    check("reset clears it right away", !stopwatch.isActive)
    await wait(0.9)
    check("reset ran the shortcut", shortcuts.ran.last?.0 == "NotchIsland Reset Stopwatch" && !stopwatch.isActive)

    // Priorities and the music bubble.
    store.change([ClockStopwatch(id: "s", state: .running(since: Date()), offset: 0, previousLapsTotal: 0, lapCount: 0)])
    play(nowPlaying)
    check("stopwatch over music, which moves to the bubble", model.resting == .stopwatch && model.showsMusicBubble)
    timer.show(.running(endDate: Date().addingTimeInterval(60)), duration: 60)
    check("a timer outranks the stopwatch", model.resting == .timer)
    model.state = .expanded
    check("open island shows the timer, not both", model.showsTimerSection && !model.showsStopwatchSection)
    model.state = .collapsed
    timer.show(.idle, duration: 0)

    // Without the shortcuts, the button opens Clock.
    shortcuts.names = []
    controller.refreshControls()
    await wait(0.1)
    let before = shortcuts.ran.count
    actions.toggle()
    actions.lapOrReset()
    check("without shortcuts, controls open Clock", opened == 2 && shortcuts.ran.count == before)
}

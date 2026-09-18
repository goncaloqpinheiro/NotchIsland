import AppKit

// `make test` compiles these files together with the app's sources (all but
// its main.swift) and runs them. Add --verbose to list every check.

@MainActor
func runTests() async {
    _ = NSApplication.shared  // menu actions are sent through NSApp
    let start = Date()
    await section("Glass and sizing") { testGlassAndSizing() }
    await section("Adaptive glass") { await testAdaptiveMaterial() }
    await section("Timer format") { testTimerFormat() }
    await section("Clock timer records") { testClockTimerParsing() }
    await section("Clock stopwatch records") { testStopwatchParsing() }
    await section("Timer model") { testTimerModel() }
    await section("Timer menu") { testTimerMenu() }
    await section("Timer controller") { await testTimerController() }
    await section("Stopwatch controller") { await testStopwatchController() }
    await section("Media glass") { await testMediaGlass() }
    await section("Focus") { await testFocus() }
    await section("AirPods and priorities") { await testAlertsAndPriorities() }
    await section("Lock") { await testLock() }
    await section("Lock, display asleep") { await testLockWhileAsleep() }
    await section("Lock, side style") { await testLockSide() }
    ScratchDefaults.removeAll()

    let seconds = Int(Date().timeIntervalSince(start).rounded())
    if Checks.failed == 0 {
        print("All \(Checks.passed) checks passed in \(seconds) s.")
        exit(0)
    } else {
        print("\(Checks.failed) of \(Checks.passed + Checks.failed) checks failed.")
        exit(1)
    }
}

Task { @MainActor in await runTests() }
RunLoop.main.run()

import Foundation

/// Stands in for Clock's timer preferences.
@MainActor
final class FakeClock: ClockTimerSource {
    var onChange: (() -> Void)?
    var records: [ClockTimer] = []
    func start() {}
    func timers() -> [ClockTimer] { records }
    func change(_ records: [ClockTimer]) { self.records = records; onChange?() }
}

/// Stands in for Clock's stopwatch preferences.
@MainActor
final class FakeStopwatchStore: ClockStopwatchSource {
    var onChange: (() -> Void)?
    var records: [ClockStopwatch] = []
    func start() {}
    func stopwatches() -> [ClockStopwatch] { records }
    func change(_ records: [ClockStopwatch]) { self.records = records; onChange?() }
}

/// Stands in for the Shortcuts tool, so no real shortcut ever runs.
@MainActor
final class FakeShortcuts: ShortcutRunner {
    var names: Set<String> = Set(TimerCommand.allCases.map(\.shortcutName) + StopwatchCommand.allCases.map(\.shortcutName))
    var ran: [(String, String?)] = []
    var succeeds = true
    var onRun: ((String, String?) -> Void)?
    func shortcutNames() async -> Set<String> { names }
    func run(_ name: String, input: String?) async -> Bool {
        ran.append((name, input))
        try? await Task.sleep(for: .seconds(0.1))  // like the real tool, it takes a moment
        onRun?(name, input)
        return succeeds
    }
}

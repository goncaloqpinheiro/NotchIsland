import SwiftUI

/// Mirrors the Clock app's stopwatch in the island, like the Dynamic Island.
/// Reads it live from Clock's timer daemon (`ClockStopwatchStore`) and, when the
/// shortcuts exist, starts, stops, laps and resets it through Clock's own
/// Shortcuts actions; otherwise the button opens Clock. The elapsed time (whole
/// seconds) is redrawn once a second only while on screen; nothing else ticks.
@MainActor
final class StopwatchController {
    private let model: NotchViewModel
    private let source: ClockStopwatchSource
    private let runner: ShortcutRunner
    private let openClock: () -> Void
    private var stopwatch: StopwatchModel { model.stopwatch }
    /// Commands started but not finished; the stored state lags behind until they are.
    private var pending = 0
    private var lastCommand: Task<Void, Never>?

    init(model: NotchViewModel, runner: ShortcutRunner, source: ClockStopwatchSource? = nil,
         openClock: (() -> Void)? = nil) {
        self.model = model
        self.runner = runner
        self.source = source ?? ClockStopwatchStore()
        self.openClock = openClock ?? { ClockApp.openStopwatch() }
    }

    func start() {
        source.onChange = { [weak self] in self?.refresh(animated: true) }
        source.start()
        refresh(animated: false)
        refreshControls()
    }

    /// Looks for the shortcuts again (they may have been added since).
    func refreshControls() {
        Task { [weak self] in
            guard let self else { return }
            let available = StopwatchCommand.available(in: await self.runner.shortcutNames())
            if self.stopwatch.controls != available {
                self.stopwatch.controls = available
                Log.app.info("Stopwatch controls: \(available.map(\.rawValue).sorted().joined(separator: ", "), privacy: .public)")
            }
        }
    }

    var actions: StopwatchActions {
        StopwatchActions(
            toggle: { [weak self] in self?.toggle() },
            lapOrReset: { [weak self] in self?.lapOrReset() },
            openClock: { [weak self] in self?.openClock() }
        )
    }

    // MARK: - Actions

    /// Stops a running stopwatch, or starts a paused one again.
    func toggle() {
        let command: StopwatchCommand = stopwatch.isPaused ? .start : .stop
        guard stopwatch.controls.contains(command) else { return openClock() }
        let elapsed = stopwatch.elapsed()
        withAnimation(NotchStyle.expand) {
            stopwatch.show(command == .start ? .running(start: .now.addingTimeInterval(-elapsed)) : .paused(elapsed: elapsed),
                           lapCount: stopwatch.lapCount)
        }
        perform(command)
    }

    /// Laps a running stopwatch, or resets a paused one.
    func lapOrReset() {
        let command: StopwatchCommand = stopwatch.isPaused ? .reset : .lap
        guard stopwatch.controls.contains(command) else { return openClock() }
        if command == .reset {
            withAnimation(NotchStyle.collapse) { stopwatch.show(.idle) }
        } else {
            stopwatch.show(stopwatch.phase, lapCount: stopwatch.lapCount + 1)
        }
        perform(command)
    }

    private func perform(_ command: StopwatchCommand) {
        pending += 1
        let previous = lastCommand
        lastCommand = Task { [weak self] in
            await previous?.value
            guard let self else { return }
            let succeeded = await self.runner.run(command.shortcutName, input: nil)
            if !succeeded {
                self.refreshControls()
            }
            self.pending -= 1
            guard self.pending == 0 else { return }
            if succeeded {
                try? await Task.sleep(for: .seconds(0.6))  // the daemon records it just after
            }
            self.refresh(animated: true)
        }
    }

    // MARK: - Reading Clock's stopwatch

    private func refresh(animated: Bool) {
        guard pending == 0 else { return }
        let now = Date.now
        let stopwatches = source.stopwatches()
        let shown = stopwatches.first { if case .running = $0.state { return true }; return false }
            ?? stopwatches.first { $0.state == .paused }
        let phase: StopwatchModel.Phase = switch shown?.state {
        case .running?: .running(start: now.addingTimeInterval(-(shown?.elapsed(at: now) ?? 0)))
        case .paused?: .paused(elapsed: shown?.elapsed(at: now) ?? 0)
        case .stopped?, nil: .idle
        }
        let lapCount = shown?.lapCount ?? 0
        // A running stopwatch's start moves by microseconds between reads; ignore that.
        guard !Self.isSameDisplay(phase, stopwatch.phase) || lapCount != stopwatch.lapCount else { return }
        if let shown {
            Log.app.info("Stopwatch: \(String(describing: shown.state), privacy: .public), offset \(shown.offset, privacy: .public) s, laps \(shown.lapCount, privacy: .public) totalling \(shown.previousLapsTotal, privacy: .public) s")
        } else {
            Log.app.info("Stopwatch: none")
        }
        withAnimation(animated ? NotchStyle.expand : nil) {
            stopwatch.show(phase, lapCount: lapCount)
        }
    }

    private static func isSameDisplay(_ a: StopwatchModel.Phase, _ b: StopwatchModel.Phase) -> Bool {
        switch (a, b) {
        case (.running(let x), .running(let y)): abs(x.timeIntervalSince(y)) < 0.05
        case (.paused(let x), .paused(let y)): abs(x - y) < 0.05
        case (.idle, .idle): true
        default: false
        }
    }
}

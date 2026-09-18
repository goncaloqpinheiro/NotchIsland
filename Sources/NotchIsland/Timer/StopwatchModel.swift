import Foundation
import Observation

/// The Clock app stopwatch the island shows (see `StopwatchController`).
@MainActor
@Observable
final class StopwatchModel {
    enum Phase: Equatable {
        case idle
        /// `start` is when it would have started had it never paused (now minus the time on it).
        case running(start: Date)
        case paused(elapsed: TimeInterval)
    }

    private(set) var phase = Phase.idle
    private(set) var lapCount = 0
    /// What NotchIsland can do to Clock's stopwatch (the shortcuts that exist).
    var controls: Set<StopwatchCommand> = []

    var isRunning: Bool {
        if case .running = phase { return true }
        return false
    }

    var isPaused: Bool {
        if case .paused = phase { return true }
        return false
    }

    var isActive: Bool { phase != .idle }

    /// Stop while running, or start again while paused.
    var canToggle: Bool { controls.contains(isPaused ? .start : .stop) }

    /// Lap while running, or reset while paused.
    var canLapOrReset: Bool { controls.contains(isPaused ? .reset : .lap) }

    func elapsed(at date: Date = .now) -> TimeInterval {
        switch phase {
        case .running(let start): max(0, date.timeIntervalSince(start))
        case .paused(let elapsed): elapsed
        case .idle: 0
        }
    }

    /// Only assigns what changed, so views don't redraw for identical updates.
    func show(_ phase: Phase, lapCount: Int = 0) {
        if self.phase != phase { self.phase = phase }
        if self.lapCount != lapCount { self.lapCount = lapCount }
    }
}

import Foundation
import Observation

/// The Clock app timer the island shows (see `TimerController`).
@MainActor
@Observable
final class TimerModel {
    enum Phase: Equatable {
        case idle
        case running(endDate: Date)
        case paused(remaining: TimeInterval)
        /// Went off; the Clock app rings until it's stopped.
        case done
    }

    private(set) var phase = Phase.idle
    /// The timer's full length, for Repeat.
    private(set) var duration: TimeInterval = 0
    /// A label given in Clock or with Siri, if any.
    private(set) var title: String?
    /// What NotchIsland can do to Clock timers (the shortcuts that exist).
    var controls: Set<TimerCommand> = []

    var isRunning: Bool {
        if case .running = phase { return true }
        return false
    }

    var isPaused: Bool {
        if case .paused = phase { return true }
        return false
    }

    /// Counting down, or paused partway.
    var isActive: Bool { isRunning || isPaused }

    var isDone: Bool { phase == .done }

    var canStart: Bool { controls.contains(.start) }

    /// Pause while running, or resume while paused.
    var canToggle: Bool { controls.contains(isPaused ? .resume : .pause) }

    var canCancel: Bool { controls.contains(.cancel) }

    func remaining(at date: Date = .now) -> TimeInterval {
        switch phase {
        case .running(let endDate): max(0, endDate.timeIntervalSince(date))
        case .paused(let remaining): remaining
        case .idle, .done: 0
        }
    }

    /// Only assigns what changed, so views don't redraw for identical updates.
    func show(_ phase: Phase, duration: TimeInterval, title: String? = nil) {
        if self.phase != phase { self.phase = phase }
        if self.duration != duration { self.duration = duration }
        if self.title != title { self.title = title }
    }
}

import Foundation

/// Stopwatch actions the island's views can trigger.
struct StopwatchActions {
    /// Stop while running, start again while paused.
    var toggle: () -> Void = {}
    /// Lap while running, reset while paused.
    var lapOrReset: () -> Void = {}
    var openClock: () -> Void = {}
}

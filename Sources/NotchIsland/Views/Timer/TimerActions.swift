import Foundation

/// Timer actions the island's views can trigger.
struct TimerActions {
    var start: (TimeInterval) -> Void = { _ in }
    var pause: () -> Void = {}
    var resume: () -> Void = {}
    var cancel: () -> Void = {}
    /// Closes a finished timer, and stops it in Clock when possible.
    var stop: () -> Void = {}
    /// Starts the finished timer again with the same length.
    var repeatLast: () -> Void = {}
    var openClock: () -> Void = {}
}

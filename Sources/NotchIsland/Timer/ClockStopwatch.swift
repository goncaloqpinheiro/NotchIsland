import Foundation

/// The Clock app's stopwatch, as its timer daemon stores it in its preferences
/// (`com.apple.mobiletimerd` → `MTStopwatches`).
struct ClockStopwatch: Equatable, Sendable {
    enum State: Equatable, Sendable {
        /// Reset: nothing to show.
        case stopped
        case paused
        /// Running since the current run began.
        case running(since: Date)
    }

    var id: String
    var state: State
    /// Time on the current lap before the current run began.
    var offset: TimeInterval
    /// All finished laps together.
    var previousLapsTotal: TimeInterval
    var lapCount: Int

    /// Total time on the stopwatch, laps included.
    func elapsed(at now: Date) -> TimeInterval {
        var currentLap = offset
        if case .running(let since) = state {
            currentLap += max(0, now.timeIntervalSince(since))
        }
        return previousLapsTotal + currentLap
    }
}

// MARK: - Reading the daemon's preferences

extension ClockStopwatch {
    /// The daemon's state numbers (from MobileTimer's own descriptions).
    private enum StoredState: Int {
        case stopped = 0, paused = 1, running = 2
    }

    /// Reads the `MTStopwatches` preference: `{"MTStopwatches": [{"$MTStopwatch": {…}}]}`.
    static func stopwatches(fromPreference value: Any?) -> [ClockStopwatch] {
        let list = ((value as? [String: Any])?["MTStopwatches"] as? [Any]) ?? (value as? [Any]) ?? []
        return list.compactMap { element in
            guard let wrapper = element as? [String: Any] else { return nil }
            return ClockStopwatch(fields: (wrapper["$MTStopwatch"] as? [String: Any]) ?? wrapper)
        }
    }

    init?(fields: [String: Any]) {
        guard let id = fields["MTStopwatchIdentifier"] as? String else { return nil }
        self.id = id
        offset = (fields["MTStopwatchOffset"] as? NSNumber)?.doubleValue ?? 0
        previousLapsTotal = (fields["MTStopwatchPreviousLapsTotalInterval"] as? NSNumber)?.doubleValue ?? 0
        lapCount = (fields["MTStopwatchLaps"] as? [Any])?.count ?? 0
        switch StoredState(rawValue: (fields["MTStopwatchState"] as? NSNumber)?.intValue ?? 0) {
        case .running?:
            if let since = Self.date(fields["MTStopwatchStartDate"]) {
                state = .running(since: since)
            } else {
                state = .paused  // no start moment recorded: show the time so far
            }
        case .paused?:
            state = .paused
        case .stopped?, nil:
            state = .stopped
        }
    }

    private static func date(_ value: Any?) -> Date? {
        switch value {
        case let date as Date: date
        case let seconds as NSNumber: Date(timeIntervalSinceReferenceDate: seconds.doubleValue)
        default: nil
        }
    }
}

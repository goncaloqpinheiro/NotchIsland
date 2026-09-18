import Foundation

/// A timer from the Clock app. Its timer daemon (mobiletimerd) keeps them in its
/// preferences, `com.apple.mobiletimerd` → `MTTimers`, one dictionary per timer.
struct ClockTimer: Equatable, Sendable {
    enum State: Equatable, Sendable {
        case stopped
        case paused(remaining: TimeInterval)
        case running(fireDate: Date)
    }

    var id: String
    var state: State
    var duration: TimeInterval
    /// A label given in Clock or with Siri, if any.
    var title: String?
    var firedDate: Date?
    var dismissedDate: Date?
    var lastModified: Date?

    /// When it went off, if it has and hasn't been stopped since.
    func wentOff(at now: Date) -> Date? {
        switch state {
        case .running(let fireDate) where fireDate <= now:
            return fireDate  // the daemon hasn't recorded it yet
        case .stopped:
            guard let firedDate, dismissedDate.map({ $0 < firedDate }) ?? true else { return nil }
            return firedDate
        default:
            return nil
        }
    }

    /// Ringing, as far as the stored state shows, for at most `limit` after going off.
    func isRinging(at now: Date, limit: TimeInterval) -> Bool {
        guard let wentOff = wentOff(at: now) else { return false }
        return now.timeIntervalSince(wentOff) < limit
    }
}

// MARK: - Reading the daemon's preferences

extension ClockTimer {
    /// The daemon's state numbers (from MobileTimer's own descriptions).
    private enum StoredState: Int {
        case stopped = 1, paused = 2, running = 3
    }

    /// Reads the `MTTimers` preference: `{"MTTimers": [{"$MTTimer": {…}}, …]}`.
    static func timers(fromPreference value: Any?) -> [ClockTimer] {
        let list = ((value as? [String: Any])?["MTTimers"] as? [Any]) ?? (value as? [Any]) ?? []
        return list.compactMap { element in
            guard let wrapper = element as? [String: Any] else { return nil }
            return ClockTimer(fields: (wrapper["$MTTimer"] as? [String: Any]) ?? wrapper)
        }
    }

    /// Paused and stopped timers store the time left (`$MTTimerTimeInterval`); running
    /// ones the moment they go off (`$MTTimerDate`).
    init?(fields: [String: Any]) {
        guard let id = fields["MTTimerID"] as? String else { return nil }
        self.id = id
        duration = (fields["MTTimerDuration"] as? NSNumber)?.doubleValue ?? 0
        let fireTime = fields["MTTimerFireTime"]
        switch StoredState(rawValue: (fields["MTTimerState"] as? NSNumber)?.intValue ?? 1) {
        case .running?:
            guard let fireDate = Self.date(in: fireTime) else { return nil }
            state = .running(fireDate: fireDate)
        case .paused?:
            state = .paused(remaining: Self.number(for: "MTTimerTimeInterval", in: fireTime) ?? duration)
        case .stopped?, nil:
            state = .stopped
        }
        let label = (fields["MTTimerUserTitle"] as? String) ?? (fields["MTTimerTitle"] as? String)
        title = label.flatMap { $0.isEmpty || $0 == "CURRENT_TIMER" ? nil : $0 }
        firedDate = fields["MTTimerFiredDate"] as? Date
        dismissedDate = fields["MTTimerDismissedDate"] as? Date
        lastModified = fields["MTTimerLastModifiedDate"] as? Date
    }

    /// The first date anywhere in a nested value (or a reference-date timestamp under a date key).
    private static func date(in value: Any?) -> Date? {
        switch value {
        case let date as Date:
            return date
        case let dictionary as [String: Any]:
            if let seconds = dictionary["MTTimerTimeDate"] as? NSNumber {
                return Date(timeIntervalSinceReferenceDate: seconds.doubleValue)
            }
            return dictionary.values.lazy.compactMap { date(in: $0) }.first
        default:
            return nil
        }
    }

    private static func number(for key: String, in value: Any?) -> Double? {
        guard let dictionary = value as? [String: Any] else { return nil }
        if let number = dictionary[key] as? NSNumber {
            return number.doubleValue
        }
        return dictionary.values.lazy.compactMap { number(for: key, in: $0) }.first
    }
}

/// Which Clock timer the island shows: one that's ringing, else the next to go
/// off, else the most recently paused.
struct TimerDisplay: Equatable {
    var phase: TimerModel.Phase
    var timer: ClockTimer?

    static func pick(from timers: [ClockTimer], at now: Date, ringingLimit: TimeInterval,
                     ignoring closed: Set<String> = []) -> TimerDisplay {
        let ringing = timers.filter { $0.isRinging(at: now, limit: ringingLimit) && !closed.contains($0.id) }
        if let latest = ringing.max(by: { ($0.wentOff(at: now) ?? .distantPast) < ($1.wentOff(at: now) ?? .distantPast) }) {
            return TimerDisplay(phase: .done, timer: latest)
        }
        let running = timers.compactMap { timer -> (ClockTimer, Date)? in
            guard case .running(let fireDate) = timer.state, fireDate > now else { return nil }
            return (timer, fireDate)
        }
        if let (timer, fireDate) = running.min(by: { $0.1 < $1.1 }) {
            return TimerDisplay(phase: .running(endDate: fireDate), timer: timer)
        }
        let paused = timers.compactMap { timer -> (ClockTimer, TimeInterval)? in
            guard case .paused(let remaining) = timer.state else { return nil }
            return (timer, remaining)
        }
        if let (timer, remaining) = paused.max(by: { ($0.0.lastModified ?? .distantPast) < ($1.0.lastModified ?? .distantPast) }) {
            return TimerDisplay(phase: .paused(remaining: remaining), timer: timer)
        }
        return TimerDisplay(phase: .idle, timer: nil)
    }
}

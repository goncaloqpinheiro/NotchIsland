import Foundation

/// Reading and writing timer durations.
enum TimerFormat {
    /// Quick durations offered in the island and the menu, in minutes.
    static let presetMinutes = [1, 3, 5, 10, 15, 30]

    /// "4:59", or "1:02:03" from an hour up. Partial seconds round up, as a countdown shows them.
    static func clock(_ seconds: TimeInterval) -> String {
        format(Int(settled(seconds).rounded(.up)))
    }

    /// A stopwatch's "0:42", or "1:02:03" from an hour up, in whole seconds (no fractions).
    static func elapsed(_ seconds: TimeInterval) -> String {
        format(Int(settled(seconds).rounded(.down)))
    }

    /// When a countdown next shows a new second: its end date minus a whole
    /// number of seconds, at or before `now`. Redrawing on those moments (and
    /// only then) keeps the text exact without ticking every frame.
    static func countdownTick(endDate: Date, now: Date) -> Date {
        endDate.addingTimeInterval(-settled(endDate.timeIntervalSince(now)).rounded(.up))
    }

    private static func format(_ total: Int) -> String {
        let hours = total / 3600, minutes = total / 60 % 60, secs = total % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, secs)
            : String(format: "%d:%02d", minutes, secs)
    }

    /// Date arithmetic lands a hair off whole seconds (e.g. 4.9999999 instead of
    /// 5), which would show the wrong second for a whole second; settle to the millisecond.
    private static func settled(_ seconds: TimeInterval) -> TimeInterval {
        (max(0, seconds) * 1000).rounded() / 1000
    }

    /// "5 Minutes" or "1 Hour, 30 Minutes", for menus.
    static func spoken(_ seconds: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .full
        formatter.allowedUnits = [.hour, .minute, .second]
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US")  // the rest of the app is in English
        formatter.calendar = calendar
        return formatter.string(from: seconds.rounded())?.capitalized ?? clock(seconds)
    }

    /// Reads what someone types for a custom timer: "25" (minutes), "1.5", "1:30"
    /// (minutes and seconds), "1:00:00", or units like "1h 15m", "90s". Between
    /// one second and a day.
    static func parse(_ text: String) -> TimeInterval? {
        let input = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !input.isEmpty else { return nil }
        let seconds: Double?
        if let minutes = Double(input) {
            seconds = minutes * 60
        } else if input.contains(":") {
            seconds = parseClock(input)
        } else {
            seconds = parseUnits(input)
        }
        guard let seconds, seconds.isFinite, (1...86_400).contains(seconds.rounded()) else { return nil }
        return seconds.rounded()
    }

    private static func parseClock(_ input: String) -> Double? {
        let parts = input.split(separator: ":", omittingEmptySubsequences: false)
            .map { Double($0.trimmingCharacters(in: .whitespaces)) }
        guard (2...3).contains(parts.count), parts.allSatisfy({ ($0 ?? -1) >= 0 }) else { return nil }
        return parts.reduce(0) { $0 * 60 + ($1 ?? 0) }
    }

    private static func parseUnits(_ input: String) -> Double? {
        let scanner = Scanner(string: input.replacingOccurrences(of: ",", with: " ")
                                           .replacingOccurrences(of: " and ", with: " "))
        scanner.charactersToBeSkipped = .whitespaces
        var total = 0.0
        var readAny = false
        while !scanner.isAtEnd {
            guard let value = scanner.scanDouble(), let unit = scanner.scanCharacters(from: .letters) else { return nil }
            switch unit {
            case "h", "hr", "hrs", "hour", "hours": total += value * 3600
            case "m", "min", "mins", "minute", "minutes": total += value * 60
            case "s", "sec", "secs", "second", "seconds": total += value
            default: return nil
            }
            readAny = true
        }
        return readAny ? total : nil
    }
}

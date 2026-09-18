import Foundation

/// Where the island's timers come from.
@MainActor
protocol ClockTimerSource: AnyObject {
    var onChange: (() -> Void)? { get set }
    func start()
    func timers() -> [ClockTimer]
}

/// Where the island's stopwatch comes from.
@MainActor
protocol ClockStopwatchSource: AnyObject {
    var onChange: (() -> Void)? { get set }
    func start()
    func stopwatches() -> [ClockStopwatch]
}

/// One value in the Clock app's timer daemon preferences (`com.apple.mobiletimerd`).
/// cfprefsd tells key-value observers about changes other processes make, so
/// every start, pause, lap or reset (in Clock, with Siri, from Control Center)
/// arrives right away, with no polling and no permission.
@MainActor
final class ClockPreference: NSObject {
    var onChange: (() -> Void)?
    private let key: String
    private let defaults = UserDefaults(suiteName: "com.apple.mobiletimerd")
    private var isObserving = false

    init(key: String) {
        self.key = key
    }

    var value: Any? { defaults?.object(forKey: key) }

    func start() {
        guard !isObserving, let defaults else { return }
        defaults.addObserver(self, forKeyPath: key, options: [], context: nil)
        isObserving = true
    }

    nonisolated override func observeValue(forKeyPath keyPath: String?, of object: Any?,
                                           change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        // Changes from other processes arrive on a background queue.
        Task { @MainActor [weak self] in
            self?.onChange?()
        }
    }
}

@MainActor
final class ClockTimerStore: ClockTimerSource {
    private let preference = ClockPreference(key: "MTTimers")

    var onChange: (() -> Void)? {
        get { preference.onChange }
        set { preference.onChange = newValue }
    }

    func start() { preference.start() }

    func timers() -> [ClockTimer] {
        ClockTimer.timers(fromPreference: preference.value)
    }
}

@MainActor
final class ClockStopwatchStore: ClockStopwatchSource {
    private let preference = ClockPreference(key: "MTStopwatches")

    var onChange: (() -> Void)? {
        get { preference.onChange }
        set { preference.onChange = newValue }
    }

    func start() { preference.start() }

    func stopwatches() -> [ClockStopwatch] {
        ClockStopwatch.stopwatches(fromPreference: preference.value)
    }
}

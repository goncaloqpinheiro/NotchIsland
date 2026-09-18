import Foundation
import IOKit.ps

/// The MacBook's battery and power adapter.
struct PowerStatus: Equatable, Sendable {
    /// Percent, 0...100.
    var level: Int
    var isPluggedIn: Bool
    var isCharging: Bool

    /// The internal battery, or nil on a Mac without one.
    static func current() -> PowerStatus? {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else { return nil }
        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any],
                  description[kIOPSTypeKey] as? String == kIOPSInternalBatteryType else { continue }
            let current = description[kIOPSCurrentCapacityKey] as? Int ?? 0
            let maximum = description[kIOPSMaxCapacityKey] as? Int ?? 100
            return PowerStatus(level: maximum > 0 ? current * 100 / maximum : current,
                               isPluggedIn: description[kIOPSPowerSourceStateKey] as? String == kIOPSACPowerValue,
                               isCharging: description[kIOPSIsChargingKey] as? Bool ?? false)
        }
        return nil
    }
}

/// A battery moment worth showing in the notch.
enum PowerAlert: Equatable, Sendable {
    case charging(level: Int)
    case unplugged(level: Int)
    case low(level: Int)

    /// Warn when the battery drops to these levels, like the iPhone.
    static let lowLevels = [20, 10]

    /// What to show when the status changes from `old` to `new`, if anything.
    static func alert(from old: PowerStatus, to new: PowerStatus) -> PowerAlert? {
        if new.isPluggedIn && !old.isPluggedIn {
            return .charging(level: new.level)
        }
        if !new.isPluggedIn && old.isPluggedIn {
            return .unplugged(level: new.level)
        }
        if !new.isPluggedIn, lowLevels.contains(where: { new.level <= $0 && old.level > $0 }) {
            return .low(level: new.level)
        }
        return nil
    }

    var level: Int {
        switch self {
        case .charging(let level), .unplugged(let level), .low(let level): level
        }
    }
}

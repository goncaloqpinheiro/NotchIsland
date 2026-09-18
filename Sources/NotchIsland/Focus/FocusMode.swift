import Foundation

/// A Focus as the user set it up: name, symbol and color.
struct FocusMode: Equatable, Sendable {
    /// e.g. "com.apple.donotdisturb.mode.default" for Do Not Disturb.
    var identifier: String
    var name: String
    /// SF Symbol name.
    var symbol: String
    /// A system color name, e.g. "systemIndigoColor".
    var tintName: String

    /// Apple's built-in Focuses, for when the configuration file lacks a detail.
    static func builtIn(_ identifier: String) -> FocusMode {
        let (name, symbol, tint): (String, String, String) = switch identifier {
        case "com.apple.donotdisturb.mode.default": ("Do Not Disturb", "moon.fill", "systemIndigoColor")
        case "com.apple.sleep.sleep-mode": ("Sleep", "bed.double.fill", "systemMintColor")
        case "com.apple.donotdisturb.mode.driving": ("Driving", "car.fill", "systemBlueColor")
        case "com.apple.focus.personal-time": ("Personal", "person.fill", "systemPurpleColor")
        case "com.apple.focus.work": ("Work", "lanyardcard.fill", "systemTealColor")
        case "com.apple.donotdisturb.mode.workout": ("Fitness", "figure.run", "systemGreenColor")
        case "com.apple.focus.gaming": ("Gaming", "gamecontroller.fill", "systemBlueColor")
        case "com.apple.focus.mindfulness": ("Mindfulness", "brain.head.profile", "systemTealColor")
        case "com.apple.focus.reading": ("Reading", "book.fill", "systemOrangeColor")
        case "com.apple.focus.reduce-interruptions": ("Reduce Interruptions", "moon.fill", "systemIndigoColor")
        default: ("Focus", "moon.fill", "systemIndigoColor")
        }
        return FocusMode(identifier: identifier, name: name, symbol: symbol, tintName: tint)
    }
}

/// A Focus turning on or off.
struct FocusAlert: Equatable, Sendable {
    var mode: FocusMode
    var isOn: Bool
}

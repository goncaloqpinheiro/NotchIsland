import Foundation
import Observation

/// User preferences, persisted in UserDefaults.
@MainActor
@Observable
final class AppSettings {
    private enum Key {
        static let notchWidthOffset = "notchWidthOffset"
        static let notchHeightOffset = "notchHeightOffset"
        static let hoverDelay = "hoverDelay"
        static let hapticsEnabled = "hapticsEnabled"
        static let blurStrength = "blurStrength"
        static let showsSystemHUD = "showsSystemHUD"
        static let didPromptForAccessibility = "didPromptForAccessibility"
        static let showsDeviceAlerts = "showsDeviceAlerts"
        static let playsSounds = "playsSounds"
        static let showsFocus = "showsFocus"
        static let glassStyle = "glassStyle"
        static let lockStyle = "lockStyle"
        static let glassTint = "glassTint"
        static let glassAdapts = "glassAdaptive"
    }

    /// Points added to the detected notch width (negative shrinks it).
    var notchWidthOffset: Double {
        didSet { defaults.set(notchWidthOffset, forKey: Key.notchWidthOffset) }
    }

    /// Points added to the detected notch height (negative shrinks it).
    var notchHeightOffset: Double {
        didSet { defaults.set(notchHeightOffset, forKey: Key.notchHeightOffset) }
    }

    /// Seconds the cursor has to stay on the notch before the island opens,
    /// so sweeping across the menu bar doesn't pop it open.
    var hoverDelay: Double {
        didSet { defaults.set(hoverDelay, forKey: Key.hoverDelay) }
    }

    /// Trackpad tick when the island opens.
    var hapticsEnabled: Bool {
        didSet { defaults.set(hapticsEnabled, forKey: Key.hapticsEnabled) }
    }

    /// Opacity of the glass around the hovered or open island, 0...1 (0 = off).
    var blurStrength: Double {
        didSet { defaults.set(blurStrength, forKey: Key.blurStrength) }
    }

    /// Which material shows behind the island.
    var glass: IslandGlass {
        didSet { defaults.set(glass.rawValue, forKey: Key.glassStyle) }
    }

    /// A color for the glass, or nil for its natural look (the default).
    var glassTint: GlassTint? {
        didSet {
            if let glassTint {
                defaults.set(glassTint.stored, forKey: Key.glassTint)
            } else {
                defaults.removeObject(forKey: Key.glassTint)
            }
        }
    }

    /// Glass that takes its color from whatever is behind it, instead of a set
    /// color or its natural grey. The default, unless a custom color was picked
    /// before it existed.
    var glassAdapts: Bool {
        didSet { defaults.set(glassAdapts, forKey: Key.glassAdapts) }
    }

    /// How the lock shows while locked and when unlocking.
    var lockStyle: LockStyle {
        didSet { defaults.set(lockStyle.rawValue, forKey: Key.lockStyle) }
    }

    /// Volume and brightness keys show their level in the notch instead of the system indicator.
    var showsSystemHUD: Bool {
        didSet { defaults.set(showsSystemHUD, forKey: Key.showsSystemHUD) }
    }

    /// The Accessibility prompt is shown once automatically; later only from Settings.
    var didPromptForAccessibility: Bool {
        didSet { defaults.set(didPromptForAccessibility, forKey: Key.didPromptForAccessibility) }
    }

    /// AirPods connecting, charger plugged in or out, low battery.
    var showsDeviceAlerts: Bool {
        didSet { defaults.set(showsDeviceAlerts, forKey: Key.showsDeviceAlerts) }
    }

    /// Lock, unlock, AirPods, low battery and timer sounds.
    var playsSounds: Bool {
        didSet { defaults.set(playsSounds, forKey: Key.playsSounds) }
    }

    /// A Focus turning on or off shows in the notch (needs Full Disk Access).
    var showsFocus: Bool {
        didSet { defaults.set(showsFocus, forKey: Key.showsFocus) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        defaults.register(defaults: [Key.hoverDelay: 0.15, Key.hapticsEnabled: true, Key.blurStrength: 0.3, Key.showsSystemHUD: true,
                                     Key.showsDeviceAlerts: true, Key.playsSounds: true, Key.showsFocus: true])
        self.defaults = defaults
        notchWidthOffset = defaults.double(forKey: Key.notchWidthOffset)
        notchHeightOffset = defaults.double(forKey: Key.notchHeightOffset)
        hoverDelay = defaults.double(forKey: Key.hoverDelay)
        hapticsEnabled = defaults.bool(forKey: Key.hapticsEnabled)
        blurStrength = defaults.double(forKey: Key.blurStrength)
        glass = IslandGlass(rawValue: defaults.string(forKey: Key.glassStyle) ?? "") ?? .frosted
        lockStyle = LockStyle(rawValue: defaults.string(forKey: Key.lockStyle) ?? "") ?? .centered
        let storedTint = GlassTint(stored: defaults.array(forKey: Key.glassTint))
        glassTint = storedTint
        glassAdapts = defaults.object(forKey: Key.glassAdapts) as? Bool ?? (storedTint == nil)
        showsSystemHUD = defaults.bool(forKey: Key.showsSystemHUD)
        didPromptForAccessibility = defaults.bool(forKey: Key.didPromptForAccessibility)
        showsDeviceAlerts = defaults.bool(forKey: Key.showsDeviceAlerts)
        playsSounds = defaults.bool(forKey: Key.playsSounds)
        showsFocus = defaults.bool(forKey: Key.showsFocus)
    }

    func resetNotchSize() {
        notchWidthOffset = 0
        notchHeightOffset = 0
    }
}

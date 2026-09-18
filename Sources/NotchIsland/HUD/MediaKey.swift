import AppKit

/// The keyboard's volume and brightness keys. macOS delivers them as "system
/// defined" events (subtype 8) whose data1 packs the key code and state.
enum MediaKey: Equatable, Sendable {
    case volumeUp, volumeDown, mute, brightnessUp, brightnessDown

    /// NX_KEYTYPE_* codes from IOKit's ev_keymap.h.
    init?(code: Int) {
        switch code {
        case 0: self = .volumeUp
        case 1: self = .volumeDown
        case 7: self = .mute
        case 2: self = .brightnessUp
        case 3: self = .brightnessDown
        default: return nil
        }
    }

    struct Event: Equatable, Sendable {
        let key: MediaKey
        let isDown: Bool
        let isRepeat: Bool
    }

    /// Decodes a system-defined event's subtype and data1; nil for anything else.
    static func decode(subtype: Int16, data1: Int) -> Event? {
        guard subtype == 8, let key = MediaKey(code: (data1 & 0xFFFF_0000) >> 16) else { return nil }
        let flags = data1 & 0xFFFF
        return Event(key: key, isDown: (flags & 0xFF00) >> 8 == 0x0A, isRepeat: flags & 0x1 != 0)
    }
}

/// Moves a 0...1 level to the next notch in a direction, the way macOS does,
/// so presses always land on the same 16 (or 64 fine) steps.
enum LevelStep {
    static func next(from level: Float, step: Float, up: Bool) -> Float {
        let notches = level / step
        let target = up ? (notches + 0.001).rounded(.down) + 1 : (notches - 0.001).rounded(.up) - 1
        return min(max(target * step, 0), 1)
    }
}

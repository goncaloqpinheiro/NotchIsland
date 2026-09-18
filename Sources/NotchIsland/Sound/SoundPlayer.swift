import AppKit

/// iPhone-style UI sounds, played from sound files that ship with macOS (used
/// in place, never copied into the app). A missing file is simply skipped.
enum SoundEffect: CaseIterable, Sendable {
    case lock, unlock, headphonesConnected, lowBattery

    /// Where to look, best match first.
    var paths: [String] {
        switch self {
        case .lock: ["/System/Library/Frameworks/SecurityInterface.framework/Versions/A/Resources/lock.aif"]
        case .unlock: ["/System/Library/Frameworks/SecurityInterface.framework/Versions/A/Resources/unlock.aif"]
        case .headphonesConnected: ["/System/Library/PrivateFrameworks/HomeKitDaemon.framework/Versions/A/Resources/pairing_complete.caf"]
        case .lowBattery: ["/System/Library/Sounds/Glass.aiff"]
        }
    }
}

@MainActor
final class SoundPlayer {
    private let settings: AppSettings
    private var loaded: [SoundEffect: NSSound] = [:]

    init(settings: AppSettings) {
        self.settings = settings
    }

    /// Plays from the start; a looping sound plays until `stop`.
    func play(_ effect: SoundEffect, loops: Bool = false) {
        guard settings.playsSounds, let sound = sound(for: effect) else { return }
        sound.stop()
        sound.loops = loops
        sound.play()
    }

    func stop(_ effect: SoundEffect) {
        loaded[effect]?.stop()
    }

    private func sound(for effect: SoundEffect) -> NSSound? {
        if let sound = loaded[effect] { return sound }
        let sound = effect.paths.lazy.compactMap { NSSound(contentsOfFile: $0, byReference: true) }.first
        loaded[effect] = sound
        return sound
    }
}

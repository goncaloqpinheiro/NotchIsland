import AppKit
import SwiftUI

/// Volume and brightness in the notch, replacing the system indicator: handles
/// the keys (via MediaKeyTap), applies the change, shows the level, and hides it
/// shortly after the last press.
@MainActor
final class HUDController {
    private let model: NotchViewModel
    private let settings: AppSettings
    private let keys = MediaKeyTap()
    private var hideTask: Task<Void, Never>?
    private var trustObserver: NSObjectProtocol?

    init(model: NotchViewModel, settings: AppSettings) {
        self.model = model
        self.settings = settings
    }

    func start() {
        keys.onPress = { [weak self] key, fineStep in self?.handle(key, fineStep: fineStep) ?? false }
        trustObserver = DistributedNotificationCenter.default().addObserver(
            forName: AccessibilityPermission.changedNotification, object: nil, queue: .main
        ) { [weak self] _ in
            // The new state can take a moment to become readable.
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(0.5))
                self?.refresh()
            }
        }
        if settings.showsSystemHUD, !AccessibilityPermission.isGranted, !settings.didPromptForAccessibility {
            settings.didPromptForAccessibility = true
            AccessibilityPermission.request()
        }
        refresh()
        observeSetting()
    }

    /// Starts or stops intercepting keys to match the setting and the permission.
    func refresh() {
        let granted = AccessibilityPermission.isGranted
        if model.isAccessibilityGranted != granted {
            model.isAccessibilityGranted = granted
        }
        if settings.showsSystemHUD && granted {
            if !keys.isRunning, keys.start() {
                Log.app.info("Volume and brightness keys: handled in the notch")
            }
        } else if keys.isRunning {
            keys.stop()
        }
    }

    private func observeSetting() {
        withObservationTracking {
            _ = settings.showsSystemHUD
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.refresh()
                self?.observeSetting()
            }
        }
    }

    // MARK: - Keys

    private func handle(_ key: MediaKey, fineStep: Bool) -> Bool {
        let step: Float = fineStep ? 1.0 / 64 : 1.0 / 16
        let hud: NotchViewModel.HUD?
        switch key {
        case .volumeUp, .volumeDown, .mute:
            hud = changeVolume(key, step: step)
        case .brightnessUp, .brightnessDown:
            hud = changeBrightness(up: key == .brightnessUp, step: step)
        }
        guard let hud else { return false }
        show(hud)
        return true
    }

    private func changeVolume(_ key: MediaKey, step: Float) -> NotchViewModel.HUD? {
        guard var level = SystemVolume.level() else { return nil }
        var muted = SystemVolume.isMuted()
        switch key {
        case .mute:
            muted.toggle()
            guard SystemVolume.setMuted(muted) else { return nil }
        default:
            level = LevelStep.next(from: level, step: step, up: key == .volumeUp)
            guard SystemVolume.setLevel(level) else { return nil }
            if muted {
                // Changing the volume unmutes, as it does in macOS.
                muted = false
                SystemVolume.setMuted(false)
            }
        }
        return NotchViewModel.HUD(kind: .volume, level: level, isMuted: muted)
    }

    private func changeBrightness(up: Bool, step: Float) -> NotchViewModel.HUD? {
        guard let display = NotchGeometry.current()?.displayID,
              let current = DisplayBrightness.level(of: display) else { return nil }
        let level = LevelStep.next(from: current, step: step, up: up)
        guard DisplayBrightness.setLevel(level, of: display) else { return nil }
        return NotchViewModel.HUD(kind: .brightness, level: level)
    }

    private func show(_ hud: NotchViewModel.HUD) {
        if model.hud == nil {
            withAnimation(NotchStyle.expand) { model.hud = hud }
        } else {
            model.hud = hud
        }
        hideTask?.cancel()
        hideTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(NotchStyle.hudDuration))
            guard !Task.isCancelled, let self else { return }
            withAnimation(NotchStyle.collapse) { self.model.hud = nil }
        }
    }
}

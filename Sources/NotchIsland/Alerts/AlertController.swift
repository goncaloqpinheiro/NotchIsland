import SwiftUI

/// Short notifications in the notch: AirPods connecting, the charger being
/// plugged in or out, low battery, and (from FocusController) Focus changes.
@MainActor
final class AlertController {
    private let model: NotchViewModel
    private let settings: AppSettings
    private let sounds: SoundPlayer
    private let power = PowerSourceMonitor()
    private let headphones = HeadphonesMonitor()
    private var hideTask: Task<Void, Never>?
    /// When each pair last showed the in-ear pill, so a flapping output doesn't repeat it.
    private var lastInEar: [String: Date] = [:]

    init(model: NotchViewModel, settings: AppSettings, sounds: SoundPlayer) {
        self.model = model
        self.settings = settings
        self.sounds = sounds
    }

    func start() {
        power.onChange = { [weak self] old, new in
            guard let self, self.settings.showsDeviceAlerts, let alert = PowerAlert.alert(from: old, to: new) else { return }
            self.present(.power(alert), for: NotchStyle.powerAlertDuration)
            // macOS already plays the charging chime; only low battery gets a sound here.
            if case .low = alert {
                self.sounds.play(.lowBattery)
            }
        }
        headphones.onConnect = { [weak self] info in
            guard let self, self.settings.showsDeviceAlerts else { return }
            self.presentHeadphones(info)
            self.sounds.play(.headphonesConnected)
        }
        headphones.onInEar = { [weak self] info in
            guard let self, self.settings.showsDeviceAlerts else { return }
            self.presentHeadphonesInEar(info)
        }
        headphones.onUpdate = { [weak self] info in
            guard let self, case .headphones(let shown, let isCompact)? = self.model.alert, shown.name == info.name else { return }
            self.model.alert = .headphones(info, isCompact: isCompact)
        }
        power.start()
        observeSetting()
    }

    /// Shows an alert for a while, replacing any other.
    func present(_ alert: NotchViewModel.Alert, for duration: TimeInterval) {
        withAnimation(NotchStyle.expand) {
            model.alert = alert
        }
        hide(after: duration)
    }

    /// Connected (usually as they leave the case): the card, until they go in an
    /// ear, then the compact pill. If they never do, it shrinks after a while anyway.
    func presentHeadphones(_ info: HeadphonesInfo) {
        // Already in an ear: the output can switch before the connection is reported.
        if case .headphones(let shown, true)? = model.alert, shown.name == info.name {
            model.alert = .headphones(info.hasBatteryLevels ? info : shown, isCompact: true)
            return
        }
        withAnimation(NotchStyle.expand) {
            model.alert = .headphones(info, isCompact: false)
        }
        hideTask?.cancel()
        hideTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(NotchStyle.headphonesCardDuration))
            // Read the alert again: battery levels may have arrived meanwhile.
            guard !Task.isCancelled, let self, case .headphones(let current, false)? = self.model.alert else { return }
            self.shrinkHeadphones(current)
        }
    }

    /// In an ear: the compact pill right away, shrinking from the card if it's up.
    func presentHeadphonesInEar(_ info: HeadphonesInfo) {
        defer { lastInEar[info.name] = .now }
        if case .headphones(let shown, _)? = model.alert, shown.name == info.name {
            shrinkHeadphones(info.hasBatteryLevels ? info : shown)
            return
        }
        guard Date.now.timeIntervalSince(lastInEar[info.name] ?? .distantPast) > NotchStyle.headphonesInEarCooldown else { return }
        withAnimation(NotchStyle.expand) {
            model.alert = .headphones(info, isCompact: true)
        }
        hide(after: NotchStyle.headphonesCompactDuration)
    }

    private func shrinkHeadphones(_ info: HeadphonesInfo) {
        withAnimation(NotchStyle.expand) {
            model.alert = .headphones(info, isCompact: true)
        }
        hide(after: NotchStyle.headphonesCompactDuration)
    }

    private func hide(after duration: TimeInterval) {
        hideTask?.cancel()
        hideTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled, let self else { return }
            withAnimation(NotchStyle.collapse) {
                self.model.alert = nil
            }
        }
    }

    /// Bluetooth (and its permission prompt) only starts once alerts are on.
    private func observeSetting() {
        if settings.showsDeviceAlerts {
            headphones.start()
        }
        withObservationTracking {
            _ = settings.showsDeviceAlerts
        } onChange: { [weak self] in
            Task { @MainActor in self?.observeSetting() }
        }
    }
}

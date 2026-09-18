import AppKit

/// Shows a Focus turning on or off, like the Dynamic Island. Watches the Focus
/// folder with FSEvents and re-reads it only when it changes.
@MainActor
final class FocusController {
    private let model: NotchViewModel
    private let settings: AppSettings
    private let alerts: AlertController
    private let watcher = DirectoryWatcher(url: FocusDatabase.directory, fileNames: FocusDatabase.fileNames)
    private var activeMode: FocusMode?
    /// The first read only records the current Focus; changes after it are shown.
    private var hasRead = false
    private var hasLoggedDenied = false
    private var activationObserver: NSObjectProtocol?

    init(model: NotchViewModel, settings: AppSettings, alerts: AlertController) {
        self.model = model
        self.settings = settings
        self.alerts = alerts
    }

    func start() {
        watcher.onChange = { [weak self] _ in
            let started = ContinuousClock.now
            self?.reload()
            Log.app.debug("Focus: re-read in \(started.duration(to: .now), privacy: .public)")
        }
        // Coming back from System Settings after granting access.
        activationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshAccess() }
        }
        observeSetting()
    }

    /// Checks again whether the files can be read, e.g. when Settings opens.
    func refreshAccess() {
        guard settings.showsFocus else { return }
        let wasGranted = model.isFocusAccessGranted
        reload()
        if model.isFocusAccessGranted && !wasGranted {
            // Changes made while the folder was unreadable may not have been reported.
            watcher.stop()
            watcher.start()
        }
    }

    private func observeSetting() {
        if settings.showsFocus {
            if !watcher.isRunning {
                hasRead = false
                reload()
                watcher.start()
            }
        } else {
            watcher.stop()
        }
        withObservationTracking {
            _ = settings.showsFocus
        } onChange: { [weak self] in
            Task { @MainActor in self?.observeSetting() }
        }
    }

    private func reload() {
        switch FocusDatabase.activeMode() {
        case .failure:
            if !hasLoggedDenied {
                Log.app.info("Focus: can't read the Focus files; needs Full Disk Access")
                hasLoggedDenied = true
            }
            setAccessGranted(false)
            // Once access is granted, the first read again just records the current Focus.
            hasRead = false
        case .success(let mode):
            setAccessGranted(true)
            if !hasRead {
                Log.app.info("Focus: reading the Focus files; now \(mode?.identifier ?? "off", privacy: .public)")
            }
            let previous = activeMode
            let isChange = hasRead && mode?.identifier != previous?.identifier
            activeMode = mode
            hasRead = true
            guard isChange else { return }
            Log.app.info("Focus: \(mode?.identifier ?? "off", privacy: .public)")
            if let mode {
                alerts.present(.focus(FocusAlert(mode: mode, isOn: true)), for: NotchStyle.focusAlertDuration)
            } else if let previous {
                alerts.present(.focus(FocusAlert(mode: previous, isOn: false)), for: NotchStyle.focusAlertDuration)
            }
        }
    }

    private func setAccessGranted(_ granted: Bool) {
        if model.isFocusAccessGranted != granted {
            model.isFocusAccessGranted = granted
        }
    }
}

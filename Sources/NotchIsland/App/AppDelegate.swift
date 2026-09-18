import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = AppSettings()
    private let nowPlaying = NowPlayingModel()
    private let timerModel = TimerModel()
    private let shortcuts = ShortcutsTool()
    private lazy var model = NotchViewModel(settings: settings, nowPlaying: nowPlaying, timer: timerModel)
    private lazy var media = NowPlayingController(model: nowPlaying)
    private lazy var sounds = SoundPlayer(settings: settings)
    private lazy var timers = TimerController(model: model, runner: shortcuts)
    private lazy var stopwatch = StopwatchController(model: model, runner: shortcuts)
    private lazy var alerts = AlertController(model: model, settings: settings, sounds: sounds)
    private lazy var focus = FocusController(model: model, settings: settings, alerts: alerts)
    private lazy var mediaGlass = MediaGlassController(model: model)
    private lazy var settingsWindow = SettingsWindowController(
        settings: settings, model: model,
        onShow: { [weak self] in
            self?.focus.refreshAccess()
            self?.refreshClockControls()
        },
        onCheckClockControls: { [weak self] in self?.refreshClockControls() })
    private var menu: AppMenu?
    private var statusItem: StatusItemController?
    private var notch: NotchWindowController?
    private var lock: LockIndicatorController?
    private var hud: HUDController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        timers.start()
        stopwatch.start()
        let timerMenu = TimerMenu(timer: timerModel, controller: timers,
                                  onSetUp: { [weak self] in self?.settingsWindow.show(tab: .clock) })
        let menu = AppMenu(onOpenSettings: { [weak self] in self?.settingsWindow.show() }, timerMenu: timerMenu,
                           needsFocusAccess: { [weak self] in
                               guard let self else { return false }
                               return self.settings.showsFocus && !self.model.isFocusAccessGranted
                           })
        self.menu = menu
        statusItem = StatusItemController(menu: menu.makeMenu())

        let notch = NotchWindowController(model: model, settings: settings, contextMenu: menu.makeMenu(),
                                          actions: mediaActions(), timerActions: timers.actions,
                                          stopwatchActions: stopwatch.actions)
        // A seek made in the player itself isn't announced; re-read when opening.
        notch.onExpand = { [weak self] in self?.media.refresh() }
        notch.start()
        self.notch = notch

        let lock = LockIndicatorController(model: model, settings: settings, mirror: LockScreenMirror(model: model),
                                           sounds: sounds)
        lock.onLock = { [weak notch] in notch?.collapse() }
        lock.start()
        self.lock = lock

        let hud = HUDController(model: model, settings: settings)
        hud.start()
        self.hud = hud

        alerts.start()
        focus.start()
        mediaGlass.start()
        media.start()
        Log.app.info("Launched")
    }

    private func refreshClockControls() {
        timers.refreshControls()
        stopwatch.refreshControls()
    }

    private func mediaActions() -> NowPlayingActions {
        NowPlayingActions(
            togglePlayPause: { [weak self] in self?.media.togglePlayPause() },
            next: { [weak self] in self?.media.next() },
            previous: { [weak self] in self?.media.previous() },
            seek: { [weak self] seconds in self?.media.seek(to: seconds) },
            openPlayer: { [weak self] in self?.media.openPlayer() },
            openAutomationSettings: {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")!)
            }
        )
    }
}

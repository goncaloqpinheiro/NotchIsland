import SwiftUI

/// Mirrors the Clock app's timers in the island, like the Dynamic Island does on
/// iPhone. Reads them live from Clock's timer daemon (`ClockTimerStore`) and, when
/// the shortcuts exist, starts, pauses, resumes and cancels them through Clock's
/// own Shortcuts actions; otherwise the buttons open Clock. Clock rings itself.
/// Nothing ticks here: one sleeping task waits for the next moment the display
/// changes, and the countdown text is redrawn once a second only while visible.
@MainActor
final class TimerController {
    private let model: NotchViewModel
    private let source: ClockTimerSource
    private let runner: ShortcutRunner
    private let openClock: () -> Void
    private var timer: TimerModel { model.timer }
    /// Finished timers closed in the island while Clock may still show them.
    private var closed: Set<String> = []
    private var ringingID: String?
    /// Commands started but not finished; the stored state lags behind until they are.
    private var pending = 0
    private var lastCommand: Task<Void, Never>?
    private var boundary: Task<Void, Never>?

    init(model: NotchViewModel, runner: ShortcutRunner, source: ClockTimerSource? = nil,
         openClock: (() -> Void)? = nil) {
        self.model = model
        self.runner = runner
        self.source = source ?? ClockTimerStore()
        self.openClock = openClock ?? { ClockApp.openTimers() }
    }

    func start() {
        source.onChange = { [weak self] in self?.refresh(animated: true) }
        source.start()
        refresh(animated: false)
        refreshControls()
    }

    /// Looks for the shortcuts again (they may have been added since).
    func refreshControls() {
        Task { [weak self] in
            guard let self else { return }
            let available = TimerCommand.available(in: await self.runner.shortcutNames())
            if self.timer.controls != available {
                self.timer.controls = available
                Log.app.info("Timer controls: \(available.map(\.rawValue).sorted().joined(separator: ", "), privacy: .public)")
            }
        }
    }

    var actions: TimerActions {
        TimerActions(
            start: { [weak self] seconds in self?.start(seconds) },
            pause: { [weak self] in self?.pause() },
            resume: { [weak self] in self?.resume() },
            cancel: { [weak self] in self?.cancel() },
            stop: { [weak self] in self?.stop() },
            repeatLast: { [weak self] in self?.repeatLast() },
            openClock: { [weak self] in self?.openClock() }
        )
    }

    // MARK: - Actions

    /// Starts a Clock timer.
    func start(_ seconds: TimeInterval) {
        guard timer.canStart else { return openClock() }
        let length = max(1, Int(seconds.rounded()))
        // Show it right away; Clock's own record replaces this a moment later.
        withAnimation(NotchStyle.expand) {
            timer.show(.running(endDate: .now.addingTimeInterval(TimeInterval(length))), duration: TimeInterval(length))
        }
        perform(.start, seconds: length)
    }

    func pause() {
        guard timer.controls.contains(.pause) else { return openClock() }
        withAnimation(NotchStyle.expand) {
            timer.show(.paused(remaining: timer.remaining()), duration: timer.duration, title: timer.title)
        }
        perform(.pause)
    }

    func resume() {
        guard timer.controls.contains(.resume) else { return openClock() }
        withAnimation(NotchStyle.expand) {
            timer.show(.running(endDate: .now.addingTimeInterval(timer.remaining())), duration: timer.duration, title: timer.title)
        }
        perform(.resume)
    }

    func cancel() {
        guard timer.canCancel else { return openClock() }
        withAnimation(NotchStyle.collapse) {
            timer.show(.idle, duration: 0)
        }
        perform(.cancel)
    }

    /// Closes a finished timer in the island, and stops it in Clock when possible.
    func stop() {
        if let ringingID {
            closed.insert(ringingID)
        }
        if timer.canCancel {
            perform(.cancel)
        }
        refresh(animated: true, force: true)
    }

    func repeatLast() {
        let length = timer.duration
        stop()
        guard length > 0 else { return }
        start(length)
    }

    /// Runs commands one after another, then re-reads Clock's state.
    private func perform(_ command: TimerCommand, seconds: Int? = nil) {
        pending += 1
        let previous = lastCommand
        lastCommand = Task { [weak self] in
            await previous?.value
            guard let self else { return }
            let succeeded = await self.runner.run(command.shortcutName, input: seconds.map(String.init))
            if !succeeded {
                self.refreshControls()
            }
            self.pending -= 1
            guard self.pending == 0 else { return }
            // The daemon records the change just after the shortcut returns.
            if succeeded {
                try? await Task.sleep(for: .seconds(0.6))
            }
            self.refresh(animated: true)
        }
    }

    // MARK: - Reading Clock's timers

    private func refresh(animated: Bool, force: Bool = false) {
        guard pending == 0 || force else { return }
        let now = Date.now
        let timers = source.timers()
        let limit = NotchStyle.timerDoneTimeout
        closed = closed.filter { id in timers.contains { $0.id == id && $0.isRinging(at: now, limit: limit) } }
        let display = TimerDisplay.pick(from: timers, at: now, ringingLimit: limit, ignoring: closed)
        ringingID = display.phase == .done ? display.timer?.id : nil
        let duration = display.timer?.duration ?? 0
        let title = display.timer?.title
        if display.phase != timer.phase || duration != timer.duration || title != timer.title {
            Log.app.info("Timer: \(Self.describe(display, at: now), privacy: .public)")
            withAnimation(animated ? NotchStyle.expand : nil) {
                timer.show(display.phase, duration: duration, title: title)
            }
        }
        scheduleBoundary(for: display, at: now)
    }

    /// Wakes once when the display next changes on its own: a running timer
    /// reaching zero, or a finished one timing out.
    private func scheduleBoundary(for display: TimerDisplay, at now: Date) {
        boundary?.cancel()
        let next: Date? = switch display.phase {
        case .running(let endDate): endDate
        case .done: display.timer?.wentOff(at: now)?.addingTimeInterval(NotchStyle.timerDoneTimeout)
        case .idle, .paused: nil
        }
        guard let next else { return }
        boundary = Task { [weak self] in
            try? await Task.sleep(for: .seconds(max(0, next.timeIntervalSinceNow) + 0.05))
            guard !Task.isCancelled else { return }
            self?.refresh(animated: true)
        }
    }

    /// For the log: the phase and the stored record behind it (no labels).
    private static func describe(_ display: TimerDisplay, at now: Date) -> String {
        guard let timer = display.timer else { return "none" }
        func time(_ date: Date?) -> String { date.map { $0.formatted(.dateTime.hour().minute().second()) } ?? "-" }
        return "\(display.phase), stored \(timer.state), length \(Int(timer.duration)) s, fired \(time(timer.firedDate)), dismissed \(time(timer.dismissedDate))"
    }
}

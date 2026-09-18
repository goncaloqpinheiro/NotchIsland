import AppKit
import SwiftUI

/// Owns the notch panel: pins it over the physical notch, follows display
/// changes, peeks on hover, opens on click, and lets clicks through everywhere
/// except the island itself.
@MainActor
final class NotchWindowController {
    /// Fixed transparent canvas with room for the open island, spring overshoot
    /// and shadow, so the window never has to resize mid-animation.
    static let canvasSize = CGSize(width: 640, height: 300)

    private let model: NotchViewModel
    private let settings: AppSettings
    private let contextMenu: NSMenu
    private let actions: NowPlayingActions
    private let timerActions: TimerActions
    private let stopwatchActions: StopwatchActions
    private let mouse = MouseTracker()
    private let hover = HoverController()
    private var panel: NotchPanel?
    private var geometry: NotchGeometry?
    private var screenObserver: NSObjectProtocol?
    private lazy var fullScreen = FullScreenMonitor { [weak self] in self?.geometry?.displayID }

    /// Called when a click opens the island.
    var onExpand: (() -> Void)?

    init(model: NotchViewModel, settings: AppSettings, contextMenu: NSMenu, actions: NowPlayingActions,
         timerActions: TimerActions, stopwatchActions: StopwatchActions) {
        self.model = model
        self.settings = settings
        self.contextMenu = contextMenu
        self.actions = actions
        self.timerActions = timerActions
        self.stopwatchActions = stopwatchActions
    }

    func start() {
        mouse.onMove = { [weak self] point in self?.handleMouse(at: point) }
        hover.enterDelay = { [weak self] in self?.settings.hoverDelay ?? 0 }
        hover.exitDelay = NotchStyle.exitDelay
        hover.onChange = { [weak self] isHovering in self?.hoverChanged(isHovering) }
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.updateScreen() }
        }
        fullScreen.onChange = { [weak self] isFullScreen in self?.model.isFullScreen = isFullScreen }
        updateScreen()
        fullScreen.start()
        observeLayout()
    }

    /// Closes the island immediately, e.g. when the screen locks.
    func collapse() {
        hover.reset()
        if model.state != .collapsed {
            setState(.collapsed)
        }
    }

    // MARK: - Mouse

    private func handleMouse(at point: CGPoint) {
        guard let geometry, let panel else { return }
        // Take clicks only over the island itself; everywhere else they fall through.
        let overIsland = geometry.rect(for: model.shapeSize).containsInclusive(point)
        if panel.ignoresMouseEvents == overIsland {
            panel.ignoresMouseEvents = !overIsland
        }
        hover.update(cursorInZone: hoverZone(in: geometry).containsInclusive(point))
    }

    /// Where the cursor has to be to hover the island, or to keep it open.
    private func hoverZone(in geometry: NotchGeometry) -> CGRect {
        let shape = model.shapeSize
        if model.isExpanded {
            let slop = NotchStyle.leaveSlop
            return geometry.rect(for: shape).insetBy(dx: -slop, dy: -slop)
        }
        let slop = NotchStyle.hoverSlop
        return geometry.rect(for: CGSize(width: shape.width + 2 * slop.width,
                                         height: shape.height + slop.height))
    }

    private func hoverChanged(_ isHovering: Bool) {
        if isHovering {
            guard model.state == .collapsed else { return }
            setState(.peeking)
            if settings.hapticsEnabled {
                NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
            }
        } else if model.state != .collapsed {
            setState(.collapsed)
        }
    }

    /// A click on the island (it only receives clicks while the cursor is over it).
    private func islandClicked() {
        guard model.state != .expanded else { return }
        // The click may land before the hover delay elapsed; count it as hovering
        // so moving away still closes the island.
        hover.markHovering()
        // A ringing timer has its own Repeat and Stop buttons; clicks go to them.
        guard model.resting != .timerDone else { return }
        setState(.expanded)
        onExpand?()
    }

    private func setState(_ state: NotchViewModel.State) {
        Log.notch.debug("Island \(String(describing: state), privacy: .public)")
        let animation = switch state {
        case .collapsed: NotchStyle.collapse
        case .peeking: NotchStyle.peek
        case .expanded: NotchStyle.expand
        }
        withAnimation(animation) {
            model.state = state
        }
    }

    // MARK: - Screen

    private func updateScreen() {
        hover.reset()
        guard let geometry = NotchGeometry.current() else {
            Log.notch.info("No notched screen; hiding panel")
            self.geometry = nil
            mouse.stop()
            panel?.orderOut(nil)
            return
        }
        if geometry != self.geometry {
            Log.notch.info("Notch \(geometry.notchSize.width, privacy: .public)x\(geometry.notchSize.height, privacy: .public) on screen \(geometry.screenFrame.debugDescription, privacy: .public)")
        }
        self.geometry = geometry
        model.detectedNotchSize = geometry.notchSize

        let panel = self.panel ?? makePanel()
        panel.setFrame(geometry.rect(for: Self.canvasSize), display: true)
        panel.orderFrontRegardless()
        mouse.start()
        fullScreen.refresh()
    }

    private func makePanel() -> NotchPanel {
        let panel = NotchPanel()
        let host = NotchHostingView(rootView: NotchRootView(model: model, actions: actions, timerActions: timerActions,
                                                            stopwatchActions: stopwatchActions))
        host.sizingOptions = []  // the canvas size is fixed; don't let SwiftUI resize the window
        host.contextMenu = contextMenu
        host.onMouseDown = { [weak self] in self?.islandClicked() }
        panel.contentView = host
        self.panel = panel
        return panel
    }

    /// Re-hit-tests whenever the island changes size under a still cursor
    /// (opening, closing, or a size change from Settings).
    private func observeLayout() {
        withObservationTracking {
            _ = model.shapeSize
        } onChange: { [weak self] in
            // onChange fires before the new value is stored; read it on the next turn.
            Task { @MainActor in
                self?.mouse.refresh()
                self?.observeLayout()
            }
        }
    }
}

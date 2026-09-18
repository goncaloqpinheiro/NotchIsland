import Foundation

/// Debounces "the cursor is in the hover zone": entering counts only after the
/// cursor stays for `enterDelay`, leaving only after `exitDelay`. So brushing
/// past the notch does nothing, and a brief slip outside doesn't close it.
@MainActor
final class HoverController {
    var enterDelay: () -> TimeInterval = { 0 }
    var exitDelay: TimeInterval = 0
    var onChange: ((_ isHovering: Bool) -> Void)?
    private(set) var isHovering = false
    private var pending: Task<Void, Never>?
    private var pendingTarget: Bool?

    func update(cursorInZone inZone: Bool) {
        guard inZone != isHovering else {
            cancelPending()
            return
        }
        guard pendingTarget != inZone else { return }  // already on its way
        cancelPending()

        let delay = inZone ? enterDelay() : exitDelay
        guard delay > 0 else { return commit(inZone) }
        pendingTarget = inZone
        pending = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            self?.commit(inZone)
        }
    }

    /// Records that the cursor is on the island without notifying, e.g. after a
    /// click opened it before the enter delay elapsed. Leaving then closes it.
    func markHovering() {
        cancelPending()
        isHovering = true
    }

    /// Stops hovering immediately, e.g. when the display changes.
    func reset() {
        cancelPending()
        if isHovering { commit(false) }
    }

    private func commit(_ hovering: Bool) {
        cancelPending()
        isHovering = hovering
        onChange?(hovering)
    }

    private func cancelPending() {
        pending?.cancel()
        pending = nil
        pendingTarget = nil
    }
}

import Foundation

/// The system announces screen lock and unlock with distributed notifications;
/// observing them needs no permission.
@MainActor
final class ScreenLockMonitor {
    var onLock: (() -> Void)?
    var onUnlock: (() -> Void)?
    private var observers: [NSObjectProtocol] = []

    func start() {
        let center = DistributedNotificationCenter.default()
        observers = [
            center.addObserver(forName: Notification.Name("com.apple.screenIsLocked"), object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.onLock?() }
            },
            center.addObserver(forName: Notification.Name("com.apple.screenIsUnlocked"), object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.onUnlock?() }
            },
        ]
    }
}

import Foundation
import IOKit.ps

/// Reports battery and power adapter changes through IOKit's power source
/// notification, which fires when either changes (no polling).
@MainActor
final class PowerSourceMonitor {
    var onChange: ((_ old: PowerStatus, _ new: PowerStatus) -> Void)?
    private var status: PowerStatus?
    private var source: CFRunLoopSource?

    func start() {
        guard source == nil else { return }
        status = PowerStatus.current()
        let context = Unmanaged.passUnretained(self).toOpaque()
        guard let source = IOPSNotificationCreateRunLoopSource({ context in
            guard let context else { return }
            let monitor = Unmanaged<PowerSourceMonitor>.fromOpaque(context).takeUnretainedValue()
            MainActor.assumeIsolated { monitor.update() }  // delivered on the main run loop
        }, context)?.takeRetainedValue() else { return }
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
        self.source = source
    }

    private func update() {
        guard let new = PowerStatus.current() else { return }
        let old = status
        status = new
        if let old, old != new {
            onChange?(old, new)
        }
    }
}

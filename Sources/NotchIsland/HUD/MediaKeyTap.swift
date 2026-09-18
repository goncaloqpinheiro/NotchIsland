import AppKit

/// Intercepts the volume and brightness keys before macOS handles them, so the
/// notch can show the level instead of the system indicator. Needs the
/// Accessibility permission. Only those keys are listened to; if a press isn't
/// handled (e.g. the output device has no volume control) it goes on to macOS.
@MainActor
final class MediaKeyTap {
    /// Return true when the press was handled and macOS shouldn't see it.
    var onPress: ((_ key: MediaKey, _ fineStep: Bool) -> Bool)?
    var isRunning: Bool { tap != nil }

    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    /// Keys whose key-down was swallowed, so their key-up is swallowed too.
    private var swallowed: [MediaKey] = []

    /// Returns false when macOS refuses (no Accessibility permission).
    @discardableResult
    func start() -> Bool {
        guard tap == nil else { return true }
        let systemDefined = CGEventMask(1 << 14)  // NX_SYSDEFINED
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap,
                                          place: .headInsertEventTap,
                                          options: .defaultTap,
                                          eventsOfInterest: systemDefined,
                                          callback: mediaKeyTapCallback,
                                          userInfo: Unmanaged.passUnretained(self).toOpaque()) else { return false }
        let source = CFMachPortCreateRunLoopSource(nil, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.tap = tap
        self.source = source
        return true
    }

    func stop() {
        guard let tap else { return }
        CGEvent.tapEnable(tap: tap, enable: false)
        if let source {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        CFMachPortInvalidate(tap)
        self.tap = nil
        source = nil
        swallowed.removeAll()
    }

    fileprivate func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        let passThrough = Unmanaged.passUnretained(event)
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return passThrough
        }
        guard let nsEvent = NSEvent(cgEvent: event), nsEvent.type == .systemDefined,
              let press = MediaKey.decode(subtype: nsEvent.subtype.rawValue, data1: nsEvent.data1) else { return passThrough }

        guard press.isDown else {
            guard let index = swallowed.firstIndex(of: press.key) else { return passThrough }
            swallowed.remove(at: index)
            return nil
        }
        let modifiers = nsEvent.modifierFlags.intersection(.deviceIndependentFlagsMask)
        // Option alone opens Sound or Displays settings: leave that to macOS.
        if modifiers == .option { return passThrough }
        guard onPress?(press.key, modifiers.isSuperset(of: [.option, .shift])) == true else { return passThrough }
        if !swallowed.contains(press.key) {
            swallowed.append(press.key)
        }
        return nil
    }
}

private func mediaKeyTapCallback(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent,
                                 userInfo: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    guard let userInfo else { return Unmanaged.passUnretained(event) }
    let tap = Unmanaged<MediaKeyTap>.fromOpaque(userInfo).takeUnretainedValue()
    // The tap's run loop source is on the main run loop.
    return MainActor.assumeIsolated { tap.handle(type: type, event: event) }
}

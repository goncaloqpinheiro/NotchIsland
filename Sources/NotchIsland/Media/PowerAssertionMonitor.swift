import AppKit
import IOKit.pwr_mgt
import notify

/// Which apps hold media power assertions ("Playing audio", "Video Wake Lock").
/// Browsers take these while a page plays and let go about 2 s after it goes
/// quiet, well before their audio output stops (about 10 s in Chrome).
///
/// The system only posts assertion-change notifications to apps that ask, and
/// then posts one for every change anywhere, including those caused by typing
/// and mouse movement. So this runs only while a browser is making sound, and
/// re-reads assertions at most once a second.
@MainActor
final class PowerAssertionMonitor {
    /// Bundle IDs of the apps currently holding a media assertion.
    var onChange: ((Set<String>) -> Void)?
    private(set) var holders: Set<String> = []
    private(set) var isActive = false

    private static let anyChange = "com.apple.system.powermanagement.assertions.anychange"
    private var token: Int32 = 0
    private var lastCheck = Date.distantPast
    private var pendingCheck: Task<Void, Never>?

    func setActive(_ active: Bool) {
        guard active != isActive else { return }
        isActive = active
        if active {
            Self.requestNotifications(true)
            notify_register_dispatch(Self.anyChange, &token, .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.scheduleCheck() }
            }
            check()
        } else {
            notify_cancel(token)
            Self.requestNotifications(false)
            pendingCheck?.cancel()
            pendingCheck = nil
            if !holders.isEmpty {
                holders = []
                onChange?([])
            }
        }
    }

    private func scheduleCheck() {
        guard pendingCheck == nil else { return }
        let wait = max(0.2, 1 - Date.now.timeIntervalSince(lastCheck))
        pendingCheck = Task { [weak self] in
            try? await Task.sleep(for: .seconds(wait))
            guard !Task.isCancelled, let self else { return }
            self.pendingCheck = nil
            self.check()
        }
    }

    private func check() {
        lastCheck = .now
        let current = Self.mediaAssertionHolders()
        guard current != holders else { return }
        holders = current
        onChange?(current)
    }

    // MARK: - System

    /// Private IOKit call asking powerd to post `anyChange` (1 registers, 2 unregisters).
    private static let assertionNotify: (@convention(c) (UnsafePointer<CChar>, Int32) -> Int32)? = {
        guard let iokit = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_LAZY),
              let function = dlsym(iokit, "IOPMAssertionNotify") else { return nil }
        return unsafeBitCast(function, to: (@convention(c) (UnsafePointer<CChar>, Int32) -> Int32).self)
    }()

    private static func requestNotifications(_ enabled: Bool) {
        _ = anyChange.withCString { assertionNotify?($0, enabled ? 1 : 2) }
    }

    private static func mediaAssertionHolders() -> Set<String> {
        var result: Unmanaged<CFDictionary>?
        guard IOPMCopyAssertionsByProcess(&result) == kIOReturnSuccess,
              let byProcess = result?.takeRetainedValue() as? [NSNumber: [[String: Any]]] else { return [] }
        var holders: Set<String> = []
        for (pid, assertions) in byProcess {
            let holdsMedia = assertions.contains { assertion in
                let name = (assertion[kIOPMAssertionNameKey] as? String)?.lowercased() ?? ""
                return name.contains("audio") || name.contains("video") || name.contains("media")
            }
            if holdsMedia, let bundleID = bundleID(ofProcess: pid.int32Value) {
                holders.insert(bundleID)
            }
        }
        return holders
    }

    /// Apps via LaunchServices; helper and XPC processes via their bundle on disk.
    private static func bundleID(ofProcess pid: pid_t) -> String? {
        if let bundleID = NSRunningApplication(processIdentifier: pid)?.bundleIdentifier {
            return bundleID
        }
        var path = [CChar](repeating: 0, count: 4096)
        guard proc_pidpath(pid, &path, UInt32(path.count)) > 0 else { return nil }
        var url = URL(fileURLWithPath: String(cString: path))
        while url.pathComponents.count > 1 {
            url.deleteLastPathComponent()
            if ["app", "xpc", "appex"].contains(url.pathExtension) {
                return Bundle(url: url)?.bundleIdentifier
            }
        }
        return nil
    }
}

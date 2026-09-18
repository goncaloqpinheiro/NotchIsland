import CoreAudio
import Foundation

/// Tracks which apps are producing sound, from Core Audio's per-process state
/// (macOS 14.2+). Listeners fire only on changes, and reading this state needs
/// no permission (it isn't audio capture).
///
/// Core Audio announces changes to a process's overall running state, not to
/// its output flag, so both are observed and the output flag is re-read on either.
@MainActor
final class AudioActivityMonitor {
    /// Which processes to watch, by bundle ID.
    var isRelevant: (String) -> Bool = { _ in true }
    /// Bundle IDs of the watched processes currently producing sound.
    var onChange: ((Set<String>) -> Void)?
    private(set) var playing: Set<String> = []

    private var watched: [AudioObjectID: (bundleID: String, listener: AudioObjectPropertyListenerBlock)] = [:]
    private var listListener: AudioObjectPropertyListenerBlock?

    func start() {
        guard listListener == nil else { return }
        let listener: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            MainActor.assumeIsolated { self?.reloadProcesses() }
        }
        var address = Self.propertyAddress(kAudioHardwarePropertyProcessObjectList)
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &address, .main, listener)
        listListener = listener
        reloadProcesses()
    }

    /// Apps open and close audio clients all the time; follow the relevant ones.
    private func reloadProcesses() {
        let current = Set(Self.processObjects())
        for (process, entry) in watched where !current.contains(process) {
            for selector in Self.runningSelectors {
                var address = Self.propertyAddress(selector)
                AudioObjectRemovePropertyListenerBlock(process, &address, .main, entry.listener)
            }
            watched[process] = nil
        }
        for process in current where watched[process] == nil {
            guard let bundleID = Self.bundleID(of: process), isRelevant(bundleID) else { continue }
            let listener: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
                MainActor.assumeIsolated { self?.recompute() }
            }
            for selector in Self.runningSelectors {
                var address = Self.propertyAddress(selector)
                AudioObjectAddPropertyListenerBlock(process, &address, .main, listener)
            }
            watched[process] = (bundleID, listener)
        }
        recompute()
    }

    private func recompute() {
        let now = Set(watched.filter { Self.isRunningOutput($0.key) }.map(\.value.bundleID))
        guard now != playing else { return }
        playing = now
        onChange?(now)
    }

    // MARK: - Core Audio

    private static let runningSelectors = [kAudioProcessPropertyIsRunning, kAudioProcessPropertyIsRunningOutput]

    private static func propertyAddress(_ selector: AudioObjectPropertySelector) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector,
                                   mScope: kAudioObjectPropertyScopeGlobal,
                                   mElement: kAudioObjectPropertyElementMain)
    }

    private static func processObjects() -> [AudioObjectID] {
        let system = AudioObjectID(kAudioObjectSystemObject)
        var address = propertyAddress(kAudioHardwarePropertyProcessObjectList)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(system, &address, 0, nil, &size) == noErr, size > 0 else { return [] }
        var processes = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(system, &address, 0, nil, &size, &processes) == noErr else { return [] }
        return processes
    }

    private static func bundleID(of process: AudioObjectID) -> String? {
        var address = propertyAddress(kAudioProcessPropertyBundleID)
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        var value: Unmanaged<CFString>?
        let status = withUnsafeMutablePointer(to: &value) {
            AudioObjectGetPropertyData(process, &address, 0, nil, &size, $0)
        }
        guard status == noErr, let bundleID = value?.takeRetainedValue() as String?, !bundleID.isEmpty else { return nil }
        return bundleID
    }

    private static func isRunningOutput(_ process: AudioObjectID) -> Bool {
        var address = propertyAddress(kAudioProcessPropertyIsRunningOutput)
        var size = UInt32(MemoryLayout<UInt32>.size)
        var running: UInt32 = 0
        return AudioObjectGetPropertyData(process, &address, 0, nil, &size, &running) == noErr && running != 0
    }
}

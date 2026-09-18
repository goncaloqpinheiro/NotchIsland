import CoreAudio
import Foundation

/// The default audio output switching to a Bluetooth device. macOS switches to
/// AirPods when ear detection sees them go in, so for AirPods this is the
/// moment they're in your ears. Core Audio announces the switch; nothing polls.
@MainActor
final class AudioOutputMonitor {
    /// The new output's name, and its Bluetooth address when its Core Audio UID carries one.
    var onBluetoothOutput: ((_ name: String, _ address: String?) -> Void)?

    private var listener: AudioObjectPropertyListenerBlock?
    private var current = AudioObjectID(kAudioObjectUnknown)

    func start() {
        guard listener == nil else { return }
        current = Self.defaultOutput() ?? AudioObjectID(kAudioObjectUnknown)
        let listener: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            MainActor.assumeIsolated { self?.outputChanged() }
        }
        var address = Self.defaultOutputAddress
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &address, .main, listener)
        self.listener = listener
    }

    private func outputChanged() {
        guard let device = Self.defaultOutput(), device != current else { return }
        current = device
        let transport = Self.uint32(kAudioDevicePropertyTransportType, of: device)
        guard transport == kAudioDeviceTransportTypeBluetooth || transport == kAudioDeviceTransportTypeBluetoothLE,
              let name = Self.string(kAudioObjectPropertyName, of: device) else { return }
        let address = Self.string(kAudioDevicePropertyDeviceUID, of: device).flatMap(Self.bluetoothAddress(fromUID:))
        onBluetoothOutput?(name, address)
    }

    /// Bluetooth audio devices' UIDs start with the device address, e.g. "AC-90-85-12-34-56:output".
    nonisolated static func bluetoothAddress(fromUID uid: String) -> String? {
        let parts = uid.prefix { $0 != ":" }.split(separator: "-")
        guard parts.count == 6, parts.allSatisfy({ $0.count == 2 && $0.allSatisfy(\.isHexDigit) }) else { return nil }
        return parts.joined(separator: "-").lowercased()
    }

    // MARK: - Core Audio

    private static let defaultOutputAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultOutputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain)

    private static func defaultOutput() -> AudioObjectID? {
        var address = defaultOutputAddress
        var device = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &device) == noErr,
              device != kAudioObjectUnknown else { return nil }
        return device
    }

    private static func uint32(_ selector: AudioObjectPropertySelector, of device: AudioObjectID) -> UInt32? {
        var address = AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal,
                                                 mElement: kAudioObjectPropertyElementMain)
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        return AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value) == noErr ? value : nil
    }

    private static func string(_ selector: AudioObjectPropertySelector, of device: AudioObjectID) -> String? {
        var address = AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal,
                                                 mElement: kAudioObjectPropertyElementMain)
        var value: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value) == noErr, let value else { return nil }
        return value.takeRetainedValue() as String
    }
}

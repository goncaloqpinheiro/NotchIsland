import IOBluetooth

/// Headphones connecting over Bluetooth, and becoming the audio output (for
/// AirPods, going in your ears). macOS asks for Bluetooth permission the first
/// time this starts. Battery levels come from private IOBluetooth properties
/// that fill in a few seconds after the connection.
@MainActor
final class HeadphonesMonitor: NSObject {
    var onConnect: ((HeadphonesInfo) -> Void)?
    /// The same headphones again, once battery levels are known.
    var onUpdate: ((HeadphonesInfo) -> Void)?
    /// Headphones became the audio output: AirPods went in an ear.
    var onInEar: ((HeadphonesInfo) -> Void)?

    private let output = AudioOutputMonitor()
    private var registration: IOBluetoothUserNotification?
    private var startedAt = Date.distantPast
    private var isStarted: Bool { registration != nil }

    func start() {
        guard !isStarted else { return }
        startedAt = .now
        registration = IOBluetoothDevice.register(forConnectNotifications: self,
                                                  selector: #selector(deviceConnected(_:device:)))
        output.onBluetoothOutput = { [weak self] name, address in self?.outputSwitched(name: name, address: address) }
        output.start()
    }

    private func outputSwitched(name: String, address: String?) {
        let paired = IOBluetoothDevice.pairedDevices()?.compactMap { $0 as? IOBluetoothDevice } ?? []
        guard let device = address.flatMap(IOBluetoothDevice.init(addressString:)) ?? paired.first(where: { $0.name == name }),
              device.deviceClassMajor == kBluetoothDeviceClassMajorAudio else { return }
        onInEar?(info(for: device))
    }

    @objc private func deviceConnected(_ notification: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        // Devices already connected when the app starts are reported right away; skip those.
        guard Date.now.timeIntervalSince(startedAt) > 2,
              device.deviceClassMajor == kBluetoothDeviceClassMajorAudio else { return }
        onConnect?(info(for: device))
        Task { [weak self] in
            for delay in [1.5, 3.0] {
                try? await Task.sleep(for: .seconds(delay))
                guard let self else { return }
                let info = self.info(for: device)
                if info.hasBatteryLevels {
                    self.onUpdate?(info)
                    return
                }
            }
        }
    }

    private func info(for device: IOBluetoothDevice) -> HeadphonesInfo {
        let name = device.name ?? "Headphones"
        return HeadphonesInfo(
            name: name,
            productID: integer("productID", of: device) ?? 0,
            left: HeadphonesInfo.batteryLevel(integer("batteryPercentLeft", of: device)),
            right: HeadphonesInfo.batteryLevel(integer("batteryPercentRight", of: device)),
            chargingCase: HeadphonesInfo.batteryLevel(integer("batteryPercentCase", of: device)),
            single: HeadphonesInfo.batteryLevel(integer("batteryPercentSingle", of: device)))
    }

    /// Reads a private property only if this macOS version has it (KVC on a
    /// missing key would throw).
    private func integer(_ key: String, of device: IOBluetoothDevice) -> Int? {
        guard device.responds(to: NSSelectorFromString(key)) else { return nil }
        return (device.value(forKey: key) as? NSNumber)?.intValue
    }
}

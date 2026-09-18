import Foundation

/// Headphones that just connected, with whatever battery levels are known.
struct HeadphonesInfo: Equatable, Sendable {
    var name: String
    /// Bluetooth product ID, e.g. 0x2019 for AirPods 4.
    var productID: Int
    var left: Int?
    var right: Int?
    var chargingCase: Int?
    /// Headphones with one battery, like AirPods Max.
    var single: Int?

    var hasBatteryLevels: Bool {
        left != nil || right != nil || chargingCase != nil || single != nil
    }

    /// One level for the compact pill: the lower earbud, else the headphones, else the case.
    var headlineLevel: Int? {
        [left, right].compactMap { $0 }.min() ?? single ?? chargingCase
    }

    /// Case symbol: AirPods 1 and 2 have the tall case, later models the wide one.
    var caseSymbol: String {
        [0x2002, 0x200F].contains(productID) ? "airpods.chargingcase.fill" : "airpods.gen3.chargingcase.wireless"
    }

    /// Shown when macOS has no animation for this product.
    var fallbackSymbol: String {
        let name = name.lowercased()
        if name.contains("airpods max") { return "airpodsmax" }
        if name.contains("airpods pro") { return "airpodspro" }
        if name.contains("airpods") { return "airpods" }
        return "headphones"
    }

    /// Bluetooth reports 0 (and sometimes >100) for batteries it doesn't know yet.
    static func batteryLevel(_ value: Int?) -> Int? {
        guard let value, (1...100).contains(value) else { return nil }
        return value
    }
}

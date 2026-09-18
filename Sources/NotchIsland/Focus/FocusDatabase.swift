import AppKit

/// Reads which Focus is on from the files macOS keeps it in. There's no public
/// API or broadcast for this, and the folder is protected: reading it needs
/// Full Disk Access. Only these two files are read.
///
/// - `Assertions.json`: the Focuses currently turned on ("assertions"), each
///   naming its mode. Scheduled and shared-across-devices Focuses appear here too.
/// - `ModeConfigurations.json`: every Focus's name, symbol and color.
enum FocusDatabase {
    static let directory = FileManager.default.homeDirectoryForCurrentUser
        .appending(path: "Library/DoNotDisturb/DB", directoryHint: .isDirectory)
    static let fileNames: Set<String> = ["Assertions.json", "ModeConfigurations.json"]

    struct AccessDenied: Error {}

    /// The Focus that's on, or nil when none is.
    static func activeMode() -> Result<FocusMode?, AccessDenied> {
        do {
            let assertions = try readIfPresent("Assertions.json")
            let configurations = try readIfPresent("ModeConfigurations.json")
            return .success(activeMode(assertions: assertions, configurations: configurations))
        } catch {
            return .failure(AccessDenied())
        }
    }

    static func activeMode(assertions: Data?, configurations: Data?) -> FocusMode? {
        guard let identifier = activeModeIdentifier(in: assertions) else { return nil }
        return mode(identifier, in: configurations)
    }

    /// The mode of the most recent assertion.
    static func activeModeIdentifier(in assertions: Data?) -> String? {
        guard let records = store(in: assertions, containing: "storeAssertionRecords")?["storeAssertionRecords"]
                as? [[String: Any]] else { return nil }
        let newest = records.max { startDate(of: $0) < startDate(of: $1) }
        let details = newest?["assertionDetails"] as? [String: Any]
        return details?["assertionDetailsModeIdentifier"] as? String
    }

    static func mode(_ identifier: String, in configurations: Data?) -> FocusMode {
        let builtIn = FocusMode.builtIn(identifier)
        let all = store(in: configurations, containing: "modeConfigurations")?["modeConfigurations"] as? [String: Any]
        let mode = (all?[identifier] as? [String: Any])?["mode"] as? [String: Any]
        // Custom Focuses can use any symbol; fall back if this Mac doesn't know it.
        let symbol = (mode?["symbolImageName"] as? String)
            .flatMap { NSImage(systemSymbolName: $0, accessibilityDescription: nil) == nil ? nil : $0 }
        let name = (mode?["name"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        return FocusMode(identifier: identifier,
                         name: name ?? builtIn.name,
                         symbol: symbol ?? builtIn.symbol,
                         tintName: (mode?["tintColorName"] as? String) ?? builtIn.tintName)
    }

    // MARK: - Files

    /// A missing file is fine (no Focus was ever used); a denied read is not.
    private static func readIfPresent(_ name: String) throws -> Data? {
        do {
            return try Data(contentsOf: directory.appending(path: name))
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            return nil
        }
    }

    /// Both files hold `{"data": [store, …], "header": …}`.
    private static func store(in data: Data?, containing key: String) -> [String: Any]? {
        guard let data,
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let stores = root["data"] as? [[String: Any]] else { return nil }
        return stores.first { $0[key] != nil }
    }

    private static func startDate(of record: [String: Any]) -> Double {
        (record["assertionStartDateTimestamp"] as? NSNumber)?.doubleValue ?? 0
    }
}

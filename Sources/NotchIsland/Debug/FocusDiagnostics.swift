import Foundation

/// Dev tool: `open -n build/NotchIsland.app --args --focus-check` logs the shape
/// of the Focus files (keys, record counts, each Focus's symbol and color, never
/// names) and what NotchIsland reads from them, then exits. It has to be launched
/// with `open` so it runs with NotchIsland's own Full Disk Access.
@MainActor
enum FocusDiagnostics {
    static func runIfRequested() -> Bool {
        guard CommandLine.arguments.contains("--focus-check") else { return false }
        let directory = FocusDatabase.directory
        let files = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        Log.app.info("Focus check: folder has \(files.sorted().joined(separator: ", "), privacy: .public)")
        for name in ["Assertions.json", "ModeConfigurations.json"] {
            guard let data = try? Data(contentsOf: directory.appending(path: name)),
                  let root = try? JSONSerialization.jsonObject(with: data) else {
                Log.app.info("Focus check: \(name, privacy: .public) unreadable or missing")
                continue
            }
            Log.app.info("Focus check: \(name, privacy: .public) \(shape(root, depth: 0), privacy: .public)")
        }
        let configurations = try? Data(contentsOf: directory.appending(path: "ModeConfigurations.json"))
        if let root = configurations.flatMap({ try? JSONSerialization.jsonObject(with: $0) }) as? [String: Any],
           let modes = (root["data"] as? [[String: Any]])?.first(where: { $0["modeConfigurations"] != nil })?["modeConfigurations"] as? [String: Any] {
            for identifier in modes.keys.sorted() {
                let mode = FocusDatabase.mode(identifier, in: configurations)
                let stored = (modes[identifier] as? [String: Any])?["mode"] as? [String: Any]
                Log.app.info("Focus check: mode \(identifier, privacy: .public): stored name \(stored?["name"] != nil, privacy: .public), symbol \(mode.symbol, privacy: .public), color \(mode.tintName, privacy: .public)")
            }
        }
        switch FocusDatabase.activeMode() {
        case .success(let mode): Log.app.info("Focus check: active \(mode?.identifier ?? "none", privacy: .public)")
        case .failure: Log.app.info("Focus check: can't read the files")
        }
        return true
    }

    /// Keys and array sizes, a few levels deep; no values.
    private static func shape(_ value: Any, depth: Int) -> String {
        switch value {
        case let dictionary as [String: Any]:
            guard depth < 4 else { return "{…}" }
            let fields = dictionary.keys.sorted().prefix(12).map { key in
                // Mode identifiers are keys too; their contents are summarized once.
                "\(key): \(shape(dictionary[key]!, depth: depth + 1))"
            }
            return "{" + fields.joined(separator: ", ") + (dictionary.count > 12 ? ", …" : "") + "}"
        case let array as [Any]:
            guard let first = array.first else { return "[]" }
            return "[\(array.count)× \(shape(first, depth: depth + 1))]"
        case is String: return "text"
        case is NSNumber: return "number"
        default: return "?"
        }
    }
}

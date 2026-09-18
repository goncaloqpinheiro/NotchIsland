import AppKit

/// Something NotchIsland can ask the Clock app to do. Only Clock can change its
/// timers and stopwatch (its daemon only talks to Apple's own apps), so each
/// command is a one-action shortcut the user creates once, using Clock's own
/// Shortcuts action.
protocol ClockCommand: CaseIterable, Hashable, Sendable {
    /// The shortcut NotchIsland runs.
    var shortcutName: String { get }
    /// The Clock action that shortcut holds.
    var clockAction: String { get }
}

enum TimerCommand: String, ClockCommand {
    case start, pause, resume, cancel

    var shortcutName: String { "NotchIsland \(rawValue.capitalized) Timer" }
    var clockAction: String { "\(rawValue.capitalized) Timer" }
}

enum StopwatchCommand: String, ClockCommand {
    case start, stop, lap, reset

    var shortcutName: String { "NotchIsland \(rawValue.capitalized) Stopwatch" }
    var clockAction: String { "\(rawValue.capitalized) Stopwatch" }
}

extension ClockCommand {
    /// The commands whose shortcuts exist.
    static func available(in shortcutNames: Set<String>) -> Set<Self> {
        Set(allCases.filter { shortcutNames.contains($0.shortcutName) })
    }
}

@MainActor
protocol ShortcutRunner: AnyObject {
    /// The names of the shortcuts in the user's library.
    func shortcutNames() async -> Set<String>
    /// Runs a shortcut by name, with optional text input. Returns whether it worked.
    func run(_ name: String, input: String?) async -> Bool
}

/// Runs shortcuts with the `shortcuts` command-line tool, off the main thread.
@MainActor
final class ShortcutsTool: ShortcutRunner {
    private let queue = DispatchQueue(label: "NotchIsland.shortcuts", qos: .userInitiated)
    /// Both Clock controllers ask at once (at launch, when Settings opens); list once.
    private var listing: Task<Set<String>, Never>?

    func shortcutNames() async -> Set<String> {
        if let listing {
            return await listing.value
        }
        let queue = queue
        let listing = Task {
            let result = await Self.runTool(["list"], input: nil, on: queue)
            return Set(result.output.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) })
        }
        self.listing = listing
        let names = await listing.value
        self.listing = nil
        return names
    }

    func run(_ name: String, input: String?) async -> Bool {
        var arguments = ["run", name]
        if input != nil {
            arguments += ["--input-path", "-"]  // the input as text on standard input
        }
        let result = await Self.runTool(arguments, input: input, on: queue)
        if result.status != 0 {
            Log.app.error("Shortcut \(name, privacy: .public) failed (\(result.status, privacy: .public)): \(result.error, privacy: .public)")
        }
        return result.status == 0
    }

    private struct ToolResult: Sendable {
        var status: Int32
        var output: String
        var error: String
    }

    private nonisolated static func runTool(_ arguments: [String], input: String?, on queue: DispatchQueue) async -> ToolResult {
        await withCheckedContinuation { continuation in
            queue.async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
                process.arguments = arguments
                let output = Pipe(), error = Pipe(), standardInput = Pipe()
                process.standardOutput = output
                process.standardError = error
                process.standardInput = input == nil ? FileHandle.nullDevice : standardInput
                do {
                    try process.run()
                } catch {
                    return continuation.resume(returning: ToolResult(status: -1, output: "", error: "\(error)"))
                }
                if let input {
                    standardInput.fileHandleForWriting.write(Data(input.utf8))
                    try? standardInput.fileHandleForWriting.close()
                }
                let outputData = output.fileHandleForReading.readDataToEndOfFile()
                let errorData = error.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                continuation.resume(returning: ToolResult(status: process.terminationStatus,
                                                          output: String(decoding: outputData, as: UTF8.self),
                                                          error: String(decoding: errorData, as: UTF8.self)))
            }
        }
    }
}

/// Opening the apps involved.
@MainActor
enum ClockApp {
    static func openTimers() {
        open("clock-timer://")
    }

    static func openStopwatch() {
        open("clock-stopwatch://")
    }

    static func openShortcuts() {
        NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: "/System/Applications/Shortcuts.app"),
                                           configuration: NSWorkspace.OpenConfiguration())
    }

    /// Clock's own links go straight to a tab; without them, just open Clock.
    private static func open(_ link: String) {
        if let url = URL(string: link), NSWorkspace.shared.urlForApplication(toOpen: url) != nil {
            NSWorkspace.shared.open(url)
        } else {
            NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: "/System/Applications/Clock.app"),
                                               configuration: NSWorkspace.OpenConfiguration())
        }
    }
}

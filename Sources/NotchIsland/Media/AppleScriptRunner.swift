import CoreServices
import Foundation

/// An AppleScript result, converted off the script thread into plain values.
enum ScriptValue: Sendable, Equatable {
    case text(String)
    case number(Double)
    case data(Data)
    case list([ScriptValue])
    case none

    init(_ descriptor: NSAppleEventDescriptor) {
        switch descriptor.descriptorType {
        case typeAEList:
            let items = (0..<descriptor.numberOfItems).compactMap { descriptor.atIndex($0 + 1) }
            self = .list(items.map(ScriptValue.init))
        case typeIEEE64BitFloatingPoint, typeIEEE32BitFloatingPoint, typeSInt16, typeSInt32, typeSInt64, typeUInt32:
            self = .number(descriptor.doubleValue)
        case typeUnicodeText, typeUTF8Text:
            self = .text(descriptor.stringValue ?? "")
        case typeNull:
            self = .none
        default:  // images, `missing value`, …
            self = .data(descriptor.data)
        }
    }
}

/// Runs AppleScript on one dedicated thread. NSAppleScript isn't thread-safe,
/// and an Apple Event blocks until the target app replies (or until the user
/// answers the Automation prompt), which must never stall the main thread.
final class AppleScriptRunner: NSObject, @unchecked Sendable {
    struct Failure: Error, Sendable {
        let code: Int
        let message: String

        /// errAEEventNotPermitted: Automation access to the app was denied.
        var isNotPermitted: Bool { code == -1743 }
    }

    private let thread: Thread
    /// Compiled scripts by source. Only touched on `thread`.
    private var compiled: [String: NSAppleScript] = [:]

    override init() {
        thread = Thread {
            // A port keeps the run loop asleep between jobs instead of returning.
            RunLoop.current.add(NSMachPort(), forMode: .default)
            while true {
                RunLoop.current.run(mode: .default, before: .distantFuture)
            }
        }
        thread.name = "NotchIsland.AppleScript"
        thread.qualityOfService = .userInitiated
        super.init()
        thread.start()
    }

    /// - Parameter cache: keep the compiled script for reuse (skip for one-off sources).
    func run(_ source: String, cache: Bool = true) async throws -> ScriptValue {
        try await withCheckedThrowingContinuation { continuation in
            let job = Job(source: source, cache: cache, continuation: continuation)
            perform(#selector(execute(_:)), on: thread, with: job, waitUntilDone: false)
        }
    }

    @objc private func execute(_ job: Job) {
        guard let script = compiled[job.source] ?? NSAppleScript(source: job.source) else {
            return job.continuation.resume(throwing: Failure(code: -2, message: "Invalid script"))
        }
        if job.cache {
            compiled[job.source] = script
        }
        var error: NSDictionary?
        let result = script.executeAndReturnError(&error)
        if let error {
            job.continuation.resume(throwing: Failure(
                code: error[NSAppleScript.errorNumber] as? Int ?? -1,
                message: error[NSAppleScript.errorMessage] as? String ?? "Unknown error"))
        } else {
            job.continuation.resume(returning: ScriptValue(result))
        }
    }
}

private final class Job: NSObject {
    let source: String
    let cache: Bool
    let continuation: CheckedContinuation<ScriptValue, Error>

    init(source: String, cache: Bool, continuation: CheckedContinuation<ScriptValue, Error>) {
        self.source = source
        self.cache = cache
        self.continuation = continuation
    }
}

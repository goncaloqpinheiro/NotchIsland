import CoreServices
import Foundation

/// Calls back on the main queue shortly after chosen files in a folder change,
/// using FSEvents (no polling, and it survives files being replaced). Changes to
/// other files in the folder are ignored without waking the app's own code.
@MainActor
final class DirectoryWatcher {
    /// The names of the watched files that changed.
    var onChange: ((Set<String>) -> Void)?

    private let url: URL
    private let fileNames: Set<String>
    private var stream: FSEventStreamRef?

    init(url: URL, fileNames: Set<String>) {
        self.url = url
        self.fileNames = fileNames
    }

    var isRunning: Bool { stream != nil }

    func start() {
        guard stream == nil else { return }
        var context = FSEventStreamContext(version: 0, info: Unmanaged.passUnretained(self).toOpaque(),
                                           retain: nil, release: nil, copyDescription: nil)
        let callback: FSEventStreamCallback = { _, info, count, paths, _, _ in
            guard let info else { return }
            let watcher = Unmanaged<DirectoryWatcher>.fromOpaque(info).takeUnretainedValue()
            // With kFSEventStreamCreateFlagUseCFTypes, `paths` is a CFArray of CFStrings.
            let changed = (Unmanaged<CFArray>.fromOpaque(paths).takeUnretainedValue() as? [String] ?? [])
                .prefix(count)
                .map { ($0 as NSString).lastPathComponent }
            MainActor.assumeIsolated { watcher.filesChanged(Set(changed)) }
        }
        // File-level events, coalesced over 0.3 s.
        let flags = kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagUseCFTypes
        guard let stream = FSEventStreamCreate(nil, callback, &context, [url.path] as CFArray,
                                               FSEventStreamEventId(kFSEventStreamEventIdSinceNow), 0.3,
                                               FSEventStreamCreateFlags(flags)) else { return }
        FSEventStreamSetDispatchQueue(stream, .main)
        FSEventStreamStart(stream)
        self.stream = stream
    }

    func stop() {
        guard let stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
    }

    private func filesChanged(_ names: Set<String>) {
        let watched = names.intersection(fileNames)
        Log.app.debug("Folder events: \(names.sorted().joined(separator: ", "), privacy: .public)")
        guard !watched.isEmpty else { return }
        onChange?(watched)
    }
}

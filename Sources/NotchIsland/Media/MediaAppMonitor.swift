import AppKit

/// Follows one player app. Its distributed notification says when something
/// changed (no polling); an AppleScript query then fills in what the
/// notification doesn't carry, like Music's position or Spotify's artwork URL.
@MainActor
final class MediaAppMonitor {
    let app: MediaApp
    /// nil means the app isn't playing anything (stopped or quit).
    var onUpdate: ((PlayerSnapshot?) -> Void)?
    /// Automation access to the app was denied (true) or works (false).
    var onPermissionChange: ((Bool) -> Void)?

    private let scripts: AppleScriptRunner
    private var observers: [NSObjectProtocol] = []
    private var refreshTask: Task<Void, Never>?

    init(app: MediaApp, scripts: AppleScriptRunner) {
        self.app = app
        self.scripts = scripts
    }

    func start() {
        observers.append(DistributedNotificationCenter.default().addObserver(
            forName: app.playbackNotification, object: nil, queue: .main
        ) { [weak self] note in
            let userInfo = note.userInfo ?? [:]
            MainActor.assumeIsolated { self?.playbackChanged(userInfo) }
        })
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            let quit = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            MainActor.assumeIsolated {
                guard let self, quit?.bundleIdentifier == self.app.bundleID else { return }
                self.refreshTask?.cancel()
                self.onUpdate?(nil)
            }
        })
        refresh()
    }

    private func playbackChanged(_ userInfo: [AnyHashable: Any]) {
        // Show what the notification says right away, then complete it.
        onUpdate?(PlayerSnapshot(notification: userInfo, app: app))
        refresh()
    }

    /// Asks the app for its full state. Does nothing if it isn't running, so it
    /// never launches the app.
    func refresh() {
        guard app.isRunning else { return }
        refreshTask?.cancel()
        refreshTask = Task { [weak self, app, scripts] in
            do {
                let value = try await scripts.run(MediaScripts.status(app))
                guard !Task.isCancelled, let self else { return }
                self.onPermissionChange?(false)
                self.onUpdate?(PlayerSnapshot(script: value, app: app))
            } catch let failure as AppleScriptRunner.Failure {
                Log.media.debug("\(app.name, privacy: .public) status failed: \(failure.code) \(failure.message, privacy: .public)")
                if failure.isNotPermitted { self?.onPermissionChange?(true) }
            } catch {}
        }
    }

    func send(_ command: MediaCommand) async {
        guard app.isRunning else { return }
        do {
            // Seek sources differ every time, so don't cache them.
            _ = try await scripts.run(MediaScripts.command(command, app: app), cache: command == .togglePlayPause || command == .next || command == .previous)
            onPermissionChange?(false)
            // Players don't always announce a seek; read the new position back.
            if case .seek = command { refresh() }
        } catch let failure as AppleScriptRunner.Failure {
            Log.media.debug("\(self.app.name, privacy: .public) command failed: \(failure.code) \(failure.message, privacy: .public)")
            if failure.isNotPermitted { onPermissionChange?(true) }
        } catch {}
    }

    /// Music only: the current track's cover, as image file data.
    func artworkData() async -> Data? {
        guard app == .music, app.isRunning,
              case .data(let data)? = try? await scripts.run(MediaScripts.musicArtwork) else { return nil }
        return data
    }
}

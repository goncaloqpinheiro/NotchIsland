import AppKit

/// Merges every source (Spotify and Music, YouTube in Chrome or Safari) into one
/// "now playing", loads artwork, and sends playback commands to the source shown.
@MainActor
final class NowPlayingController {
    private let model: NowPlayingModel
    private let scripts = AppleScriptRunner()
    private let audio = AudioActivityMonitor()
    private let assertions = PowerAssertionMonitor()
    private var apps: [MediaApp: MediaAppMonitor] = [:]
    private var browsers: [Browser: BrowserMediaMonitor] = [:]
    private var browserPlayback: [Browser: BrowserPlayback] = [:]
    private var latest: [MediaSource: (snapshot: PlayerSnapshot, receivedAt: Date)] = [:]
    /// Which track (and cover URL) the current artwork belongs to.
    private var artworkKey: String?
    private var artworkTask: Task<Void, Never>?

    init(model: NowPlayingModel) {
        self.model = model
    }

    func start() {
        for app in MediaApp.allCases {
            let monitor = MediaAppMonitor(app: app, scripts: scripts)
            monitor.onUpdate = { [weak self] snapshot in self?.update(.app(app), snapshot) }
            monitor.onPermissionChange = { [weak self] denied in self?.model.setPermissionDenied(denied, for: .app(app)) }
            apps[app] = monitor
            monitor.start()
        }

        for browser in Browser.allCases {
            let monitor = BrowserMediaMonitor(browser: browser, scripts: scripts)
            monitor.onUpdate = { [weak self] snapshot in self?.update(.browser(browser), snapshot) }
            monitor.onPermissionChange = { [weak self] denied in self?.model.setPermissionDenied(denied, for: .browser(browser)) }
            browsers[browser] = monitor
        }
        // Browsers don't announce playback. Their audio output says when they start
        // (and eventually stop); while it runs, media power assertions notice a pause sooner.
        audio.isRelevant = { bundleID in Browser.allCases.contains { $0.owns(bundleID: bundleID) } }
        audio.onChange = { [weak self] _ in self?.updateBrowserPlayback() }
        assertions.onChange = { [weak self] _ in self?.updateBrowserPlayback() }
        audio.start()
    }

    // MARK: - Commands

    func togglePlayPause() {
        send(.togglePlayPause) { $0.setPlaying(!$0.isPlaying) }
    }

    func next() {
        send(.next)
    }

    func previous() {
        send(.previous)
    }

    func seek(to seconds: TimeInterval) {
        send(.seek(seconds)) { $0.setPosition(seconds) }
    }

    /// Re-reads the shown source, e.g. when the island opens (a seek made in the
    /// player itself isn't announced).
    func refresh() {
        switch model.source {
        case .app(let app)?: apps[app]?.refresh()
        case .browser(let browser)?: browsers[browser]?.refresh()
        case nil: break
        }
    }

    /// Switches to the player, or to the browser tab with the video.
    func openPlayer() {
        switch model.source {
        case .app(let app)?:
            NSRunningApplication.runningApplications(withBundleIdentifier: app.bundleID).first?.activate()
        case .browser(let browser)?:
            browsers[browser]?.showTab()
        case nil:
            break
        }
    }

    private func send(_ command: MediaCommand, optimistic: ((NowPlayingModel) -> Void)? = nil) {
        guard let source = model.source else { return }
        switch source {
        case .app(let app):
            guard let monitor = apps[app] else { return }
            optimistic?(model)
            Task { await monitor.send(command) }
        case .browser:
            if case .seek = command { return }  // no timeline for browser media
            optimistic?(model)
            // Goes to macOS's active media session: the tab that played last.
            MediaRemoteCommands.send(command)
        }
    }

    // MARK: - Updates

    private func updateBrowserPlayback() {
        assertions.setActive(!audio.playing.isEmpty)
        for (browser, monitor) in browsers {
            let playing = browserPlayback[browser, default: BrowserPlayback()].isPlaying(
                makingSound: audio.playing.contains(where: browser.owns(bundleID:)),
                holdsMediaAssertion: assertions.holders.contains(where: browser.owns(bundleID:)))
            monitor.setPlaying(playing)
        }
    }

    private func update(_ source: MediaSource, _ snapshot: PlayerSnapshot?) {
        latest[source] = snapshot.map { ($0, .now) }
        let shown = SourcePicker.pick(latest.mapValues { ($0.snapshot.isPlaying, $0.receivedAt) })
        let shownSnapshot = shown.flatMap { latest[$0]?.snapshot }
        model.apply(source: shown, snapshot: shownSnapshot)
        if let shown, let shownSnapshot {
            loadArtwork(source: shown, snapshot: shownSnapshot)
        } else {
            artworkKey = nil
            artworkTask?.cancel()
        }
    }

    private func loadArtwork(source: MediaSource, snapshot: PlayerSnapshot) {
        let key: String
        let fetch: () async -> Data?
        if let url = snapshot.artworkURL {
            key = "\(snapshot.trackID)|\(url.absoluteString)"
            fetch = { try? await URLSession.shared.data(from: url).0 }
        } else if source == .app(.music) {
            key = snapshot.trackID
            let monitor = apps[.music]
            fetch = { await monitor?.artworkData() }
        } else {
            return  // Spotify's cover URL arrives with the AppleScript refresh
        }
        guard key != artworkKey else { return }
        artworkKey = key
        artworkTask?.cancel()
        artworkTask = Task { [weak self] in
            guard let data = await fetch(), !Task.isCancelled else { return }
            let decoded = await Task.detached { Self.decode(data) }.value
            guard !Task.isCancelled, let self, self.artworkKey == key, let decoded else { return }
            let image = NSImage(cgImage: decoded.image, size: .zero)
            self.model.setArtwork(image, accent: decoded.accent)
        }
    }

    private nonisolated static func decode(_ data: Data) -> (image: CGImage, accent: NSColor?)? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
        return (image, ArtworkPalette.accentColor(of: image))
    }
}

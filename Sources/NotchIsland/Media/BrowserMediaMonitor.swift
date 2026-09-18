import AppKit

/// Follows YouTube in one browser. The browser starting or stopping sound
/// (reported by AudioActivityMonitor) triggers one AppleScript read of its tabs
/// to find the video, and YouTube's public oEmbed endpoint adds the title and
/// channel. While sound continues, tabs are re-read every 15 s to notice
/// autoplay moving to the next video.
@MainActor
final class BrowserMediaMonitor {
    static let refreshWhilePlaying: TimeInterval = 15

    let browser: Browser
    /// nil means no YouTube video is open.
    var onUpdate: ((PlayerSnapshot?) -> Void)?
    /// Automation access to the browser was denied (true) or works (false).
    var onPermissionChange: ((Bool) -> Void)?

    private let scripts: AppleScriptRunner
    private var isPlaying = false
    private var tab: YouTubeTab?
    private var info: (videoID: String, value: YouTube.VideoInfo)?
    private var refreshTask: Task<Void, Never>?
    private var heartbeat: Task<Void, Never>?

    init(browser: Browser, scripts: AppleScriptRunner) {
        self.browser = browser
        self.scripts = scripts
    }

    /// Whether any of the browser's processes is producing sound.
    func setPlaying(_ playing: Bool) {
        guard playing != isPlaying else { return }
        isPlaying = playing
        heartbeat?.cancel()
        heartbeat = nil
        if playing {
            heartbeat = Task { [weak self] in
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(Self.refreshWhilePlaying))
                    guard !Task.isCancelled else { return }
                    self?.refresh()
                }
            }
        }
        refresh()
    }

    /// Re-reads the browser's tabs. Never launches the browser, and doesn't
    /// contact it (or trigger its Automation prompt) before it has played sound.
    func refresh() {
        guard MediaSource.browser(browser).isRunning else {
            tab = nil
            onUpdate?(nil)
            return
        }
        guard isPlaying || tab != nil else { return }
        refreshTask?.cancel()
        refreshTask = Task { [weak self, browser, scripts] in
            do {
                let value = try await scripts.run(MediaScripts.browserTabs(browser))
                guard !Task.isCancelled, let self else { return }
                self.onPermissionChange?(false)
                self.tab = YouTube.likelyPlayingTab(in: BrowserWindowTabs.parse(value))
                self.publish()
                await self.loadInfoIfNeeded()
            } catch let failure as AppleScriptRunner.Failure {
                Log.media.debug("\(browser.name, privacy: .public) tabs failed: \(failure.code) \(failure.message, privacy: .public)")
                if failure.isNotPermitted { self?.onPermissionChange?(true) }
            } catch {}
        }
    }

    /// Brings the video's tab to the front.
    func showTab() {
        guard let url = tab?.url else { return }
        Task { [browser, scripts] in
            _ = try? await scripts.run(MediaScripts.showTab(url: url, in: browser), cache: false)
        }
    }

    private func publish() {
        guard let tab else {
            onUpdate?(nil)
            return
        }
        let known = info?.videoID == tab.videoID ? info?.value : nil
        onUpdate?(PlayerSnapshot(
            isPlaying: isPlaying,
            title: known?.title ?? tab.title,
            artist: known?.channel ?? "YouTube",
            album: "",
            duration: 0,  // not readable without running scripts inside the page
            position: nil,
            capturedAt: .now,
            trackID: tab.videoID,
            artworkURL: YouTube.thumbnailURL(videoID: tab.videoID)))
    }

    private func loadInfoIfNeeded() async {
        guard let videoID = tab?.videoID, info?.videoID != videoID,
              let value = await YouTube.videoInfo(videoID: videoID),
              tab?.videoID == videoID else { return }
        info = (videoID, value)
        publish()
    }
}

import AppKit
import Observation

/// What the island shows about media. Fed by NowPlayingController.
@MainActor
@Observable
final class NowPlayingModel {
    /// How long the compact activity stays beside the notch after pausing.
    static let pausedLinger: TimeInterval = 8

    private(set) var source: MediaSource?
    private(set) var title = ""
    private(set) var artist = ""
    private(set) var duration: TimeInterval = 0
    private(set) var isPlaying = false
    private(set) var trackID = ""
    private(set) var artwork: NSImage?
    /// Tint from the artwork for the audio bars; white until known.
    private(set) var accentColor = NSColor.white
    /// Sources whose Automation access was denied.
    private(set) var deniedSources: Set<MediaSource> = []
    /// Art and audio bars beside the notch: while playing, and briefly after pausing.
    private(set) var showsLiveActivity = false

    private var position: TimeInterval = 0
    private var positionDate = Date.distantPast
    @ObservationIgnored private var lingerTask: Task<Void, Never>?

    var hasTrack: Bool { source != nil && !title.isEmpty }

    /// Seconds into the track at `date`, extrapolated while playing.
    func elapsed(at date: Date) -> TimeInterval {
        let running = isPlaying ? max(0, date.timeIntervalSince(positionDate)) : 0
        let value = max(0, position + running)
        return duration > 0 ? min(value, duration) : value
    }

    func apply(source: MediaSource?, snapshot: PlayerSnapshot?) {
        guard let source, let snapshot else {
            update(\.source, nil)
            update(\.title, "")
            update(\.artist, "")
            update(\.duration, 0)
            update(\.isPlaying, false)
            update(\.trackID, "")
            setArtwork(nil, accent: nil)
            updateLiveActivity()
            return
        }

        let trackChanged = source != self.source || snapshot.trackID != trackID
        if let reported = snapshot.position {
            position = reported
            positionDate = snapshot.capturedAt
        } else if trackChanged {
            position = 0
            positionDate = snapshot.capturedAt
        } else if snapshot.isPlaying != isPlaying {
            // No position reported: carry the running estimate across play/pause.
            position = elapsed(at: snapshot.capturedAt)
            positionDate = snapshot.capturedAt
        }
        if trackChanged {
            setArtwork(nil, accent: nil)
        }
        update(\.source, source)
        update(\.title, snapshot.title)
        update(\.artist, snapshot.artist)
        update(\.duration, snapshot.duration)
        update(\.trackID, snapshot.trackID)
        update(\.isPlaying, snapshot.isPlaying)
        updateLiveActivity()
    }

    func setArtwork(_ image: NSImage?, accent: NSColor?) {
        update(\.artwork, image)
        update(\.accentColor, accent ?? .white)
    }

    /// Optimistic update right after a play/pause click.
    func setPlaying(_ playing: Bool) {
        position = elapsed(at: .now)
        positionDate = .now
        update(\.isPlaying, playing)
        updateLiveActivity()
    }

    /// Optimistic update right after a seek.
    func setPosition(_ seconds: TimeInterval) {
        position = seconds
        positionDate = .now
    }

    func setPermissionDenied(_ denied: Bool, for source: MediaSource) {
        guard deniedSources.contains(source) != denied else { return }
        if denied { deniedSources.insert(source) } else { deniedSources.remove(source) }
    }

    /// Assigns only real changes, so views reading the property don't redraw for nothing.
    private func update<Value: Equatable>(_ keyPath: ReferenceWritableKeyPath<NowPlayingModel, Value>, _ value: Value) {
        if self[keyPath: keyPath] != value {
            self[keyPath: keyPath] = value
        }
    }

    private func updateLiveActivity() {
        if hasTrack && isPlaying {
            lingerTask?.cancel()
            lingerTask = nil
            update(\.showsLiveActivity, true)
        } else if !hasTrack {
            lingerTask?.cancel()
            lingerTask = nil
            update(\.showsLiveActivity, false)
        } else if showsLiveActivity && lingerTask == nil {
            lingerTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(Self.pausedLinger))
                guard !Task.isCancelled, let self else { return }
                self.lingerTask = nil
                self.update(\.showsLiveActivity, false)
            }
        }
    }
}

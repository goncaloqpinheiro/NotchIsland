import SwiftUI

/// A media interaction (music starting, pausing, resuming, or moving to
/// another track) lights the glass around the island for a moment, the way an
/// alert does. It fades again while the music keeps playing, so nothing blurs
/// for hours. Position updates while a track runs aren't interactions.
@MainActor
final class MediaGlassController {
    private let model: NotchViewModel
    private var nowPlaying: NowPlayingModel { model.nowPlaying }
    private var last: Signature?
    private var hideTask: Task<Void, Never>?

    /// What counts as an interaction: which player, which track, playing or not.
    private struct Signature: Equatable {
        var source: MediaSource?
        var trackID: String
        var isPlaying: Bool
    }

    init(model: NotchViewModel) {
        self.model = model
    }

    func start() {
        last = signature()
        observe()
    }

    private func signature() -> Signature {
        Signature(source: nowPlaying.source, trackID: nowPlaying.trackID, isPlaying: nowPlaying.isPlaying)
    }

    private func observe() {
        withObservationTracking {
            _ = signature()
        } onChange: { [weak self] in
            // onChange runs before the new value is stored; read it next turn.
            Task { @MainActor in self?.mediaChanged() }
        }
    }

    private func mediaChanged() {
        defer { observe() }
        let now = signature()
        guard now != last else { return }
        last = now
        // With the music gone there's only the bare notch; nothing to light up.
        guard nowPlaying.hasTrack else { return }
        light()
    }

    private func light() {
        if !model.showsMediaGlass {
            withAnimation(NotchStyle.expand) {
                model.showsMediaGlass = true
            }
        }
        hideTask?.cancel()
        hideTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(NotchStyle.mediaGlassDuration))
            guard !Task.isCancelled, let self else { return }
            withAnimation(NotchStyle.glassOut) {
                self.model.showsMediaGlass = false
            }
        }
    }
}

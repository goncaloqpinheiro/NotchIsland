import SwiftUI

/// Previous, play/pause and next.
struct MediaControlsView: View {
    let isPlaying: Bool
    let actions: NowPlayingActions

    var body: some View {
        HStack(spacing: 34) {
            control("backward.fill", size: 16, action: actions.previous)
            control(isPlaying ? "pause.fill" : "play.fill", size: 22, action: actions.togglePlayPause)
            control("forward.fill", size: 16, action: actions.next)
        }
        .frame(maxWidth: .infinity)
    }

    private func control(_ symbol: String, size: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size, weight: .semibold))
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 38, height: 30)
                .contentShape(Rectangle())
        }
        .buttonStyle(IslandButtonStyle())
    }
}

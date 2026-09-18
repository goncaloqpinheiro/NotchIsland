import SwiftUI

/// Music playing while the timer holds the island: a small separate bubble to
/// its right with the album art, like the Dynamic Island's second activity.
struct MusicBubbleView: View {
    let nowPlaying: NowPlayingModel
    let diameter: CGFloat

    var body: some View {
        Circle()
            .fill(.black)
            .frame(width: diameter, height: diameter)
            .overlay {
                ArtworkView(image: nowPlaying.artwork, cornerRadius: diameter * 0.2)
                    .frame(width: diameter - 10, height: diameter - 10)
            }
    }
}

extension AnyTransition {
    /// The bubble splits off from the island's edge, and merges back into it.
    static func bubbleSplit(distance: CGFloat) -> AnyTransition {
        .modifier(active: BubbleSplitEffect(distance: distance, visible: false),
                  identity: BubbleSplitEffect(distance: distance, visible: true))
    }
}

private struct BubbleSplitEffect: ViewModifier {
    let distance: CGFloat
    let visible: Bool

    func body(content: Content) -> some View {
        content
            .scaleEffect(visible ? 1 : 0.4)
            .offset(x: visible ? 0 : -distance)
            .opacity(visible ? 1 : 0)
    }
}

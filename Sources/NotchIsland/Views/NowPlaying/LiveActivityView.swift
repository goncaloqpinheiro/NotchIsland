import SwiftUI

/// The compact activity while music plays: art to the left of the camera
/// housing, audio bars to the right, at the notch's own height.
struct LiveActivityView: View {
    let nowPlaying: NowPlayingModel
    let size: CGSize
    let notchWidth: CGFloat

    var body: some View {
        // The shape's top corners flare outward by this much; center content in
        // the straight part of each ear.
        let inset = NotchStyle.collapsedTopRadius
        let earWidth = (size.width - notchWidth) / 2 - inset
        let artSide = size.height - 8
        HStack(spacing: 0) {
            ArtworkView(image: nowPlaying.artwork, cornerRadius: 5)
                .frame(width: artSide, height: artSide)
                .frame(width: earWidth)
            Spacer(minLength: 0)
            AudioBarsView(isPlaying: nowPlaying.isPlaying, color: nowPlaying.accentColor)
                .frame(width: 16, height: 12)
                .frame(width: earWidth)
        }
        .padding(.horizontal, inset)
        .frame(width: size.width, height: size.height)
    }
}

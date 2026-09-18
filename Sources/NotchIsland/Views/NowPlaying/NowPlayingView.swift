import SwiftUI

/// The open island while there's a track: art, title and artist, progress, controls.
struct NowPlayingView: View {
    let nowPlaying: NowPlayingModel
    let size: CGSize
    let notchHeight: CGFloat
    let actions: NowPlayingActions

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.top, notchHeight + 8)
            PlaybackProgressView(nowPlaying: nowPlaying, onSeek: actions.seek)
                .padding(.top, 12)
                .opacity(nowPlaying.duration > 0 ? 1 : 0)  // streams have no length
            MediaControlsView(isPlaying: nowPlaying.isPlaying, actions: actions)
                .padding(.top, 6)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 22)
        .frame(width: size.width, height: size.height, alignment: .top)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button(action: actions.openPlayer) {
                ArtworkView(image: nowPlaying.artwork, cornerRadius: 10)
                    .frame(width: 52, height: 52)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 3) {
                Text(nowPlaying.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                Text(nowPlaying.artist)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)

            AudioBarsView(isPlaying: nowPlaying.isPlaying, color: nowPlaying.accentColor)
                .frame(width: 22, height: 18)
        }
    }
}

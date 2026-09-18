import AVFoundation
import SwiftUI

/// Apple's turning 3D animation of the headphones, or a swinging symbol when
/// macOS has none for this model.
struct HeadphonesAnimationView: View {
    let info: HeadphonesInfo
    @Environment(\.isRenderingSnapshot) private var isRenderingSnapshot
    @Environment(\.snapshotTime) private var snapshotTime
    /// When the rendered demo first showed it, so the movie starts from the top.
    @State private var shownAt: TimeInterval?

    var body: some View {
        if let url = ProductAnimation.url(forProductID: info.productID) {
            if isRenderingSnapshot, let frame = VideoFrames.frame(of: url, at: movieTime) {
                Image(decorative: frame, scale: 2)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .onAppear { shownAt = snapshotTime }
            } else {
                LoopingVideoView(url: url)
            }
        } else {
            SwingingSymbol(name: info.fallbackSymbol)
        }
    }
}

/// Snapshots show the first frame; the rendered demo plays it by the clock.
extension HeadphonesAnimationView {
    private var movieTime: TimeInterval {
        guard let snapshotTime else { return 0 }
        return snapshotTime - (shownAt ?? snapshotTime)
    }
}

/// Loops a movie with a transparent background.
private struct LoopingVideoView: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> LoopingVideoPlayerView {
        LoopingVideoPlayerView(url: url)
    }

    func updateNSView(_ view: LoopingVideoPlayerView, context: Context) {}
}

final class LoopingVideoPlayerView: NSView {
    private let player = AVQueuePlayer()
    private var looper: AVPlayerLooper?

    init(url: URL) {
        super.init(frame: .zero)
        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.videoGravity = .resizeAspect
        playerLayer.backgroundColor = .clear
        // Follow SwiftUI's frame changes exactly (the card shrinking to the compact
        // pill) instead of trailing behind with Core Animation's implicit animations.
        playerLayer.actions = ["bounds": NSNull(), "position": NSNull(), "frame": NSNull()]
        layer = playerLayer  // a layer-hosting view: set the layer before wantsLayer
        wantsLayer = true
        player.isMuted = true
        looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: url))
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    // Decode only while on screen.
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil {
            player.pause()
        } else {
            player.play()
        }
    }
}

/// A symbol turning back and forth in 3D, sized to its frame.
private struct SwingingSymbol: View {
    let name: String
    @State private var angle = -35.0

    var body: some View {
        Image(systemName: name)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .scaleEffect(0.55)
            .foregroundStyle(.white)
            .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                    angle = 35
                }
            }
    }
}

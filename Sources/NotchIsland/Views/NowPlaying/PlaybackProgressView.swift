import SwiftUI

/// Elapsed and remaining time around a bar you can click or drag to seek.
struct PlaybackProgressView: View {
    let nowPlaying: NowPlayingModel
    let onSeek: (TimeInterval) -> Void
    /// Where the drag is, 0...1, while scrubbing.
    @State private var scrub: Double?

    var body: some View {
        // Redraws twice a second while playing (and only while the island is open).
        TimelineView(.periodic(from: .now, by: nowPlaying.isPlaying ? 0.5 : 3600)) { context in
            let duration = nowPlaying.duration
            let elapsed = scrub.map { $0 * duration } ?? nowPlaying.elapsed(at: context.date)
            let fraction = duration > 0 ? min(max(elapsed / duration, 0), 1) : 0
            HStack(spacing: 10) {
                timeLabel(Self.format(elapsed), alignment: .trailing)
                bar(fraction: fraction, duration: duration)
                timeLabel("-" + Self.format(max(duration - elapsed, 0)), alignment: .leading)
            }
        }
    }

    private func bar(fraction: Double, duration: TimeInterval) -> some View {
        GeometryReader { geometry in
            let width = max(geometry.size.width, 1)
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.2))
                Capsule().fill(.white).frame(width: width * fraction)
            }
            .frame(height: scrub == nil ? 4 : 6)
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        scrub = min(max(drag.location.x / width, 0), 1)
                    }
                    .onEnded { drag in
                        scrub = nil
                        onSeek(min(max(drag.location.x / width, 0), 1) * duration)
                    }
            )
            .animation(.spring(duration: 0.2), value: scrub == nil)
        }
        .frame(height: 12)
    }

    private func timeLabel(_ text: String, alignment: Alignment) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .medium).monospacedDigit())
            .foregroundStyle(.white.opacity(0.5))
            .frame(minWidth: 34, alignment: alignment)
    }

    static func format(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded(.down))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

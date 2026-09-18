import AVFoundation

/// Frames of a movie by time, for snapshots and the rendered demo, which can't
/// play video. The movie loops, as it does on screen.
@MainActor
enum VideoFrames {
    private struct Movie {
        let generator: AVAssetImageGenerator
        let duration: TimeInterval
    }

    private static var movies: [URL: Movie] = [:]

    static func frame(of url: URL, at time: TimeInterval) -> CGImage? {
        let movie = movies[url] ?? load(url)
        movies[url] = movie
        let seconds = movie.duration > 0 ? time.truncatingRemainder(dividingBy: movie.duration) : 0
        return wait { (box: Box<CGImage>, done) in
            movie.generator.generateCGImageAsynchronously(for: CMTime(seconds: max(0, seconds), preferredTimescale: 600)) { image, _, _ in
                box.value = image
                done.signal()
            }
        }
    }

    private static func load(_ url: URL) -> Movie {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        let duration = wait { (box: Box<TimeInterval>, done) in
            Task.detached {
                box.value = (try? await asset.load(.duration))?.seconds
                done.signal()
            }
        }
        return Movie(generator: generator, duration: duration ?? 0)
    }

    private final class Box<Value>: @unchecked Sendable {
        var value: Value?
    }

    /// Waits a moment for a result that arrives on another thread.
    private static func wait<Value>(_ start: (Box<Value>, DispatchSemaphore) -> Void) -> Value? {
        let box = Box<Value>()
        let done = DispatchSemaphore(value: 0)
        start(box, done)
        _ = done.wait(timeout: .now() + 2)
        return box.value
    }
}

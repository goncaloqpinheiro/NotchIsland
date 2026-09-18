import AppKit
import SwiftUI

/// Dev tool: `NotchIsland --docs-demo <gif> <movie>` (or `make docs-demo`)
/// renders the animated demo: the README's GIF, and a 1080p movie with
/// captions for sharing. Every frame is the app's own island, stepped through
/// its real animations one frame at a time; nothing is recorded from the screen.
@MainActor
enum DocsDemo {
    static func runIfRequested() -> Bool {
        let args = CommandLine.arguments
        guard let flag = args.firstIndex(of: "--docs-demo"), args.indices.contains(flag + 2) else {
            return false
        }
        NSApplication.shared.setActivationPolicy(.prohibited)  // no Dock icon while it works
        defer { ScratchDefaults.removeAll() }
        renderGIF(to: URL(fileURLWithPath: args[flag + 1]))
        renderMovie(to: URL(fileURLWithPath: args[flag + 2]))
        return true
    }

    /// The README's loop: the top of the screen, 25 frames a second.
    private static func renderGIF(to url: URL) {
        let size = CGSize(width: 520, height: 190)
        let screen = { (stage: DemoStage) in DemoScreen(stage: stage, width: size.width, height: size.height) }
        // A quick pass to learn the colors the animation needs, then the real one.
        var histogram = GIFPalette.Histogram()
        play(DemoScript.loop, fps: 4, size: size, view: screen) { histogram.add($0) }
        let scale = 2.0
        let writer = GIFWriter(width: Int(size.width * scale), height: Int(size.height * scale), delay: 4,
                               palette: GIFPalette(histogram))
        play(DemoScript.loop, fps: 25, size: size, view: screen) { writer.add($0) }
        do {
            try writer.write(to: url)
            print("Wrote \(url.path)")
        } catch {
            print("Failed to write \(url.path): \(error.localizedDescription)")
        }
    }

    /// The film: 1920 by 1080, 60 frames a second, with captions.
    private static func renderMovie(to url: URL) {
        let size = DemoFilm.size
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard let writer = MovieWriter(url: url, width: Int(size.width) * 2, height: Int(size.height) * 2, fps: 60) else {
            return print("Failed to start \(url.path)")
        }
        play(0...DemoScript.length, fps: 60, size: size, view: { DemoFilm(stage: $0) }) { writer.add($0) }
        print(writer.finish() ? "Wrote \(url.path)" : "Failed to write \(url.path)")
    }

    /// Plays the script on a fresh stage, handing over each frame.
    private static func play<Content: View>(_ range: ClosedRange<TimeInterval>, fps: Double, size: CGSize,
                                            view: (DemoStage) -> Content, frame: (CGImage) -> Void) {
        let stage = DemoStage()
        let stepper = FrameStepper(view(stage), size: size)
        defer { stepper.close() }
        for _ in 0..<10 {
            _ = stepper.step(by: 1 / fps)  // let the first layout settle
        }
        var moments = DemoScript.moments[...]
        let count = Int(((range.upperBound - range.lowerBound) * fps).rounded())
        for index in 0..<count {
            let time = range.lowerBound + Double(index) / fps
            while let moment = moments.first, moment.time <= time {
                moment.action(stage)
                moments = moments.dropFirst()
            }
            stage.time = time
            if let image = stepper.step(by: 1 / fps) {
                frame(image)
            }
        }
    }
}

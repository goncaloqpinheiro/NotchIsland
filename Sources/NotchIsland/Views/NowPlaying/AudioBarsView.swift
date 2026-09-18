import AppKit
import SwiftUI

/// Bars that dance while music plays and settle when it pauses. The animation
/// runs in Core Animation's render server, so the app does no per-frame work.
struct AudioBarsView: View {
    let isPlaying: Bool
    let color: NSColor
    @Environment(\.isRenderingSnapshot) private var isRenderingSnapshot
    @Environment(\.snapshotTime) private var snapshotTime

    var body: some View {
        if isRenderingSnapshot {
            GeometryReader { geometry in
                let gap = geometry.size.width * AudioBarsLayerView.gapRatio
                HStack(spacing: gap) {
                    ForEach(AudioBarsLayerView.stillLevels.indices, id: \.self) { index in
                        let dancing = snapshotTime.map { AudioBarsLayerView.level(bar: index, at: $0) }
                        let level = isPlaying ? dancing ?? AudioBarsLayerView.stillLevels[index] : AudioBarsLayerView.restingLevel
                        Capsule()
                            .fill(Color(nsColor: color))
                            .frame(height: geometry.size.height * level)
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
        } else {
            AudioBarsRepresentable(isPlaying: isPlaying, color: color)
        }
    }
}

private struct AudioBarsRepresentable: NSViewRepresentable {
    let isPlaying: Bool
    let color: NSColor

    func makeNSView(context: Context) -> AudioBarsLayerView {
        AudioBarsLayerView()
    }

    func updateNSView(_ view: AudioBarsLayerView, context: Context) {
        view.color = color
        view.isPlaying = isPlaying
    }
}

final class AudioBarsLayerView: NSView {
    static let gapRatio: CGFloat = 0.14
    static let restingLevel: CGFloat = 0.3
    /// Stand-in heights for snapshots.
    static let stillLevels: [CGFloat] = [0.55, 1, 0.7, 0.4]

    /// Looping heights per bar; each loop starts and ends on the same level.
    private static let patterns: [[CGFloat]] = [
        [0.35, 0.8, 0.5, 1.0, 0.45, 0.7, 0.35],
        [0.6, 1.0, 0.4, 0.85, 0.3, 0.95, 0.6],
        [0.45, 0.65, 1.0, 0.5, 0.9, 0.4, 0.45],
        [0.3, 0.7, 0.45, 0.6, 1.0, 0.55, 0.3],
    ]

    /// Each bar loops at its own pace, so they never line up.
    static func danceDuration(bar index: Int) -> TimeInterval {
        1.1 + Double(index) * 0.17
    }

    /// Where a bar's dance is at a moment, for the rendered demo: the looping
    /// curve Core Animation draws through the same pattern (Catmull-Rom).
    static func level(bar index: Int, at time: TimeInterval) -> CGFloat {
        let loop = Array(patterns[index].dropLast())  // the last level repeats the first
        let position = (time / danceDuration(bar: index)).truncatingRemainder(dividingBy: 1) * Double(loop.count)
        let segment = Int(position)
        let t = CGFloat(position - Double(segment))
        func point(_ offset: Int) -> CGFloat { loop[(segment + offset + loop.count) % loop.count] }
        let (p0, p1, p2, p3) = (point(-1), point(0), point(1), point(2))
        let level = 0.5 * (2 * p1 + (p2 - p0) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t
                           + (3 * p1 - p0 - 3 * p2 + p3) * t * t * t)
        return min(max(level, 0.2), 1)
    }

    var color = NSColor.white {
        didSet { if color != oldValue { applyColor() } }
    }

    var isPlaying = false {
        didSet { if isPlaying != oldValue { updateAnimation() } }
    }

    private let bars = patterns.map { _ in CALayer() }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        for bar in bars {
            bar.transform = CATransform3DMakeScale(1, Self.restingLevel, 1)
            layer?.addSublayer(bar)
        }
        applyColor()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    override func layout() {
        super.layout()
        withoutImplicitAnimations {
            let count = CGFloat(bars.count)
            let gap = bounds.width * Self.gapRatio
            let width = (bounds.width - gap * (count - 1)) / count
            for (index, bar) in bars.enumerated() {
                bar.bounds = CGRect(x: 0, y: 0, width: width, height: bounds.height)
                bar.position = CGPoint(x: CGFloat(index) * (width + gap) + width / 2, y: bounds.midY)
                bar.cornerRadius = width / 2
            }
        }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        // Layers lose their animations when they leave a window; restart them.
        updateAnimation()
    }

    private func applyColor() {
        withoutImplicitAnimations {
            bars.forEach { $0.backgroundColor = color.cgColor }
        }
    }

    private func updateAnimation() {
        for (index, bar) in bars.enumerated() {
            let current = bar.presentation()?.value(forKeyPath: "transform.scale.y") as? CGFloat ?? Self.restingLevel
            bar.removeAllAnimations()
            guard window != nil else { continue }

            if isPlaying {
                let levels = Self.patterns[index]
                let dance = CAKeyframeAnimation(keyPath: "transform.scale.y")
                dance.values = levels
                dance.keyTimes = levels.indices.map { NSNumber(value: Double($0) / Double(levels.count - 1)) }
                dance.duration = Self.danceDuration(bar: index)
                dance.calculationMode = .cubic
                dance.repeatCount = .infinity
                dance.isRemovedOnCompletion = false
                bar.add(dance, forKey: "dance")
            } else {
                let settle = CABasicAnimation(keyPath: "transform.scale.y")
                settle.fromValue = current
                settle.toValue = Self.restingLevel
                settle.duration = 0.3
                settle.timingFunction = CAMediaTimingFunction(name: .easeOut)
                bar.add(settle, forKey: "settle")
            }
        }
    }

    private func withoutImplicitAnimations(_ changes: () -> Void) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        changes()
        CATransaction.commit()
    }
}

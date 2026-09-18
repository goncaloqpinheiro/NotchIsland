import AppKit
import SwiftUI

/// Blurs whatever is behind the panel (menu bar, windows, wallpaper), fading
/// out toward its edges. Only exists while the island is hovered or open, so
/// the window server does no blur work while idle.
struct BackdropBlurView: NSViewRepresentable {
    /// 0...1. The material's own blur is fixed, so strength is its opacity:
    /// low values mix a little blur into the sharp background.
    var strength: Double
    /// Takes its color from what's behind (see `AdaptiveEffectView`).
    var adapts = false

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = AdaptiveEffectView()
        view.adapts = adapts
        // One of the most transparent materials, so it softens rather than darkens.
        view.material = .underWindowBackground
        view.blendingMode = .behindWindow
        view.state = .active  // stay blurred even though the panel is never key
        view.appearance = NSAppearance(named: .darkAqua)  // the island is black in any mode
        view.maskImage = Self.featheredMask
        view.alphaValue = strength
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.alphaValue = strength
    }

    /// Stretchable rounded rect whose edges fade to transparent over `haloSpread`.
    /// Only the feathered border and corners are fixed, so one small image masks
    /// every size the island animates through.
    static let featheredMask: NSImage = {
        let spread = NotchStyle.haloSpread
        let corner: CGFloat = 14
        let inset = spread + corner
        let side = 2 * inset + 2
        let shape = RoundedRectangle(cornerRadius: corner, style: .continuous)
            .fill(.black)
            .padding(spread * 0.6)
            .blur(radius: spread * 0.35)
            .frame(width: side, height: side)
        let renderer = ImageRenderer(content: shape)
        renderer.scale = 2
        let image = renderer.nsImage ?? NSImage(size: CGSize(width: side, height: side))
        image.capInsets = NSEdgeInsets(top: inset, left: inset, bottom: inset, right: inset)
        image.resizingMode = .stretch
        return image
    }()
}

/// A material that can take its color from what's behind it. The material is
/// a live copy of what's behind the window (wallpaper, windows, anything),
/// blurred and saturated by the window server, under a dark grey fill and
/// tone that wash those colors out. Adaptive glass swaps the grey for a light
/// milky layer and saturates a bit more, so it glows in the colors around the
/// island, like frosted glass would. Nothing is captured or sampled by the app.
/// If a future macOS builds the material differently, it stays natural.
final class AdaptiveEffectView: NSVisualEffectView {
    var adapts = false {
        didSet { adapt() }
    }

    /// The white over the blurred colors, and how much more vivid they get
    /// (the material's own saturation is 2.4).
    static let milk = CGColor(gray: 1, alpha: 0.16)
    static let saturation = 2.8

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        adapt()
    }

    override func layout() {
        super.layout()
        adapt()
    }

    override func updateLayer() {
        super.updateLayer()
        adapt()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        adapt()
    }

    private func adapt() {
        guard adapts else { return }
        for material in layer?.sublayers ?? [] {
            for part in material.sublayers ?? [] {
                switch part.name {
                case "backdrop":
                    part.setValue(Self.saturation, forKeyPath: "filters.colorSaturate.inputAmount")
                case "fill":
                    part.backgroundColor = Self.milk
                    part.opacity = 1
                case "tone", "desktop tint":
                    // The tone darkens; the tint is the whole desktop's color, not what's behind.
                    part.opacity = 0
                default:
                    break
                }
            }
        }
    }
}

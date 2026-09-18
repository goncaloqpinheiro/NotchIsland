import AppKit
import SwiftUI

/// Blurs whatever is behind the panel (menu bar, windows, wallpaper), fading
/// out toward its edges. Only exists while the island is hovered or open, so
/// the window server does no blur work while idle.
struct BackdropBlurView: NSViewRepresentable {
    /// 0...1. The material's own blur is fixed, so strength is its opacity:
    /// low values mix a little blur into the sharp background.
    var strength: Double

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
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

import AppKit
import SwiftUI

/// What shows behind the island while it's hovered or open.
enum IslandGlass: String, CaseIterable, Identifiable, Sendable {
    /// A blur of what's behind, fading out toward its edges, with a light rim
    /// along the island's own outline: soft, like Apple's own glass.
    case frosted
    /// macOS's Liquid Glass, hugging the island as a thin glass edge.
    case liquid
    /// The plain feathered blur, with no rim.
    case blur

    var id: String { rawValue }

    var name: String {
        switch self {
        case .frosted: "Frosted Glass"
        case .liquid: "Liquid Glass"
        case .blur: "Blur"
        }
    }

    /// Liquid Glass has hard edges, so it stays close to the island instead of
    /// drawing a panel around it; the blurs fade out and can reach further.
    var spread: CGFloat {
        usesLiquidGlass ? NotchStyle.glassEdgeSpread : NotchStyle.haloSpread
    }

    /// A light edge along the island's outline, the way glass catches light.
    var showsRim: Bool { self == .frosted }

    /// Liquid Glass needs macOS 26, and a build with its SDK (Swift 6.2 or
    /// later); otherwise the blur stands in.
    var usesLiquidGlass: Bool {
        guard self == .liquid else { return false }
        #if compiler(>=6.2)
        if #available(macOS 26, *) { return true }
        #endif
        return false
    }

    /// How opaque to draw it for a Settings strength of 0...1. Both kinds are
    /// see-through by nature, so a low setting would fade them away to nothing.
    func opacity(forStrength strength: Double) -> Double {
        let strength = min(max(strength, 0), 1)
        return usesLiquidGlass ? 0.3 + 0.7 * strength : 0.2 + 0.8 * strength
    }
}

/// A color for the glass, picked in Settings. Without one the glass keeps its
/// natural look.
struct GlassTint: Equatable, Sendable {
    var red: Double
    var green: Double
    var blue: Double

    init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    init(_ color: Color) {
        let srgb = NSColor(color).usingColorSpace(.sRGB) ?? .systemBlue
        self.init(red: srgb.redComponent, green: srgb.greenComponent, blue: srgb.blueComponent)
    }

    /// What Custom starts from.
    static let starting = GlassTint(red: 0.35, green: 0.55, blue: 1.0)

    var color: Color { Color(.sRGB, red: red, green: green, blue: blue) }

    /// Stored in UserDefaults as [red, green, blue].
    var stored: [Double] { [red, green, blue] }

    init?(stored: Any?) {
        guard let values = stored as? [Double], values.count == 3,
              values.allSatisfy({ (0...1).contains($0) }) else { return nil }
        self.init(red: values[0], green: values[1], blue: values[2])
    }

    /// The glow is soft and fades out, so it can be fairly strong in the middle;
    /// it follows the Strength slider like the glass does.
    static func opacity(forStrength strength: Double) -> Double {
        0.3 + 0.5 * min(max(strength, 0), 1)
    }
}

/// The glass behind the island. It only exists while the island is hovered or
/// open, so the window server does no work for it while idle.
struct IslandBackdrop: View {
    var glass: IslandGlass
    /// 0...1, from Settings.
    var strength: Double
    /// Matches the island's own corners, one spread further out.
    var cornerRadius: CGFloat
    /// A color from Settings, or nil for the glass's natural look.
    var tint: GlassTint?
    @Environment(\.isRenderingSnapshot) private var isRenderingSnapshot

    var body: some View {
        let opacity = glass.opacity(forStrength: strength)
        ZStack {
            // Blur and Liquid Glass come from the window server, which snapshots can't draw.
            if !isRenderingSnapshot {
                #if compiler(>=6.2)
                if glass.usesLiquidGlass, #available(macOS 26, *) {
                    GlassBackdrop(opacity: opacity, cornerRadius: cornerRadius,
                                  tint: tint.map { NSColor($0.color).withAlphaComponent(GlassTint.opacity(forStrength: strength)) })
                } else {
                    BackdropBlurView(strength: opacity)
                }
                #else
                BackdropBlurView(strength: opacity)
                #endif
            }
            if let tint, !glass.usesLiquidGlass {
                TintGlow(color: tint.color, cornerRadius: cornerRadius)
                    .opacity(GlassTint.opacity(forStrength: strength))
            }
        }
    }
}

/// A soft glow of the glass color in the same feathered shape as the blur.
private struct TintGlow: View {
    var color: Color
    var cornerRadius: CGFloat

    var body: some View {
        let spread = NotchStyle.haloSpread
        RoundedRectangle(cornerRadius: max(0, cornerRadius - spread * 0.6), style: .continuous)
            .fill(color)
            .padding(spread * 0.6)
            .blur(radius: spread * 0.35)
    }
}

// NSGlassEffectView is in the macOS 26 SDK, which comes with Swift 6.2, so
// older Command Line Tools still build the app, without Liquid Glass.
#if compiler(>=6.2)
@available(macOS 26, *)
private struct GlassBackdrop: NSViewRepresentable {
    var opacity: Double
    var cornerRadius: CGFloat
    var tint: NSColor?

    func makeNSView(context: Context) -> NSGlassEffectView {
        let view = NSGlassEffectView()
        apply(to: view)
        return view
    }

    func updateNSView(_ view: NSGlassEffectView, context: Context) {
        apply(to: view)
    }

    private func apply(to view: NSGlassEffectView) {
        view.style = .clear  // the most transparent of the two
        view.cornerRadius = cornerRadius
        view.tintColor = tint
        view.alphaValue = opacity
    }
}
#endif

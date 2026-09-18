import SwiftUI

/// Volume or brightness beside the notch: the symbol on the left of the camera
/// housing, the level on the right.
struct HUDView: View {
    let hud: NotchViewModel.HUD
    let size: CGSize
    let notchWidth: CGFloat

    var body: some View {
        let inset = NotchStyle.collapsedTopRadius
        let earWidth = (size.width - notchWidth) / 2 - inset
        let padding = NotchStyle.hudEdgePadding
        HStack(spacing: 0) {
            // Held at the outer edge, so a wider symbol grows toward the notch.
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .contentTransition(.symbolEffect(.replace))
                .padding(.leading, padding)
                .frame(width: earWidth, alignment: .leading)
            Spacer(minLength: 0)
            LevelBar(level: hud.isMuted ? 0 : Double(hud.level))
                .frame(width: earWidth - padding - NotchStyle.hudNotchGap, height: 6)
                .padding(.trailing, padding)
                .frame(width: earWidth, alignment: .trailing)
        }
        .padding(.horizontal, inset)
        .frame(width: size.width, height: size.height)
    }

    private var symbol: String {
        switch hud.kind {
        case .volume:
            if hud.isMuted || hud.level == 0 { return "speaker.slash.fill" }
            if hud.level < 0.34 { return "speaker.wave.1.fill" }
            return hud.level < 0.67 ? "speaker.wave.2.fill" : "speaker.wave.3.fill"
        case .brightness:
            return hud.level < 0.5 ? "sun.min.fill" : "sun.max.fill"
        }
    }
}

private struct LevelBar: View {
    let level: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.25))
                Capsule().fill(.white).frame(width: geometry.size.width * level)
            }
        }
        .animation(.spring(duration: 0.25, bounce: 0.1), value: level)
    }
}

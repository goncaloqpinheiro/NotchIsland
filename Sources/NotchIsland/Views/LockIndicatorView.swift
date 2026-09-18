import SwiftUI

/// A lock below the camera housing that moves into the ear on its left, and
/// whose shackle springs open on unlock. The icon is placed by position, so a
/// change of placement slides it along with the island's spring.
struct LockIndicatorView: View {
    let indicator: NotchViewModel.LockIndicator
    let size: CGSize
    let notchSize: CGSize

    var body: some View {
        Image(systemName: indicator.isUnlocked ? "lock.open.fill" : "lock.fill")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white)
            // Magic Replace morphs the shackle open rather than swapping images.
            .contentTransition(.symbolEffect(.replace.magic(fallback: .downUp.byLayer)))
            .symbolEffect(.bounce.up, value: indicator.isUnlocked)
            .frame(width: 24, height: 24)
            .position(iconCenter)
            .frame(width: size.width, height: size.height)
    }

    private var iconCenter: CGPoint {
        switch indicator.placement {
        case .center:
            return CGPoint(x: size.width / 2, y: notchSize.height + NotchStyle.lockIndicatorHeight / 2)
        case .leading:
            // The middle of the straight part of the left ear, past the top flare.
            let inset = NotchStyle.collapsedTopRadius
            return CGPoint(x: inset + (NotchStyle.lockEarWidth - inset) / 2, y: notchSize.height / 2)
        }
    }
}

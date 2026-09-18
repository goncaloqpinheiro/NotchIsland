import SwiftUI

extension CGSize {
    /// This size, grown to at least `minimum` in each direction.
    func atLeast(_ minimum: CGSize) -> CGSize {
        CGSize(width: Swift.max(width, minimum.width), height: Swift.max(height, minimum.height))
    }
}

extension View {
    /// Sizes the island, animating the size itself so a spring's overshoot never
    /// shrinks it past the camera housing. Without the floor, closing something
    /// tall (the open island, the lock, an AirPods card) undershoots by several
    /// points on the way to the notch, flashing the wallpaper around its edges.
    func islandSize(_ size: CGSize, atLeast minimum: CGSize) -> some View {
        modifier(IslandSize(size: size, minimum: minimum))
    }
}

private struct IslandSize: ViewModifier, Animatable {
    var size: CGSize
    /// Not animated: the island's floor stays put while the size springs to it.
    let minimum: CGSize

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(size.width, size.height) }
        set { size = CGSize(width: newValue.first, height: newValue.second) }
    }

    func body(content: Content) -> some View {
        let clamped = size.atLeast(minimum)
        return content.frame(width: clamped.width, height: clamped.height)
    }
}

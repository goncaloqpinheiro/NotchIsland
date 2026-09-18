import SwiftUI

extension AnyTransition {
    /// A content transition in the style of the Dynamic Island: content scales and un-blurs in
    /// from the camera housing as the island grows, and dissolves quickly as it shrinks.
    static var islandContent: AnyTransition {
        let effect = AnyTransition.modifier(active: IslandContentEffect(visible: false),
                                            identity: IslandContentEffect(visible: true))
        return .asymmetric(insertion: effect.animation(NotchStyle.contentIn),
                           removal: effect.animation(NotchStyle.contentOut))
    }
}

private struct IslandContentEffect: ViewModifier {
    let visible: Bool

    func body(content: Content) -> some View {
        content
            .scaleEffect(visible ? 1 : 0.85, anchor: .top)
            .blur(radius: visible ? 0 : 10)
            .opacity(visible ? 1 : 0)
    }
}

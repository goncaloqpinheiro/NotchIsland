import SwiftUI

/// The notch silhouette: flat top flush with the screen edge, concave "shoulders"
/// flaring into that edge, straight sides, and rounded bottom corners.
struct NotchShape: Shape {
    var topCornerRadius: CGFloat
    var bottomCornerRadius: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(topCornerRadius, bottomCornerRadius) }
        set {
            topCornerRadius = newValue.first
            bottomCornerRadius = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let top = max(0, min(topCornerRadius, rect.width / 4, rect.height / 2))
        let bottom = max(0, min(bottomCornerRadius, (rect.width - 2 * top) / 2, rect.height - top))

        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        // Top-left shoulder (concave).
        path.addQuadCurve(to: CGPoint(x: rect.minX + top, y: rect.minY + top),
                          control: CGPoint(x: rect.minX + top, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + top, y: rect.maxY - bottom))
        // Bottom-left corner.
        path.addQuadCurve(to: CGPoint(x: rect.minX + top + bottom, y: rect.maxY),
                          control: CGPoint(x: rect.minX + top, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX - top - bottom, y: rect.maxY))
        // Bottom-right corner.
        path.addQuadCurve(to: CGPoint(x: rect.maxX - top, y: rect.maxY - bottom),
                          control: CGPoint(x: rect.maxX - top, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX - top, y: rect.minY + top))
        // Top-right shoulder (concave).
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY),
                          control: CGPoint(x: rect.maxX - top, y: rect.minY))
        // Left open along the top: fills and clips close it implicitly, while a
        // stroke traces only the visible outline, not the screen edge.
        return path
    }
}

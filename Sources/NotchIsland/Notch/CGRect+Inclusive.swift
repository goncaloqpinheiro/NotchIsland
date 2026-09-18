import CoreGraphics

extension CGRect {
    /// Like `contains(_:)` but inclusive on every edge: the cursor can rest
    /// exactly on the screen's top edge, which `contains` treats as outside.
    func containsInclusive(_ point: CGPoint) -> Bool {
        point.x >= minX && point.x <= maxX && point.y >= minY && point.y <= maxY
    }
}

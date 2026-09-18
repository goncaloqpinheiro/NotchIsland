import SwiftUI

private struct RenderingSnapshotKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// True while `make snapshots` renders with ImageRenderer, which can't draw
    /// AppKit-backed views; those draw a still stand-in instead.
    var isRenderingSnapshot: Bool {
        get { self[RenderingSnapshotKey.self] }
        set { self[RenderingSnapshotKey.self] = newValue }
    }
}

private struct SnapshotTimeKey: EnvironmentKey {
    static let defaultValue: TimeInterval? = nil
}

extension EnvironmentValues {
    /// The moment a frame of the rendered demo shows (`make docs-demo`), so the
    /// parts that normally move outside SwiftUI (the audio bars, the AirPods
    /// movie) can move in it too. Nil everywhere else.
    var snapshotTime: TimeInterval? {
        get { self[SnapshotTimeKey.self] }
        set { self[SnapshotTimeKey.self] = newValue }
    }
}

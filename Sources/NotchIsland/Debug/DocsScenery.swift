import SwiftUI

/// An original gradient standing in for a desktop picture.
struct DocsWallpaper: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.10, green: 0.12, blue: 0.30),
                                    Color(red: 0.34, green: 0.19, blue: 0.48),
                                    Color(red: 0.86, green: 0.45, blue: 0.38)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            RadialGradient(colors: [Color(red: 1.0, green: 0.74, blue: 0.48).opacity(0.5), .clear],
                           center: .bottomTrailing, startRadius: 10, endRadius: 520)
        }
    }
}

/// A translucent menu bar with abstract items, so the island reads in place.
struct DocsMenuBar: View {
    let height: CGFloat
    let showsItems: Bool

    var body: some View {
        ZStack {
            Rectangle().fill(.black.opacity(0.22))
            if showsItems { items }
        }
        .frame(height: height)
    }

    private var items: some View {
        HStack(spacing: 16) {
            ForEach(Array([30, 44, 36, 40].enumerated()), id: \.offset) { _, width in
                Capsule().fill(.white.opacity(0.6)).frame(width: CGFloat(width), height: 6)
            }
            Spacer()
            ForEach(0..<3, id: \.self) { _ in
                Circle().fill(.white.opacity(0.6)).frame(width: 9, height: 9)
            }
            Capsule().fill(.white.opacity(0.6)).frame(width: 46, height: 6)
        }
        .padding(.horizontal, 18)
    }
}

/// The top of the screen behind the island: the wallpaper and the menu bar.
/// Also what adaptive glass is prepared from (see `SnapshotBackdrop.make`).
struct DocsBackground: View {
    let menuBarHeight: CGFloat
    let showsMenuItems: Bool

    var body: some View {
        ZStack(alignment: .top) {
            DocsWallpaper()
            DocsMenuBar(height: menuBarHeight, showsItems: showsMenuItems)
        }
    }
}

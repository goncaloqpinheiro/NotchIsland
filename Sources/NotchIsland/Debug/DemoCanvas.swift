import SwiftUI

/// The top of a Mac's screen with the island and the pointer, as in the
/// README's pictures.
struct DemoScreen: View {
    let stage: DemoStage
    let width: CGFloat
    let height: CGFloat
    /// What adaptive glass shows (see `SnapshotBackdrop.make`).
    let backdrop: SnapshotBackdrop?
    var showsWallpaper = true

    var body: some View {
        ZStack(alignment: .top) {
            if showsWallpaper {
                DocsWallpaper()
            }
            DocsMenuBar(height: stage.model.notchSize.height, showsItems: false)
            NotchRootView(model: stage.model, actions: NowPlayingActions())
                .environment(\.isRenderingSnapshot, true)
                .environment(\.snapshotTime, stage.time)
                .environment(\.snapshotBackdrop, backdrop)
                .frame(width: width, height: 300, alignment: .top)
            DemoPointer()
                .scaleEffect(stage.isClicking ? 0.85 : 1, anchor: .topLeading)
                .offset(x: stage.pointer.x + DemoPointer.size.width / 2, y: stage.pointer.y)
                .opacity(stage.showsPointer ? 1 : 0)
        }
        .frame(width: width, height: height, alignment: .top)
        .coordinateSpace(name: SnapshotBackdrop.space)
        .clipped()
    }

    /// Prepares the glass for a screen over the plain wallpaper.
    @MainActor
    static func backdrop(width: CGFloat, height: CGFloat, menuBarHeight: CGFloat) -> SnapshotBackdrop? {
        SnapshotBackdrop.make(size: CGSize(width: width, height: height)) {
            DocsBackground(menuBarHeight: menuBarHeight, showsMenuItems: false)
        }
    }
}

/// A 16:9 film for sharing: the screen at twice its size, with captions.
struct DemoFilm: View {
    static let size = CGSize(width: 960, height: 540)
    let stage: DemoStage
    let backdrop: SnapshotBackdrop?

    var body: some View {
        ZStack(alignment: .top) {
            Self.background
            DemoScreen(stage: stage, width: Self.size.width / 2, height: Self.size.height / 2, backdrop: backdrop,
                       showsWallpaper: false)
                .scaleEffect(2, anchor: .top)
            DemoCaptionView(caption: stage.caption)
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 52)
        }
        .frame(width: Self.size.width, height: Self.size.height)
    }

    private static var background: some View {
        ZStack {
            DocsWallpaper()
            LinearGradient(colors: [.clear, .black.opacity(0.28)], startPoint: .center, endPoint: .bottom)
        }
    }

    /// The glass for the screen, which shows the film's background at half size.
    @MainActor
    static func backdrop(menuBarHeight: CGFloat) -> SnapshotBackdrop? {
        SnapshotBackdrop.make(size: CGSize(width: size.width / 2, height: size.height / 2)) {
            ZStack(alignment: .top) {
                background
                    .frame(width: size.width, height: size.height)
                    .scaleEffect(0.5, anchor: .topLeading)
                    .frame(width: size.width / 2, height: size.height / 2, alignment: .topLeading)
                DocsMenuBar(height: menuBarHeight, showsItems: false)
            }
        }
    }
}

private struct DemoCaptionView: View {
    let caption: DemoCaption?

    var body: some View {
        ZStack {
            if let caption {
                VStack(spacing: 8) {
                    Text(caption.title)
                        .font(.system(size: 44, weight: .bold))
                    Text(caption.detail)
                        .font(.system(size: 23, weight: .medium))
                        .opacity(0.88)
                }
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .shadow(color: .black.opacity(0.3), radius: 14, y: 4)
                .id(caption)
                .transition(.opacity.combined(with: .offset(y: 10)))
            }
        }
    }
}

/// The classic arrow pointer, drawn rather than taken from the system so it
/// renders anywhere. Its tip is the top left corner.
struct DemoPointer: View {
    static let size = CGSize(width: 12, height: 19)

    var body: some View {
        let arrow = Path { path in
            path.addLines([
                CGPoint(x: 0, y: 0), CGPoint(x: 0, y: 16.5), CGPoint(x: 3.8, y: 12.9), CGPoint(x: 6.4, y: 18.6),
                CGPoint(x: 8.6, y: 17.7), CGPoint(x: 6.1, y: 12.1), CGPoint(x: 11.3, y: 12.1),
            ])
            path.closeSubpath()
        }
        ZStack(alignment: .topLeading) {
            arrow.stroke(.white, style: StrokeStyle(lineWidth: 2.2, lineJoin: .round))
            arrow.fill(.black)
        }
        .frame(width: Self.size.width, height: Self.size.height, alignment: .topLeading)
        .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
    }
}

import SwiftUI

/// Album art, with a music note while there's none. New covers fade in.
struct ArtworkView: View {
    let image: NSImage?
    let cornerRadius: CGFloat

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        GeometryReader { geometry in
            ZStack {
                shape.fill(.white.opacity(0.12))
                Image(systemName: "music.note")
                    .font(.system(size: geometry.size.height * 0.42, weight: .medium))
                    .foregroundStyle(.white.opacity(0.45))
                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .transition(.opacity)
                }
            }
        }
        .clipShape(shape)
        .animation(.easeInOut(duration: 0.3), value: image)
    }
}

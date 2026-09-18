import SwiftUI

/// The open island when nothing is playing.
struct NotPlayingView: View {
    let size: CGSize
    let notchHeight: CGFloat
    /// A source that couldn't be read because Automation access was denied.
    let deniedSource: MediaSource?
    let onOpenAutomationSettings: () -> Void

    var body: some View {
        Group {
            if let deniedSource {
                VStack(spacing: 6) {
                    Text("\(deniedSource.name) access needed")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                    Button("Open Automation Settings", action: onOpenAutomationSettings)
                        .buttonStyle(.plain)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.tint)
                }
            } else {
                Label("Not Playing", systemImage: "music.note")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.45))
            }
        }
        .padding(.top, notchHeight)
        .frame(width: size.width, height: size.height)
    }
}

import SwiftUI

/// The compact stopwatch, like the Dynamic Island's: an orange stopwatch on the
/// left of the camera housing, the time on the right. Dimmed while paused.
struct StopwatchActivityView: View {
    let stopwatch: StopwatchModel
    let size: CGSize
    let notchWidth: CGFloat

    var body: some View {
        let inset = NotchStyle.collapsedTopRadius
        let earWidth = (size.width - notchWidth) / 2 - inset
        HStack(spacing: 0) {
            Image(systemName: stopwatch.isPaused ? "pause.circle.fill" : "stopwatch")
                .font(.system(size: 14, weight: .semibold))
                .contentTransition(.symbolEffect(.replace))
                .frame(width: earWidth)
            Spacer(minLength: 0)
            ElapsedText(stopwatch: stopwatch)
                .font(.system(size: 14, weight: .semibold).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(width: earWidth)
        }
        .foregroundStyle(.orange)
        .opacity(stopwatch.isPaused ? 0.6 : 1)
        .padding(.horizontal, inset)
        .frame(width: size.width, height: size.height)
    }
}

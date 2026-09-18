import SwiftUI

/// The compact timer, like the Dynamic Island's: an orange timer on the left
/// of the camera housing, the countdown on the right. Dimmed while paused.
struct TimerActivityView: View {
    let timer: TimerModel
    let size: CGSize
    let notchWidth: CGFloat

    var body: some View {
        let inset = NotchStyle.collapsedTopRadius
        let earWidth = (size.width - notchWidth) / 2 - inset
        HStack(spacing: 0) {
            Image(systemName: timer.isPaused ? "pause.circle.fill" : "timer")
                .font(.system(size: 14, weight: .semibold))
                .contentTransition(.symbolEffect(.replace))
                .frame(width: earWidth)
            Spacer(minLength: 0)
            CountdownText(timer: timer)
                .font(.system(size: 14, weight: .semibold).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(width: earWidth)
        }
        .foregroundStyle(.orange)
        .opacity(timer.isPaused ? 0.6 : 1)
        .padding(.horizontal, inset)
        .frame(width: size.width, height: size.height)
    }
}

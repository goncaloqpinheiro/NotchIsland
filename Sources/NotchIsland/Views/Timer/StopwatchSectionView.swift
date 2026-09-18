import SwiftUI

/// The stopwatch expanded, laid out like the timer: stop (or start) and lap (or
/// reset) on the left, the time large on the right. Without the Clock shortcuts,
/// a single button opens Clock's stopwatch instead.
struct StopwatchSectionView: View {
    let stopwatch: StopwatchModel
    let actions: StopwatchActions

    var body: some View {
        HStack(spacing: 10) {
            if stopwatch.canToggle {
                CircleIconButton(symbol: stopwatch.isPaused ? "play.fill" : "pause.fill", tint: .orange,
                                 action: actions.toggle)
            }
            if stopwatch.canLapOrReset {
                CircleIconButton(symbol: stopwatch.isPaused ? "arrow.counterclockwise" : "flag.fill", tint: .white,
                                 action: actions.lapOrReset)
            }
            if !stopwatch.canToggle && !stopwatch.canLapOrReset {
                CircleIconButton(symbol: "stopwatch.fill", tint: .orange, action: actions.openClock)
            }
            Spacer(minLength: 12)
            VStack(alignment: .trailing, spacing: -3) {
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                ElapsedText(stopwatch: stopwatch)
                    .font(.system(size: 30, weight: .medium).monospacedDigit())
                    .lineLimit(1)
            }
            .foregroundStyle(.orange)
            .opacity(stopwatch.isPaused ? 0.65 : 1)
        }
        .padding(.horizontal, 22)
        .frame(height: NotchStyle.timerSectionHeight)
    }

    private var label: String {
        if stopwatch.isPaused { return "Paused" }
        return stopwatch.lapCount > 0 ? "Stopwatch · Lap \(stopwatch.lapCount + 1)" : "Stopwatch"
    }
}

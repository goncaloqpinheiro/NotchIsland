import SwiftUI

/// The timer expanded, laid out like the Dynamic Island's: pause and cancel on
/// the left, the countdown large on the right. When it reaches zero: a ringing
/// timer with Repeat and Stop. Without the Clock shortcuts, a single button
/// opens Clock instead.
struct TimerSectionView: View {
    let timer: TimerModel
    let actions: TimerActions

    var body: some View {
        HStack(spacing: 10) {
            if timer.isDone {
                RingingTimerIcon()
                VStack(alignment: .leading, spacing: 1) {
                    Text(timer.title ?? "Timer")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text("Done")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .padding(.leading, 2)
                Spacer(minLength: 12)
                if timer.canStart {
                    CircleIconButton(symbol: "arrow.clockwise", tint: .white, action: actions.repeatLast)
                }
                CircleIconButton(symbol: "xmark", tint: .orange, action: actions.stop)
            } else {
                if timer.canToggle {
                    CircleIconButton(symbol: timer.isPaused ? "play.fill" : "pause.fill", tint: .orange,
                                     action: timer.isPaused ? actions.resume : actions.pause)
                }
                if timer.canCancel {
                    CircleIconButton(symbol: "xmark", tint: .white, action: actions.cancel)
                }
                if !timer.canToggle && !timer.canCancel {
                    CircleIconButton(symbol: "clock.fill", tint: .orange, action: actions.openClock)
                }
                Spacer(minLength: 12)
                VStack(alignment: .trailing, spacing: -3) {
                    Text(timer.title ?? (timer.isPaused ? "Paused" : "Timer"))
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                    CountdownText(timer: timer)
                        .font(.system(size: 30, weight: .medium).monospacedDigit())
                        .lineLimit(1)
                }
                .foregroundStyle(.orange)
                .opacity(timer.isPaused ? 0.65 : 1)
            }
        }
        .padding(.horizontal, 22)
        .frame(height: NotchStyle.timerSectionHeight)
    }
}

/// A round, tinted icon button.
struct CircleIconButton: View {
    let symbol: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(tint)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 40, height: 40)
                .background(Circle().fill(tint.opacity(0.22)))
                .contentShape(Circle())
        }
        .buttonStyle(IslandPressStyle())
    }
}

private struct RingingTimerIcon: View {
    var body: some View {
        Image(systemName: "timer")
            .font(.system(size: 19, weight: .semibold))
            .foregroundStyle(.orange)
            .symbolEffect(.wiggle.byLayer, options: .repeating)
            .frame(width: 40, height: 40)
            .background(Circle().fill(.orange.opacity(0.22)))
    }
}

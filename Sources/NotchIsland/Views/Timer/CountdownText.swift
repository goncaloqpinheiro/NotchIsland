import SwiftUI

/// The time left, counting down while the timer runs. Redrawn once a second,
/// exactly when the shown second changes, and only while on screen.
struct CountdownText: View {
    let timer: TimerModel

    var body: some View {
        switch timer.phase {
        case .running(let endDate):
            TimelineView(.periodic(from: TimerFormat.countdownTick(endDate: endDate, now: .now), by: 1)) { context in
                Text(TimerFormat.clock(endDate.timeIntervalSince(context.date)))
            }
        case .paused(let remaining):
            Text(TimerFormat.clock(remaining))
        case .idle, .done:
            Text(TimerFormat.clock(0))
        }
    }
}

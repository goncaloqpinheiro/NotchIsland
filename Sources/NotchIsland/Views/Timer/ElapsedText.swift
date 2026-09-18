import SwiftUI

/// The time on the stopwatch in whole seconds, counting up while it runs.
/// Redrawn once a second, exactly when the shown second changes, and only while on screen.
struct ElapsedText: View {
    let stopwatch: StopwatchModel

    var body: some View {
        switch stopwatch.phase {
        case .running(let start):
            TimelineView(.periodic(from: start, by: 1)) { context in
                Text(TimerFormat.elapsed(context.date.timeIntervalSince(start)))
            }
        case .paused(let elapsed):
            Text(TimerFormat.elapsed(elapsed))
        case .idle:
            Text(TimerFormat.elapsed(0))
        }
    }
}

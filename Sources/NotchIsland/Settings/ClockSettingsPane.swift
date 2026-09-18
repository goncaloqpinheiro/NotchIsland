import SwiftUI

/// "Clock" tab: where the timers and stopwatch come from, and the optional
/// shortcuts that let the notch's buttons control them.
struct ClockSettingsPane: View {
    let timer: TimerModel
    let stopwatch: StopwatchModel
    let onCheckAgain: () -> Void

    var body: some View {
        Form {
            Section {
                LabeledContent("Timers and stopwatch from Clock") {
                    Button("Open Clock") { ClockApp.openTimers() }
                }
            } footer: {
                Text("Timers and the stopwatch you start in Clock, with Siri or from Control Center show in the notch like on iPhone. Clock rings when a timer ends.")
                    .foregroundStyle(.secondary)
            }

            Section("Timer Controls (Optional)") {
                ForEach(TimerCommand.allCases, id: \.self) { command in
                    status(command.shortcutName, isReady: timer.controls.contains(command))
                }
            }

            Section {
                ForEach(StopwatchCommand.allCases, id: \.self) { command in
                    status(command.shortcutName, isReady: stopwatch.controls.contains(command))
                }
                HStack {
                    Spacer()
                    Button("Check Again", action: onCheckAgain)
                    Button("Open Shortcuts") { ClockApp.openShortcuts() }
                }
            } header: {
                Text("Stopwatch Controls (Optional)")
            } footer: {
                Text("Only Clock can change its timers and stopwatch, so the notch's buttons use Clock's Shortcuts actions. In Shortcuts, create a shortcut for each name above, holding the Clock action with the same name (for example, “NotchIsland Pause Timer” holds Pause Timer). In NotchIsland Start Timer, click the duration, choose Shortcut Input, and set the unit to seconds. Without them the notch still shows everything, and its buttons open Clock.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 460, height: 700)
    }

    private func status(_ name: String, isReady: Bool) -> some View {
        LabeledContent(name) {
            if isReady {
                Label("Ready", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Label("Not Set Up", systemImage: "circle.dashed")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

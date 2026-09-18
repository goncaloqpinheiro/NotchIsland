import SwiftUI

/// "Indicators" tab: volume and brightness, AirPods and battery alerts, Focus, sounds.
struct IndicatorsSettingsPane: View {
    @Bindable var settings: AppSettings
    let model: NotchViewModel

    var body: some View {
        Form {
            Section {
                Toggle("Show volume and brightness in the notch", isOn: $settings.showsSystemHUD)
                if settings.showsSystemHUD && !model.isAccessibilityGranted {
                    LabeledContent("Needs Accessibility access") {
                        Button("Allow…") {
                            AccessibilityPermission.request()
                            AccessibilityPermission.openSettings()
                        }
                    }
                }
            } header: {
                Text("Volume and Brightness")
            } footer: {
                Text("Replaces the macOS volume and brightness indicator. Accessibility access lets NotchIsland handle those keys; no other keys are read.")
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle("AirPods and battery alerts", isOn: $settings.showsDeviceAlerts)
            } header: {
                Text("Alerts")
            } footer: {
                Text("AirPods connecting (with battery levels), the charger being plugged in or out, and low battery at 20% and 10%. AirPods need Bluetooth access.")
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle("Show Focus turning on and off", isOn: $settings.showsFocus)
                if settings.showsFocus && !model.isFocusAccessGranted {
                    LabeledContent("Full Disk Access is off") {
                        Button("Open Full Disk Access…", action: FullDiskAccess.openSettings)
                    }
                }
            } header: {
                Text("Focus")
            } footer: {
                Text("macOS keeps the Focus state in a protected folder, so NotchIsland needs Full Disk Access to see it. In Full Disk Access, turn on the switch next to NotchIsland (it's already in the list; if not, click + and choose it), then click Quit & Reopen. Only the Focus files are read.")
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle("Play sounds", isOn: $settings.playsSounds)
            } header: {
                Text("Sounds")
            } footer: {
                Text("Lock and unlock, AirPods connecting, low battery, and the iPhone's timer sound.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 460, height: 680)
    }
}

import SwiftUI

/// "Notch" tab: line the collapsed shape up with the camera housing, tune hover and the glass.
struct NotchSettingsPane: View {
    @Bindable var settings: AppSettings
    let model: NotchViewModel

    /// The last custom color, so switching away and back keeps it.
    @State private var lastTint: GlassTint?

    private enum GlassColor: Hashable {
        case natural, adaptive, custom
    }

    private var glassColor: Binding<GlassColor> {
        Binding(
            get: { settings.glassAdapts ? .adaptive : settings.glassTint != nil ? .custom : .natural },
            set: { choice in
                lastTint = settings.glassTint ?? lastTint
                settings.glassAdapts = choice == .adaptive
                settings.glassTint = choice == .custom ? lastTint ?? .starting : nil
            })
    }

    var body: some View {
        Form {
            Section {
                sizeRow("Width", offset: $settings.notchWidthOffset, in: -40...80, result: model.notchSize.width)
                sizeRow("Height", offset: $settings.notchHeightOffset, in: -12...24, result: model.notchSize.height)
                LabeledContent("Detected") {
                    HStack {
                        Text("\(Int(model.detectedNotchSize.width)) × \(Int(model.detectedNotchSize.height)) pt")
                            .monospacedDigit()
                        Button("Reset") { settings.resetNotchSize() }
                            .disabled(settings.notchWidthOffset == 0 && settings.notchHeightOffset == 0)
                    }
                }
            } header: {
                Text("Notch Size")
            } footer: {
                Text("While this window is open the notch shape has a red outline. Adjust until it just traces the edge of the camera housing.")
                    .foregroundStyle(.secondary)
            }

            Section("Hover") {
                LabeledContent("Open delay") {
                    HStack {
                        Slider(value: $settings.hoverDelay, in: 0...0.5, step: 0.05)
                        Text("\(Int((settings.hoverDelay * 1000).rounded())) ms")
                            .monospacedDigit()
                            .frame(width: 56, alignment: .trailing)
                    }
                }
                Toggle("Haptic feedback when opening", isOn: $settings.hapticsEnabled)
            }

            Section("Appearance") {
                Picker("Behind the island", selection: $settings.glass) {
                    ForEach(IslandGlass.allCases) { glass in
                        Text(glass.name).tag(glass)
                    }
                }
                LabeledContent("Strength") {
                    HStack {
                        Slider(value: $settings.blurStrength, in: 0...1)
                        Text(settings.blurStrength < 0.01 ? "Off" : "\(Int((settings.blurStrength * 100).rounded()))%")
                            .monospacedDigit()
                            .frame(width: 56, alignment: .trailing)
                    }
                }
                Picker("Glass color", selection: glassColor) {
                    Text("Adaptive").tag(GlassColor.adaptive)
                    Text("Natural").tag(GlassColor.natural)
                    Text("Custom").tag(GlassColor.custom)
                }
                if settings.glassAdapts && settings.glass != .liquid {
                    Text("Takes its color from whatever is behind the island.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                if let tint = settings.glassTint {
                    ColorPicker("Color", selection: Binding(get: { tint.color },
                                                            set: { settings.glassTint = GlassTint($0) }),
                                supportsOpacity: false)
                }
                Picker("Lock animation", selection: $settings.lockStyle) {
                    ForEach(LockStyle.allCases) { style in
                        Text(style.name).tag(style)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 460, height: 630)
    }

    private func sizeRow(_ title: String, offset: Binding<Double>, in range: ClosedRange<Double>,
                         result: CGFloat) -> some View {
        LabeledContent(title) {
            HStack {
                // Rounded in the binding rather than `step:`, which would draw a dense row of ticks.
                Slider(value: Binding(get: { offset.wrappedValue },
                                      set: { offset.wrappedValue = $0.rounded() }),
                       in: range)
                Stepper(title, value: offset, in: range, step: 1)
                    .labelsHidden()
                Text("\(Int(result)) pt")
                    .monospacedDigit()
                    .frame(width: 56, alignment: .trailing)
            }
        }
    }
}

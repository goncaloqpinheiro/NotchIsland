import SwiftUI

/// Charging, unplugged or low battery beside the notch, like the iPhone's
/// "Charging" activity: label on the left, level and battery on the right.
struct PowerAlertView: View {
    let alert: PowerAlert
    let size: CGSize
    let notchWidth: CGFloat

    var body: some View {
        let inset = NotchStyle.collapsedTopRadius
        let earWidth = (size.width - notchWidth) / 2 - inset
        HStack(spacing: 0) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(width: earWidth)
            Spacer(minLength: 0)
            HStack(spacing: 5) {
                Text("\(alert.level)%")
                    .font(.system(size: 12, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.white)
                BatteryGlyph(level: alert.level, tint: tint, isCharging: isCharging)
                    .frame(width: 25, height: 12)
            }
            .frame(width: earWidth)
        }
        .padding(.horizontal, inset)
        .frame(width: size.width, height: size.height)
    }

    private var title: String {
        switch alert {
        case .charging: "Charging"
        case .unplugged: "On Battery"
        case .low: "Low Battery"
        }
    }

    private var isCharging: Bool {
        if case .charging = alert { return true }
        return false
    }

    private var tint: Color {
        switch alert {
        case .charging: .green
        case .low: .red
        case .unplugged(let level): level <= 20 ? .red : .white
        }
    }
}

/// A battery outline filled to `level`, with a bolt while charging.
struct BatteryGlyph: View {
    let level: Int
    let tint: Color
    let isCharging: Bool

    var body: some View {
        GeometryReader { geometry in
            let bodyWidth = geometry.size.width - 3
            let height = geometry.size.height
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                    .strokeBorder(.white.opacity(0.4), lineWidth: 1)
                    .frame(width: bodyWidth, height: height)
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(tint)
                    .frame(width: max(2, (bodyWidth - 4) * CGFloat(min(max(level, 0), 100)) / 100), height: height - 4)
                    .padding(.leading, 2)
                RoundedRectangle(cornerRadius: 1)
                    .fill(.white.opacity(0.4))
                    .frame(width: 2, height: height * 0.4)
                    .offset(x: bodyWidth + 1)
                if isCharging {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: height * 0.72, weight: .bold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.6), radius: 1)
                        .frame(width: bodyWidth)
                }
            }
        }
    }
}

import SwiftUI

/// A Focus turning on or off, compact like the Dynamic Island: its symbol in
/// its color on the left of the camera housing, "On" or "Off" on the right.
struct FocusAlertView: View {
    let alert: FocusAlert
    let size: CGSize
    let notchWidth: CGFloat

    var body: some View {
        let inset = NotchStyle.collapsedTopRadius
        let earWidth = (size.width - notchWidth) / 2 - inset
        let tint = alert.isOn ? alert.mode.tint : .white.opacity(0.5)
        HStack(spacing: 0) {
            Image(systemName: alert.mode.symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tint)
                .symbolEffect(.bounce, options: .nonRepeating, value: alert)
                .frame(width: earWidth)
            Spacer(minLength: 0)
            Text(alert.isOn ? "On" : "Off")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(tint)
                .lineLimit(1)
                .frame(width: earWidth)
        }
        .padding(.horizontal, inset)
        .frame(width: size.width, height: size.height)
    }
}

extension FocusMode {
    /// The Focus's color, from a system color name like "systemIndigoColor".
    var tint: Color {
        switch tintName.replacingOccurrences(of: "system", with: "").replacingOccurrences(of: "Color", with: "").lowercased() {
        case "red": .red
        case "orange": .orange
        case "yellow": .yellow
        case "green": .green
        case "mint": .mint
        case "teal": .teal
        case "cyan": .cyan
        case "blue": .blue
        case "purple": .purple
        case "pink": .pink
        case "brown": .brown
        case "gray", "grey": .gray
        default: .indigo
        }
    }
}

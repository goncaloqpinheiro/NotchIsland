import SwiftUI

/// Headphones just connected. First a card below the notch (the model on the
/// left, name and batteries on the right), then, like the Dynamic Island, a
/// compact pill: the model shrinks into the left ear and a battery ring appears
/// in the right one. Everything is placed by position, so the model glides
/// from one layout to the other with the island's spring.
struct HeadphonesAlertView: View {
    let info: HeadphonesInfo
    let isCompact: Bool
    /// The island's size for the current layout.
    let size: CGSize
    let notchSize: CGSize

    private static let cardPadding: CGFloat = 18
    private static let cardModelSide: CGFloat = 80
    private static let cardSpacing: CGFloat = 14

    var body: some View {
        let inset = NotchStyle.collapsedTopRadius
        let earWidth = NotchStyle.headphonesCompactEarWidth - inset
        let card = NotchStyle.headphonesAlertSize(forNotch: notchSize)
        let cardMiddle = notchSize.height + (card.height - notchSize.height) / 2
        let detailsX = Self.cardPadding + Self.cardModelSide + Self.cardSpacing
        let detailsWidth = card.width - detailsX - Self.cardPadding

        ZStack(alignment: .topLeading) {
            // A little taller than the ear: the movie has transparent margins.
            HeadphonesAnimationView(info: info)
                .frame(width: isCompact ? notchSize.height + 2 : Self.cardModelSide,
                       height: isCompact ? notchSize.height + 2 : Self.cardModelSide)
                .position(isCompact
                          ? CGPoint(x: inset + earWidth / 2, y: notchSize.height / 2)
                          : CGPoint(x: Self.cardPadding + Self.cardModelSide / 2, y: cardMiddle))

            details
                .frame(width: detailsWidth, alignment: .leading)
                .scaleEffect(isCompact ? 0.8 : 1, anchor: .leading)
                .blur(radius: isCompact ? 6 : 0)
                .opacity(isCompact ? 0 : 1)
                .position(x: detailsX + detailsWidth / 2, y: cardMiddle)

            compactBattery
                .frame(width: earWidth)
                .opacity(isCompact ? 1 : 0)
                .position(x: size.width - inset - earWidth / 2, y: notchSize.height / 2)
        }
        .frame(width: size.width, height: size.height)
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(info.name)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
            if info.hasBatteryLevels {
                HStack(spacing: 12) {
                    battery("airpod.left", info.left)
                    battery("airpod.right", info.right)
                    battery(info.caseSymbol, info.chargingCase)
                    battery("headphones", info.single)
                }
                .transition(.opacity)
            } else {
                Text("Connected")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: info.hasBatteryLevels)
    }

    @ViewBuilder
    private func battery(_ symbol: String, _ level: Int?) -> some View {
        if let level {
            HStack(spacing: 4) {
                Image(systemName: symbol)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.75))
                Text("\(level)%")
                    .font(.system(size: 12, weight: .medium).monospacedDigit())
                    .foregroundStyle(level <= 20 ? Color.red : .white)
            }
        }
    }

    /// The Dynamic Island's battery ring, with the level beside it.
    @ViewBuilder
    private var compactBattery: some View {
        if let level = info.headlineLevel {
            HStack(spacing: 5) {
                Text("\(level)%")
                    .font(.system(size: 11, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.white)
                BatteryRing(level: level)
                    .frame(width: 14, height: 14)
            }
        } else {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14))
                .foregroundStyle(.green)
        }
    }
}

/// A circular battery gauge: green, or red at 20% and below.
struct BatteryRing: View {
    let level: Int

    var body: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.2), lineWidth: 2.5)
            Circle()
                .trim(from: 0, to: CGFloat(min(max(level, 0), 100)) / 100)
                .stroke(level <= 20 ? Color.red : .green, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}

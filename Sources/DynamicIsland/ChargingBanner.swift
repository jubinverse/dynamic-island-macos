import SwiftUI

struct ChargingInfo: Equatable, Identifiable {
    let id = UUID()
    let level: Int
    let minutesToFull: Int?

    var subtitle: String {
        if level >= 100 { return "Fully charged" }
        guard let minutes = minutesToFull else { return "Connected to power" }
        let hours = minutes / 60, rest = minutes % 60
        let time = hours > 0 ? (rest > 0 ? "\(hours) hr \(rest) min" : "\(hours) hr") : "\(rest) min"
        return "Full in \(time)"
    }

    static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
}

/// Drop-down shown when the charger is plugged in: a battery that fills to the current
/// level, a bolt that pops in, a soft green glow, and a percentage that counts up.
struct ChargingBanner: View {
    let info: ChargingInfo
    let notchHeight: CGFloat
    /// Snapshots render the finished state; the live island animates into it.
    var animated = true

    @State private var fill: CGFloat = 0
    @State private var shownLevel = 0
    @State private var boltVisible = false
    @State private var glowing = false

    private static let green = Color(red: 0.2, green: 0.84, blue: 0.4)

    var body: some View {
        HStack(spacing: 14) {
            AnimatedBattery(fill: fill, boltVisible: boltVisible, glowing: glowing, tint: Self.green)
                .frame(width: 52, height: 26)

            VStack(alignment: .leading, spacing: 2) {
                Text("Charging")
                    .font(Island.headline)
                    .foregroundStyle(Island.primary)
                Text(info.subtitle)
                    .font(Island.body)
                    .foregroundStyle(Island.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text("\(shownLevel)%")
                .font(.system(size: 26, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Self.green)
                .contentTransition(.numericText(value: Double(shownLevel)))
        }
        .padding(.top, notchHeight + 6)
        .padding(.bottom, 14)
        .onAppear(perform: start)
    }

    private func start() {
        let target = CGFloat(min(max(info.level, 0), 100)) / 100
        guard animated else {
            fill = target
            shownLevel = info.level
            boltVisible = true
            return
        }
        withAnimation(.easeOut(duration: 1.0).delay(0.2)) {
            fill = target
            shownLevel = info.level
        }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.5).delay(0.9)) {
            boltVisible = true
        }
        withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true).delay(1.0)) {
            glowing = true
        }
    }
}

/// Battery outline with an animated fill, terminal cap, lightning bolt and glow.
private struct AnimatedBattery: View {
    let fill: CGFloat
    let boltVisible: Bool
    let glowing: Bool
    let tint: Color

    var body: some View {
        GeometryReader { geo in
            let capWidth: CGFloat = 3
            let bodyWidth = geo.size.width - capWidth - 1
            let height = geo.size.height
            let inset: CGFloat = 3
            let innerWidth = bodyWidth - inset * 2

            ZStack(alignment: .leading) {
                // Glow behind the battery.
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(tint)
                    .frame(width: bodyWidth, height: height)
                    .blur(radius: 10)
                    .opacity(glowing ? 0.45 : 0.15)

                // Outline.
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.35), lineWidth: 2)
                    .frame(width: bodyWidth, height: height)

                // Terminal cap.
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color.white.opacity(0.35))
                    .frame(width: capWidth, height: height * 0.36)
                    .offset(x: bodyWidth + 1)

                // Charge fill.
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(LinearGradient(colors: [tint, tint.opacity(0.75)], startPoint: .top, endPoint: .bottom))
                    .frame(width: max(innerWidth * fill, fill > 0 ? 4 : 0), height: height - inset * 2)
                    .offset(x: inset)

                // Lightning bolt, centred on the battery body.
                Image(systemName: "bolt.fill")
                    .font(.system(size: height * 0.62, weight: .bold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.35), radius: 1.5)
                    .scaleEffect(boltVisible ? 1 : 0.2)
                    .opacity(boltVisible ? 1 : 0)
                    .frame(width: bodyWidth, height: height)
            }
        }
    }
}

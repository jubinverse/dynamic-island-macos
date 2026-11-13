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

/// Drop-down shown when the charger is plugged in: a circular charge ring that sweeps to the
/// current level with light travelling around it, a bolt that pops in and breathes, a soft
/// ripple, and a percentage that counts up.
struct ChargingBanner: View {
    let info: ChargingInfo
    let notchHeight: CGFloat
    /// Snapshots render the finished state; the live island animates into it.
    var animated = true

    @State private var progress: CGFloat = 0
    @State private var shownLevel = 0
    @State private var boltVisible = false
    @State private var pulsing = false

    private var tint: Color { info.level <= 10 ? Island.red : Island.green }

    var body: some View {
        HStack(spacing: 14) {
            ChargeRing(progress: progress, boltVisible: boltVisible, pulsing: pulsing,
                       animated: animated, tint: tint)
                .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(info.level >= 100 ? "Charged" : "Charging")
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
                .foregroundStyle(tint)
                .contentTransition(.numericText(value: Double(shownLevel)))
        }
        .padding(.top, notchHeight + 4)
        .padding(.bottom, 12)
        .onAppear(perform: start)
    }

    private func start() {
        let target = CGFloat(min(max(info.level, 0), 100)) / 100
        guard animated else {
            progress = target
            shownLevel = info.level
            boltVisible = true
            return
        }
        withAnimation(.easeOut(duration: 1.1).delay(0.15)) {
            progress = target
            shownLevel = info.level
        }
        withAnimation(.spring(response: 0.38, dampingFraction: 0.52).delay(0.35)) {
            boltVisible = true
        }
        withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true).delay(1.2)) {
            pulsing = true
        }
    }
}

/// Apple Watch–style charge ring: track, gradient arc with a glowing head, a highlight that
/// travels along the filled arc, an expanding ripple and a breathing bolt in the centre.
private struct ChargeRing: View {
    let progress: CGFloat
    let boltVisible: Bool
    let pulsing: Bool
    let animated: Bool
    let tint: Color

    private let lineWidth: CGFloat = 4.5

    var body: some View {
        ZStack {
            // Ripple radiating outward while charging.
            if animated {
                Ripple(tint: tint)
            }

            // Track.
            Circle()
                .stroke(Color.white.opacity(0.12), lineWidth: lineWidth)

            // Charge arc.
            Circle()
                .trim(from: 0, to: max(progress, 0.001))
                .stroke(
                    AngularGradient(colors: [tint.opacity(0.55), tint],
                                    center: .center,
                                    startAngle: .degrees(0),
                                    endAngle: .degrees(360 * max(Double(progress), 0.01))),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: tint.opacity(0.6), radius: pulsing ? 5 : 2)

            // Light travelling along the filled arc.
            if animated {
                TimelineView(.animation) { context in
                    let t = context.date.timeIntervalSinceReferenceDate
                    let phase = CGFloat(t.truncatingRemainder(dividingBy: 1.6) / 1.6)
                    let head = phase * progress
                    Circle()
                        .trim(from: max(head - 0.12, 0), to: head)
                        .stroke(
                            LinearGradient(colors: [.white.opacity(0), .white.opacity(0.75)],
                                           startPoint: .leading, endPoint: .trailing),
                            style: StrokeStyle(lineWidth: lineWidth - 1.5, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .opacity(progress > 0.05 ? 1 : 0)
                }
            }

            // Glowing head at the end of the arc.
            Circle()
                .fill(.white)
                .frame(width: lineWidth - 1, height: lineWidth - 1)
                .shadow(color: tint, radius: 3)
                .offset(y: -22)
                .rotationEffect(.degrees(360 * Double(progress)))
                .opacity(progress > 0.02 && progress < 1 ? 1 : 0)

            // Bolt.
            Image(systemName: "bolt.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(tint)
                .shadow(color: tint.opacity(pulsing ? 0.9 : 0.4), radius: pulsing ? 6 : 3)
                .scaleEffect(boltVisible ? (pulsing ? 1.08 : 1) : 0.2)
                .opacity(boltVisible ? 1 : 0)
        }
    }
}

/// Two staggered rings expanding out of the charge ring and fading away.
private struct Ripple: View {
    let tint: Color

    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            ZStack {
                ForEach(0..<2, id: \.self) { i in
                    let p = CGFloat(((t + Double(i) * 1.1) .truncatingRemainder(dividingBy: 2.2)) / 2.2)
                    Circle()
                        .stroke(tint.opacity(0.45 * (1 - p)), lineWidth: 1.5)
                        .scaleEffect(1 + p * 0.35)
                }
            }
        }
    }
}

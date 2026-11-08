import SwiftUI

/// Drop-down shown when AirPods connect: model, name, and a battery ring per bud and case.
struct AirPodsBanner: View {
    let info: AirPodsInfo
    let notchHeight: CGFloat

    var body: some View {
        HStack(spacing: Island.gap) {
            Image(systemName: info.symbol)
                .font(.system(size: 28, weight: .regular))
                .foregroundStyle(Island.primary)
                .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 2) {
                Text(info.name)
                    .font(Island.headline)
                    .foregroundStyle(Island.primary)
                    .lineLimit(1)
                Text("Connected")
                    .font(Island.body)
                    .foregroundStyle(Island.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 14) {
                if let left = info.left { BatteryRing(symbol: "airpod.left", level: left) }
                if let right = info.right { BatteryRing(symbol: "airpod.right", level: right) }
                if let caseLevel = info.caseLevel { BatteryRing(symbol: info.caseSymbol, level: caseLevel) }
                if info.left == nil, info.right == nil, let single = info.single {
                    BatteryRing(symbol: info.symbol, level: single)
                }
            }
        }
        .padding(.top, notchHeight + 6)
        .padding(.bottom, 14)
    }
}

/// Small circular battery gauge with the percentage underneath, like the iOS battery widget.
private struct BatteryRing: View {
    let symbol: String
    let level: Int

    private var color: Color {
        level <= 10 ? .red : level <= 20 ? .orange : .green
    }

    var body: some View {
        VStack(spacing: 3) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.15), lineWidth: 3)
                Circle()
                    .trim(from: 0, to: CGFloat(level) / 100)
                    .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Image(systemName: symbol)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Island.primary)
            }
            .frame(width: 28, height: 28)
            Text("\(level)%")
                .font(.system(size: 10, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(Island.secondary)
        }
    }
}

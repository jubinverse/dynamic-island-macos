import SwiftUI

/// One place for the island's type scale, colours, spacing and controls, so every page
/// shares the same rhythm. Values follow Apple's dark-material conventions.
enum Island {
    // Spacing (4-pt grid)
    static let inset: CGFloat = 20        // content inset from the island's straight edges
    static let gap: CGFloat = 12          // between related elements
    static let tightGap: CGFloat = 4      // between stacked lines of text
    static let rowGap: CGFloat = 4        // between list rows

    // Text colours on black
    static let primary = Color.white
    static let secondary = Color.white.opacity(0.6)
    static let tertiary = Color.white.opacity(0.38)
    static let fill = Color.white.opacity(0.08)
    static let fillHover = Color.white.opacity(0.14)

    // Type scale
    static let largeTitle = Font.system(size: 34, weight: .semibold, design: .rounded)
    static let title = Font.system(size: 15, weight: .semibold)
    static let headline = Font.system(size: 13, weight: .semibold)
    static let body = Font.system(size: 12)
    static let caption = Font.system(size: 11, weight: .medium)
}

/// Compact capsule button. `.filled` for the one primary action, `.tinted` for secondary ones.
struct IslandButton: View {
    enum Style { case filled, tinted }

    let title: String
    var tint: Color = .accentColor
    var style: Style = .tinted
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(style == .filled ? Color.white : tint)
                .padding(.horizontal, 12)
                .frame(height: 24)
                .background(Capsule().fill(style == .filled ? tint : tint.opacity(0.18)))
                .contentShape(Capsule())
        }
        .buttonStyle(PressScaleStyle())
    }
}

/// App-icon-style rounded square with a white SF Symbol.
struct IslandGlyph: View {
    let symbol: String
    let tint: Color
    var size: CGFloat = 48

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
            .fill(LinearGradient(colors: [tint, tint.opacity(0.72)], startPoint: .top, endPoint: .bottom))
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: symbol)
                    .font(.system(size: size * 0.42, weight: .medium))
                    .foregroundStyle(.white)
            )
    }
}

/// Apple-style status card: glyph, short title, one sentence, optional actions.
struct IslandMessageCard: View {
    let symbol: String
    let tint: Color
    let title: String
    let message: String
    var primary: (String, () -> Void)? = nil
    var secondary: (String, () -> Void)? = nil

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            IslandGlyph(symbol: symbol, tint: tint)

            VStack(alignment: .leading, spacing: Island.tightGap) {
                Text(title)
                    .font(Island.headline)
                    .foregroundStyle(Island.primary)
                    .lineLimit(1)
                Text(message)
                    .font(Island.body)
                    .foregroundStyle(Island.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 340, alignment: .leading)

                if primary != nil || secondary != nil {
                    HStack(spacing: 8) {
                        if let primary {
                            IslandButton(title: primary.0, style: .filled, action: primary.1)
                        }
                        if let secondary {
                            IslandButton(title: secondary.0, tint: .white, action: secondary.1)
                        }
                    }
                    .padding(.top, 6)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxHeight: .infinity)
    }
}

struct PressScaleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .opacity(configuration.isPressed ? 0.8 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

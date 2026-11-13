import SwiftUI

/// One place for the island's type scale, colours, spacing and controls, so every page
/// shares the same rhythm. Values follow Apple's dark-appearance system conventions.
enum Island {
    // Spacing (4-pt grid)
    static let inset: CGFloat = 20        // content inset from the island's straight edges
    static let gap: CGFloat = 12          // between related elements
    static let tightGap: CGFloat = 4      // between stacked lines of text
    static let rowGap: CGFloat = 4        // between list rows

    // Label colours on black (Apple's label / secondaryLabel / tertiaryLabel in dark mode)
    static let primary = Color.white
    static let secondary = Color.white.opacity(0.6)
    static let tertiary = Color.white.opacity(0.38)
    // Fills (Apple's quaternary → secondary system fills in dark mode)
    static let fill = Color.white.opacity(0.08)
    static let fillHover = Color.white.opacity(0.14)
    static let fillStrong = Color.white.opacity(0.2)

    // Apple system colours, dark appearance
    static let blue = Color(red: 10 / 255, green: 132 / 255, blue: 255 / 255)
    static let green = Color(red: 48 / 255, green: 209 / 255, blue: 88 / 255)
    static let red = Color(red: 255 / 255, green: 69 / 255, blue: 58 / 255)
    static let orange = Color(red: 255 / 255, green: 159 / 255, blue: 10 / 255)
    static let pink = Color(red: 255 / 255, green: 55 / 255, blue: 95 / 255)

    // Type scale
    static let largeTitle = Font.system(size: 34, weight: .semibold, design: .rounded)
    static let title = Font.system(size: 15, weight: .semibold)
    static let headline = Font.system(size: 13, weight: .semibold)
    static let body = Font.system(size: 12)
    static let caption = Font.system(size: 11, weight: .medium)
}

// MARK: - Buttons

/// The island's one text-button component, modelled on Apple's bordered button roles:
/// - `.prominent`: filled with the tint, white label. One per view, for the main action.
/// - `.gray`: neutral translucent fill, white label. Secondary actions.
/// - `.tinted`: light wash of the tint, tinted label. Contextual actions like "Join".
/// Like Apple's controls, buttons dim while pressed and brighten on hover; they don't scale.
struct IslandButton: View {
    enum Role { case prominent, gray, tinted }
    enum Size { case regular, small }

    let title: String
    var systemImage: String? = nil
    var role: Role = .gray
    var tint: Color = Island.blue
    var size: Size = .regular
    let action: () -> Void

    @State private var hovering = false

    private var height: CGFloat { size == .regular ? 28 : 24 }
    private var fontSize: CGFloat { size == .regular ? 13 : 12 }

    private var labelColor: Color {
        switch role {
        case .prominent, .gray: return .white
        case .tinted: return tint
        }
    }

    private var fillColor: Color {
        switch role {
        case .prominent: return tint
        case .gray: return hovering ? Island.fillStrong : Island.fillHover
        case .tinted: return tint.opacity(hovering ? 0.3 : 0.2)
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: fontSize - 1, weight: .semibold))
                        .imageScale(.small)
                }
                Text(title)
                    .font(.system(size: fontSize, weight: role == .prominent ? .semibold : .medium))
            }
            .foregroundStyle(labelColor)
            .padding(.horizontal, size == .regular ? 14 : 11)
            .frame(height: height)
            .background(
                Capsule()
                    .fill(fillColor)
                    // Prominent buttons brighten on hover, like macOS default buttons.
                    .overlay(Capsule().fill(Color.white.opacity(role == .prominent && hovering ? 0.12 : 0)))
            )
            .contentShape(Capsule())
            .animation(.easeOut(duration: 0.12), value: hovering)
        }
        .buttonStyle(IslandPressStyle())
        .onHover { hovering = $0 }
    }
}

/// Borderless circular icon button (media controls, settings). Shows a soft circle on hover.
struct IslandIconButton: View {
    let systemImage: String
    var size: CGFloat = 15
    var diameter: CGFloat = 32
    var color: Color = Island.primary
    var help: String? = nil
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: size, weight: .medium))
                .foregroundStyle(color)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: diameter, height: diameter)
                .background(Circle().fill(hovering ? Island.fillHover : .clear))
                .contentShape(Circle())
                .animation(.easeOut(duration: 0.12), value: hovering)
        }
        .buttonStyle(IslandPressStyle())
        .onHover { hovering = $0 }
        .help(help ?? "")
    }
}

/// Apple-style highlight: the control dims while held, with no bounce or scaling.
struct IslandPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.55 : 1)
            .animation(.easeOut(duration: configuration.isPressed ? 0.05 : 0.18), value: configuration.isPressed)
    }
}

// MARK: - Icons

/// App-icon-style rounded square with a white SF Symbol, like the tiles in System Settings:
/// a solid fill with a gentle top highlight and a hairline edge.
struct IslandGlyph: View {
    let symbol: String
    let tint: Color
    var size: CGFloat = 48

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: size * 0.225, style: .continuous)
        shape
            .fill(tint)
            .overlay(shape.fill(LinearGradient(colors: [.white.opacity(0.22), .white.opacity(0)],
                                               startPoint: .top, endPoint: .bottom)))
            .overlay(shape.strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5))
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: symbol)
                    .font(.system(size: size * 0.46, weight: .semibold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.15), radius: 1, y: 0.5)
            )
    }
}

// MARK: - Message card

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
                            IslandButton(title: primary.0, role: .prominent, size: .small, action: primary.1)
                        }
                        if let secondary {
                            IslandButton(title: secondary.0, role: .gray, size: .small, action: secondary.1)
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

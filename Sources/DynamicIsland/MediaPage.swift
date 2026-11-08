import SwiftUI

struct MediaPage: View {
    @ObservedObject var nowPlaying: NowPlayingMonitor

    private static let musicTint = Color(red: 0.98, green: 0.24, blue: 0.35)

    var body: some View {
        if nowPlaying.info.hasContent {
            MediaPlayer(nowPlaying: nowPlaying)
        } else if nowPlaying.helperMissing {
            IslandMessageCard(
                symbol: "music.note", tint: Self.musicTint,
                title: "Now Playing Unavailable",
                message: "The helper library wasn’t found. Build the app with build.sh."
            )
        } else {
            IslandMessageCard(
                symbol: "music.note", tint: Self.musicTint,
                title: "Nothing Playing",
                message: "Play something in Music, Spotify or your browser."
            )
        }
    }
}

private struct MediaPlayer: View {
    @ObservedObject var nowPlaying: NowPlayingMonitor

    private static let artworkSize: CGFloat = 100
    private var info: NowPlayingInfo { nowPlaying.info }

    var body: some View {
        HStack(spacing: 16) {
            Button(action: nowPlaying.openSourceApp) {
                ArtworkView(image: info.artwork, cornerRadius: 12)
                    .frame(width: Self.artworkSize, height: Self.artworkSize)
                    .overlay(alignment: .bottomTrailing) {
                        if let icon = info.sourceApp?.icon {
                            Image(nsImage: icon)
                                .resizable()
                                .frame(width: 24, height: 24)
                                .shadow(color: .black.opacity(0.4), radius: 2)
                                .offset(x: 5, y: 5)
                        }
                    }
                    .scaleEffect(info.isPlaying ? 1 : 0.94)
                    .animation(.spring(response: 0.35, dampingFraction: 0.7), value: info.isPlaying)
            }
            .buttonStyle(.plain)
            .help("Open \(info.sourceApp?.localizedName ?? "source app")")

            VStack(alignment: .leading, spacing: 0) {
                Text(info.title)
                    .font(Island.title)
                    .foregroundStyle(Island.primary)
                    .lineLimit(1)
                Text(info.artist.isEmpty ? (info.sourceApp?.localizedName ?? "") : info.artist)
                    .font(.system(size: 13))
                    .foregroundStyle(Island.secondary)
                    .lineLimit(1)
                    .padding(.top, 2)

                Spacer(minLength: 0)

                if info.duration > 0 {
                    ProgressRow(info: info)
                }

                Spacer(minLength: 0)

                HStack(spacing: 40) {
                    ControlButton(symbol: "backward.fill", size: 16) { nowPlaying.send(.previous) }
                    ControlButton(symbol: info.isPlaying ? "pause.fill" : "play.fill", size: 22) {
                        nowPlaying.send(.toggle)
                    }
                    ControlButton(symbol: "forward.fill", size: 16) { nowPlaying.send(.next) }
                }
                .frame(maxWidth: .infinity)
            }
            .frame(height: Self.artworkSize)
        }
        .frame(maxHeight: .infinity)
    }
}

private struct ProgressRow: View {
    let info: NowPlayingInfo

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { context in
            let elapsed = info.elapsed(at: context.date)
            let progress = info.duration > 0 ? min(max(elapsed / info.duration, 0), 1) : 0
            HStack(spacing: 10) {
                Text(format(elapsed))
                    .frame(width: 34, alignment: .leading)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.18))
                        Capsule()
                            .fill(Color.white.opacity(0.85))
                            .frame(width: geo.size.width * progress)
                    }
                }
                .frame(height: 4)
                Text("-" + format(max(info.duration - elapsed, 0)))
                    .frame(width: 38, alignment: .trailing)
            }
            .font(.system(size: 10, weight: .medium))
            .monospacedDigit()
            .foregroundStyle(Island.tertiary)
        }
    }

    private func format(_ seconds: Double) -> String {
        let s = Int(seconds.rounded(.down))
        return s >= 3600
            ? String(format: "%d:%02d:%02d", s / 3600, (s / 60) % 60, s % 60)
            : String(format: "%d:%02d", s / 60, s % 60)
    }
}

private struct ControlButton: View {
    let symbol: String
    let size: CGFloat
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size))
                .foregroundStyle(Island.primary)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 32, height: 28)
                .background(Circle().fill(Island.fill).opacity(hovering ? 1 : 0).frame(width: 34, height: 34))
                .contentShape(Rectangle())
        }
        .buttonStyle(PressScaleStyle())
        .onHover { hovering = $0 }
    }
}

struct ArtworkView: View {
    let image: NSImage?
    let cornerRadius: CGFloat

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                GeometryReader { geo in
                    LinearGradient(colors: [Color(white: 0.24), Color(white: 0.14)],
                                   startPoint: .top, endPoint: .bottom)
                        .overlay(
                            Image(systemName: "music.note")
                                .font(.system(size: min(geo.size.width, geo.size.height) * 0.4, weight: .medium))
                                .foregroundStyle(.white.opacity(0.45))
                        )
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

extension NSImage {
    /// Average colour of the image, brightened so it reads well on black. Cached per image.
    var averageColor: Color {
        if let cached = Self.colorCache.object(forKey: self) { return Color(nsColor: cached) }
        var result = NSColor.white
        if let cg = cgImage(forProposedRect: nil, context: nil, hints: nil) {
            var pixel = [UInt8](repeating: 0, count: 4)
            if let ctx = CGContext(data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                                   space: CGColorSpaceCreateDeviceRGB(),
                                   bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) {
                ctx.interpolationQuality = .medium
                ctx.draw(cg, in: CGRect(x: 0, y: 0, width: 1, height: 1))
                let color = NSColor(red: CGFloat(pixel[0]) / 255, green: CGFloat(pixel[1]) / 255,
                                    blue: CGFloat(pixel[2]) / 255, alpha: 1)
                var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
                color.usingColorSpace(.deviceRGB)?.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
                result = NSColor(hue: h, saturation: min(s * 1.2, 0.9), brightness: max(b, 0.75), alpha: 1)
            }
        }
        Self.colorCache.setObject(result, forKey: self)
        return Color(nsColor: result)
    }

    private static let colorCache = NSCache<NSImage, NSColor>()
}

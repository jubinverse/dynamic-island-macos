import SwiftUI

/// The drop-down banner shown when a notification arrives.
struct NotificationBanner: View {
    let item: IslandNotification
    let notchHeight: CGFloat
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Island.gap) {
                Image(nsImage: item.icon)
                    .resizable()
                    .frame(width: 38, height: 38)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(item.title.isEmpty ? item.appName : item.title)
                            .font(Island.headline)
                            .foregroundStyle(Island.primary)
                            .lineLimit(1)
                        Spacer(minLength: 8)
                        if !item.isCall {
                            Text("now")
                                .font(Island.caption)
                                .foregroundStyle(Island.tertiary)
                        }
                    }
                    Text(bodyText)
                        .font(Island.body)
                        .foregroundStyle(Island.secondary)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if item.isCall {
                    CallIndicator()
                }
            }
            .padding(.top, notchHeight + 6)
            .padding(.bottom, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Open \(item.appName)")
    }

    private var bodyText: String {
        let parts = [item.subtitle, item.body].filter { !$0.isEmpty }
        let text = parts.joined(separator: " · ")
        return item.title.isEmpty ? text : text.isEmpty ? item.appName : text
    }
}

/// Pulsing green phone for incoming calls.
private struct CallIndicator: View {
    @State private var pulse = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(Island.green.opacity(0.6), lineWidth: 2)
                .scaleEffect(pulse ? 1.5 : 1)
                .opacity(pulse ? 0 : 1)
            Circle()
                .fill(Island.green)
            Image(systemName: "phone.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: 36, height: 36)
        .onAppear {
            withAnimation(.easeOut(duration: 1.1).repeatForever(autoreverses: false)) { pulse = true }
        }
    }
}

/// The three most recent notifications.
struct NotificationsPage: View {
    @ObservedObject var monitor: NotificationMonitor

    /// Xcode runs the bare executable (no .app bundle) from DerivedData.
    static var isRunningFromXcode = Bundle.main.bundleURL.pathExtension != "app"

    var body: some View {
        switch monitor.access {
        case .granted:
            if monitor.recent.isEmpty {
                IslandMessageCard(
                    symbol: "bell.fill", tint: Island.red,
                    title: "No Notifications",
                    message: "Messages from WhatsApp, Slack, Claude and other apps will appear here."
                )
            } else {
                VStack(spacing: Island.rowGap) {
                    ForEach(monitor.recent.prefix(3)) { NotificationRow(item: $0) }
                }
                .frame(maxHeight: .infinity, alignment: .top)
            }
        case .needsFullDiskAccess:
            if Self.isRunningFromXcode {
                IslandMessageCard(
                    symbol: "bell.badge.fill", tint: Island.red,
                    title: "Notifications Unavailable",
                    message: "Apps run from Xcode can’t read notifications. Launch the built app instead."
                )
            } else {
                IslandMessageCard(
                    symbol: "bell.badge.fill", tint: Island.red,
                    title: "Show Notifications Here",
                    message: "Allow Full Disk Access so Dynamic Island can read Notification Center.",
                    primary: ("Open Settings", monitor.openFullDiskAccessSettings),
                    secondary: ("Show in Finder", {
                        NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL])
                    })
                )
            }
        case .unsupported:
            IslandMessageCard(
                symbol: "exclamationmark.triangle.fill", tint: Island.orange,
                title: "Notifications Unavailable",
                message: "This version of macOS stores notifications in a format Dynamic Island can’t read."
            )
        }
    }
}

private struct NotificationRow: View {
    let item: IslandNotification
    @State private var hovering = false

    var body: some View {
        Button(action: item.openApp) {
            HStack(spacing: 10) {
                Image(nsImage: item.icon)
                    .resizable()
                    .frame(width: 28, height: 28)
                VStack(alignment: .leading, spacing: 1) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        if item.isCall {
                            Image(systemName: "phone.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(.green)
                        }
                        Text(item.title.isEmpty ? item.appName : item.title)
                            .font(Island.headline)
                            .foregroundStyle(Island.primary)
                            .lineLimit(1)
                        Spacer(minLength: 8)
                        Text(item.date, format: .relative(presentation: .numeric, unitsStyle: .narrow))
                            .font(Island.caption)
                            .foregroundStyle(Island.tertiary)
                    }
                    Text([item.subtitle, item.body].filter { !$0.isEmpty }.joined(separator: " · "))
                        .font(Island.body)
                        .foregroundStyle(Island.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 8)
            .frame(height: 32)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(hovering ? Island.fill : .clear)
                .padding(.vertical, -2))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, -8) // hover highlight bleeds into the inset; content stays aligned
        .onHover { hovering = $0 }
    }
}

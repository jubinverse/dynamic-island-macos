import SwiftUI
import UniformTypeIdentifiers

struct NotchView: View {
    @ObservedObject var vm: NotchViewModel
    @ObservedObject var battery: BatteryMonitor
    @ObservedObject var nowPlaying: NowPlayingMonitor
    @ObservedObject var calendar: CalendarMonitor
    @ObservedObject var shelf: ShelfStore
    @ObservedObject var notifications: NotificationMonitor
    @ObservedObject var settings: AppSettings
    let onBannerTap: () -> Void

    @State private var isDropTargeted = false

    private var topRadius: CGFloat {
        if vm.isExpanded { return NotchViewModel.openTopRadius }
        return vm.isShowingBanner ? 10 : NotchViewModel.closedTopRadius
    }

    private var bottomRadius: CGFloat {
        if vm.isExpanded { return 26 }
        return vm.isShowingBanner ? 24 : 10
    }

    var body: some View {
        ZStack(alignment: .top) {
            NotchShape(topRadius: topRadius, bottomRadius: bottomRadius)
                .fill(Color.black)

            if vm.isExpanded {
                expandedContent
                    .padding(.horizontal, topRadius + Island.inset)
                    .transition(
                        .asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.85, anchor: .top))
                                .animation(.spring(response: 0.4, dampingFraction: 0.8).delay(0.06)),
                            removal: .opacity.animation(.easeOut(duration: 0.12))
                        )
                    )
            } else if let banner = vm.banner {
                NotificationBanner(item: banner, notchHeight: vm.notchSize.height, onTap: onBannerTap)
                    .padding(.horizontal, topRadius + 14)
                    .id(banner.id)
                    .transition(
                        .asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.8, anchor: .top))
                                .animation(.spring(response: 0.4, dampingFraction: 0.75).delay(0.05)),
                            removal: .opacity.animation(.easeOut(duration: 0.12))
                        )
                    )
            } else if let airPods = vm.airPods {
                AirPodsBanner(info: airPods, notchHeight: vm.notchSize.height)
                    .padding(.horizontal, topRadius + 14)
                    .contentShape(Rectangle())
                    .onTapGesture(perform: onBannerTap)
                    .id(airPods.id)
                    .transition(
                        .asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.8, anchor: .top))
                                .animation(.spring(response: 0.4, dampingFraction: 0.75).delay(0.05)),
                            removal: .opacity.animation(.easeOut(duration: 0.12))
                        )
                    )
            } else if vm.showsLiveActivity {
                ClosedActivityView(
                    activity: vm.activity,
                    info: nowPlaying.info,
                    wingWidth: vm.activityWingWidth,
                    height: vm.notchSize.height
                )
                .padding(.horizontal, NotchViewModel.closedTopRadius)
                .transition(.opacity.animation(.easeInOut(duration: 0.2)))
            }
        }
        .frame(width: vm.currentSize.width, height: vm.currentSize.height)
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted, perform: handleDrop)
        .shadow(color: .black.opacity(vm.isExpanded ? 0.45 : 0), radius: 14, y: 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(.spring(response: 0.42, dampingFraction: 0.78), value: vm.isExpanded)
        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: vm.activity)
        .animation(.spring(response: 0.45, dampingFraction: 0.72), value: vm.banner)
        .animation(.spring(response: 0.45, dampingFraction: 0.72), value: vm.airPods)
        .animation(.easeInOut(duration: 0.2), value: vm.notchSize)
    }

    private var expandedContent: some View {
        VStack(spacing: NotchViewModel.topRowSpacing) {
            // Top row sits either side of the camera housing.
            HStack(spacing: 10) {
                PageTabs(vm: vm)
                Spacer()
                if battery.hasBattery {
                    BatteryBadge(battery: battery)
                }
                Button {
                    SettingsWindowController.shared.show()
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Island.tertiary)
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Settings")
            }
            .frame(height: vm.notchSize.height)

            Group {
                switch vm.page {
                case .media: MediaPage(nowPlaying: nowPlaying)
                case .notifications: NotificationsPage(monitor: notifications)
                case .calendar: CalendarPage(calendar: calendar)
                case .shelf: ShelfPage(shelf: shelf, isDropTargeted: isDropTargeted)
                }
            }
            .id(vm.page)
            .frame(maxWidth: .infinity)
            .frame(height: NotchViewModel.pageContentHeight, alignment: .top)
            .transition(.opacity.combined(with: .scale(scale: 0.96)))
        }
        .padding(.bottom, NotchViewModel.expandedBottomPadding)
        .foregroundStyle(.white)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: vm.page)
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard settings.showShelfPage else { return false }
        var accepted = false
        for provider in providers where provider.canLoadObject(ofClass: URL.self) {
            accepted = true
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url else { return }
                DispatchQueue.main.async {
                    shelf.add([url])
                    vm.page = .shelf
                }
            }
        }
        return accepted
    }
}

// MARK: - Top bar

private struct PageTabs: View {
    @ObservedObject var vm: NotchViewModel

    var body: some View {
        if vm.availablePages.count > 1 {
            HStack(spacing: 2) {
                ForEach(vm.availablePages) { page in
                    Button {
                        vm.page = page
                    } label: {
                        Image(systemName: page.symbol)
                            .font(.system(size: 12, weight: .medium))
                            .frame(width: 30, height: 24)
                            .foregroundStyle(vm.page == page ? Island.primary : Island.tertiary)
                            .background(Capsule().fill(vm.page == page ? Island.fillHover : .clear))
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .help(page.title)
                }
            }
            .padding(2)
            .background(Capsule().fill(Island.fill))
        }
    }
}

private struct BatteryBadge: View {
    @ObservedObject var battery: BatteryMonitor

    private var symbol: String {
        if battery.isCharging { return "battery.100.bolt" }
        switch battery.level {
        case ..<13: return "battery.0"
        case ..<38: return "battery.25"
        case ..<63: return "battery.50"
        case ..<88: return "battery.75"
        default: return "battery.100"
        }
    }

    var body: some View {
        HStack(spacing: 5) {
            Text("\(battery.level)%")
                .font(Island.caption)
                .monospacedDigit()
                .foregroundStyle(Island.secondary)
            Image(systemName: symbol)
                .font(.system(size: 13))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(battery.isCharging ? Color.green : (battery.level < 20 ? Color.red : Island.secondary))
        }
    }
}

// MARK: - Closed state

/// Content of the side "wings" that appear around the closed notch.
private struct ClosedActivityView: View {
    let activity: LiveActivity
    let info: NowPlayingInfo
    let wingWidth: CGFloat
    let height: CGFloat

    var body: some View {
        HStack(spacing: 0) {
            leading.frame(width: wingWidth)
            Spacer(minLength: 0)
            trailing.frame(width: wingWidth)
        }
        .frame(height: height)
    }

    @ViewBuilder private var leading: some View {
        switch activity {
        case .media:
            ArtworkView(image: info.artwork, cornerRadius: 5)
                .frame(width: height - 14, height: height - 14)
        case .charging:
            Image(systemName: "bolt.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.green)
                .symbolEffect(.pulse)
        case .none:
            EmptyView()
        }
    }

    @ViewBuilder private var trailing: some View {
        switch activity {
        case .media:
            Waveform(isPlaying: info.isPlaying, color: info.artwork?.averageColor ?? .white)
                .frame(width: 18, height: height - 20)
        case .charging(let level):
            Text("\(level)%")
                .font(.system(size: 12, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(.green)
        case .none:
            EmptyView()
        }
    }
}

private struct Waveform: View {
    let isPlaying: Bool
    let color: Color

    var body: some View {
        TimelineView(.animation(paused: !isPlaying)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            HStack(alignment: .center, spacing: 2) {
                ForEach(0..<4, id: \.self) { i in
                    let phase = t * (5 + Double(i) * 1.7) + Double(i) * 1.3
                    let level = isPlaying ? 0.35 + 0.65 * abs(sin(phase)) : 0.2
                    Capsule()
                        .fill(color)
                        .frame(width: 2.5)
                        .scaleEffect(y: level, anchor: .center)
                }
            }
        }
    }
}

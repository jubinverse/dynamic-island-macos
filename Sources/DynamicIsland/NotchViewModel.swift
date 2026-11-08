import AppKit
import Combine

enum IslandPage: String, CaseIterable, Identifiable {
    case media, notifications, calendar, shelf
    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .media: return "music.note"
        case .notifications: return "bell.fill"
        case .calendar: return "calendar"
        case .shelf: return "tray.full"
        }
    }

    var title: String {
        switch self {
        case .media: return "Now Playing"
        case .notifications: return "Notifications"
        case .calendar: return "Calendar"
        case .shelf: return "Shelf"
        }
    }
}

/// What the closed island shows in its side "wings".
enum LiveActivity: Equatable {
    case none
    case media
    case charging(level: Int)
}

final class NotchViewModel: ObservableObject {
    @Published var isExpanded = false
    @Published var activity: LiveActivity = .none
    /// A notification currently dropping down from the notch, iPhone-style.
    @Published var banner: IslandNotification?
    /// AirPods that just connected, shown as a drop-down like a notification.
    @Published var airPods: AirPodsInfo?

    var isShowingBanner: Bool { banner != nil || airPods != nil }
    @Published var page: IslandPage = .media
    @Published var availablePages: [IslandPage] = IslandPage.allCases {
        didSet {
            if !availablePages.contains(page) { page = availablePages.first ?? .media }
        }
    }
    @Published private(set) var notchSize = CGSize(width: 190, height: 32)
    @Published private(set) var hasPhysicalNotch = false
    private(set) var screenFrame: CGRect = .zero

    static let closedTopRadius: CGFloat = 6
    static let openTopRadius: CGFloat = 14
    /// Height available to a page below the top row. Sized to the music player's artwork (104)
    /// plus a little room, so no page leaves a large empty band at the bottom.
    static let pageContentHeight: CGFloat = 104
    static let topRowSpacing: CGFloat = 10
    /// Matches the visual side margin of the open island.
    static let expandedBottomPadding: CGFloat = 20

    var openSize: CGSize {
        CGSize(
            width: 560,
            height: notchSize.height + Self.topRowSpacing + Self.pageContentHeight + Self.expandedBottomPadding
        )
    }

    var showsLiveActivity: Bool { activity != .none }

    /// Width added on each side of the notch while a live activity is showing.
    var activityWingWidth: CGFloat { notchSize.height + 10 }

    /// Closed island = the real notch plus the small outward "flares" at the top corners.
    var closedSize: CGSize {
        var width = notchSize.width + Self.closedTopRadius * 2
        if showsLiveActivity { width += activityWingWidth * 2 }
        return CGSize(width: width, height: notchSize.height)
    }

    var bannerSize: CGSize {
        CGSize(width: max(closedSize.width, 430), height: notchSize.height + 66)
    }

    var currentSize: CGSize {
        if isExpanded { return openSize }
        if isShowingBanner { return bannerSize }
        return closedSize
    }

    func showPage(offset: Int) {
        guard let index = availablePages.firstIndex(of: page) else { return }
        let next = index + offset
        guard availablePages.indices.contains(next) else { return }
        page = availablePages[next]
    }

    /// Used by snapshot mode to lay out without a real screen.
    func configurePreview(notchSize: CGSize) {
        self.notchSize = notchSize
        hasPhysicalNotch = true
    }

    func configure(for screen: NSScreen) {
        screenFrame = screen.frame
        let top = screen.safeAreaInsets.top
        if top > 0,
           let left = screen.auxiliaryTopLeftArea,
           let right = screen.auxiliaryTopRightArea {
            hasPhysicalNotch = true
            notchSize = CGSize(width: screen.frame.width - left.width - right.width, height: top)
        } else {
            // No notch (e.g. external display): draw a pill the height of the menu bar.
            hasPhysicalNotch = false
            let menuBarHeight = screen.frame.maxY - screen.visibleFrame.maxY
            notchSize = CGSize(width: 190, height: max(menuBarHeight, 24))
        }
    }
}

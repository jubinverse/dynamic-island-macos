import AppKit
import Combine
import SwiftUI

/// The panel is never key, so without this the first click on a button would be swallowed.
final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

/// Borderless, transparent panel that floats above the menu bar on every Space,
/// including over full-screen apps. It never takes focus from the app you're using.
final class NotchPanel: NSPanel {
    init() {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isMovable = false
        level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 3)
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        ignoresMouseEvents = true
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

final class NotchWindowController {
    /// The panel is a fixed canvas big enough for the expanded island; the island
    /// itself is drawn at the top-center and everything else is transparent.
    private static let canvasSize = CGSize(width: 700, height: 280)
    private static let chargingFlashDuration: TimeInterval = 3.5

    private let viewModel = NotchViewModel()
    private let battery = BatteryMonitor()
    private let nowPlaying = NowPlayingMonitor()
    private let calendar = CalendarMonitor()
    private let shelf = ShelfStore()
    private let notifications = NotificationMonitor()
    private let bluetooth = BluetoothMonitor()
    private let settings = AppSettings.shared
    private let panel = NotchPanel()

    private var eventMonitors: [Any] = []
    private var cancellables: Set<AnyCancellable> = []
    private var chargingFlashEnd: DispatchWorkItem?
    private var bannerDismiss: DispatchWorkItem?
    private var isChargingFlashActive = false

    // Mouse tracking state
    private var mouseDownInsideIsland = false
    private var dragPasteboardChangeCount = 0
    private var scrollAccumulator: CGFloat = 0
    private var scrollConsumed = false

    init() {
        panel.contentView = FirstMouseHostingView(
            rootView: NotchView(
                vm: viewModel, battery: battery, nowPlaying: nowPlaying,
                calendar: calendar, shelf: shelf, notifications: notifications, settings: settings,
                onBannerTap: { [weak self] in self?.openBanner() }
            )
        )
        reposition()
        panel.orderFrontRegardless()

        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main
        ) { [weak self] _ in self?.reposition() }

        bindState()
        installEventMonitors()
    }

    deinit {
        eventMonitors.forEach(NSEvent.removeMonitor)
    }

    // MARK: - State

    private func bindState() {
        nowPlaying.$info
            .map { $0.hasContent && $0.isPlaying }
            .removeDuplicates()
            .sink { [weak self] _ in DispatchQueue.main.async { self?.updateActivity() } }
            .store(in: &cancellables)

        // Charging flash when the charger is plugged in.
        battery.$isPluggedIn
            .removeDuplicates()
            .dropFirst()
            .filter { $0 }
            .sink { [weak self] _ in DispatchQueue.main.async { self?.flashCharging() } }
            .store(in: &cancellables)

        battery.$level
            .removeDuplicates()
            .sink { [weak self] _ in DispatchQueue.main.async { self?.updateActivity() } }
            .store(in: &cancellables)

        notifications.incoming
            .receive(on: DispatchQueue.main)
            .sink { [weak self] item in self?.showBanner(item) }
            .store(in: &cancellables)

        bluetooth.airPodsConnected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] info in self?.showAirPods(info) }
            .store(in: &cancellables)

        // objectWillChange fires before the new value is stored, so hop to the next runloop turn.
        settings.objectWillChange
            .sink { [weak self] _ in DispatchQueue.main.async { self?.applySettings() } }
            .store(in: &cancellables)
        applySettings()
    }

    private func applySettings() {
        var pages: [IslandPage] = [.media]
        if settings.showNotifications { pages.append(.notifications) }
        if settings.showCalendarPage { pages.append(.calendar) }
        if settings.showShelfPage { pages.append(.shelf) }
        if viewModel.availablePages != pages { viewModel.availablePages = pages }
        updateActivity()
    }

    private func flashCharging() {
        guard settings.showChargingAnimation else { return }
        isChargingFlashActive = true
        updateActivity()
        chargingFlashEnd?.cancel()
        let end = DispatchWorkItem { [weak self] in
            self?.isChargingFlashActive = false
            self?.updateActivity()
        }
        chargingFlashEnd = end
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.chargingFlashDuration, execute: end)
    }

    // MARK: - Notification banners

    private func showBanner(_ item: IslandNotification) {
        // While the island is open, the notification just lands in the Notifications page.
        guard settings.showNotifications, !viewModel.isExpanded else { return }
        viewModel.airPods = nil
        viewModel.banner = item
        scheduleBannerDismiss(after: item.isCall ? 25 : 6)
    }

    private func showAirPods(_ info: AirPodsInfo) {
        guard settings.showAirPods, !viewModel.isExpanded else { return }
        viewModel.banner = nil
        viewModel.airPods = info
        scheduleBannerDismiss(after: 4)
    }

    private func scheduleBannerDismiss(after seconds: TimeInterval) {
        bannerDismiss?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            // Don't pull the banner away while the pointer is resting on it.
            if self.islandRect.contains(NSEvent.mouseLocation) {
                self.scheduleBannerDismiss(after: 2)
            } else {
                self.viewModel.banner = nil
                self.viewModel.airPods = nil
            }
        }
        bannerDismiss = work
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work)
    }

    private func openBanner() {
        viewModel.banner?.openApp()
        bannerDismiss?.cancel()
        viewModel.banner = nil
        viewModel.airPods = nil
    }

    private func updateActivity() {
        let next: LiveActivity
        if isChargingFlashActive {
            next = .charging(level: battery.level)
        } else if settings.showMediaActivity, nowPlaying.info.hasContent, nowPlaying.info.isPlaying {
            next = .media
        } else {
            next = .none
        }
        if viewModel.activity != next { viewModel.activity = next }
    }

    // MARK: - Window placement

    /// Prefer the built-in display (the one with a notch); fall back to the main screen.
    private var targetScreen: NSScreen? {
        NSScreen.screens.first { $0.safeAreaInsets.top > 0 } ?? NSScreen.main
    }

    private func reposition() {
        guard let screen = targetScreen else { return }
        viewModel.configure(for: screen)
        let size = Self.canvasSize
        let origin = CGPoint(x: screen.frame.midX - size.width / 2, y: screen.frame.maxY - size.height)
        panel.setFrame(CGRect(origin: origin, size: size), display: true)
    }

    // MARK: - Mouse

    private func installEventMonitors() {
        // Mouse monitors don't need Accessibility permission.
        let mouse: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .leftMouseDown, .leftMouseUp]
        if let global = NSEvent.addGlobalMonitorForEvents(matching: mouse, handler: { [weak self] event in
            self?.handleMouse(event)
        }) { eventMonitors.append(global) }

        if let local = NSEvent.addLocalMonitorForEvents(matching: mouse.union(.scrollWheel), handler: { [weak self] event in
            if event.type == .scrollWheel {
                self?.handleScroll(event)
            } else {
                self?.handleMouse(event)
            }
            return event
        }) { eventMonitors.append(local) }
    }

    private var islandRect: CGRect {
        let screenFrame = viewModel.screenFrame
        let size = viewModel.currentSize
        var rect = CGRect(
            x: screenFrame.midX - size.width / 2,
            y: screenFrame.maxY - size.height,
            width: size.width,
            height: size.height + 1 // include the very top pixel row
        )
        // Give the closed notch a slightly larger hit area so it's easy to trigger.
        if !viewModel.isExpanded {
            rect = rect.insetBy(dx: -12, dy: -8)
        }
        return rect
    }

    private func handleMouse(_ event: NSEvent) {
        let location = NSEvent.mouseLocation
        let inside = islandRect.contains(location)
        let dragPasteboard = NSPasteboard(name: .drag)

        switch event.type {
        case .leftMouseDown:
            mouseDownInsideIsland = inside
            dragPasteboardChangeCount = dragPasteboard.changeCount
        case .leftMouseUp:
            mouseDownInsideIsland = false
        default:
            break
        }

        // While a banner is showing, make it clickable instead of expanding over it.
        if viewModel.isShowingBanner, !viewModel.isExpanded {
            panel.ignoresMouseEvents = !inside
            return
        }

        // A file drag from Finder etc. has written new file URLs to the drag pasteboard.
        let isDraggingFiles = event.type == .leftMouseDragged
            && dragPasteboard.changeCount != dragPasteboardChangeCount
            && (dragPasteboard.types?.contains(.fileURL) ?? false)

        // Keep the island open while dragging something out of it (e.g. a shelf file).
        let holdOpen = viewModel.isExpanded && mouseDownInsideIsland
            && (NSEvent.pressedMouseButtons & 1) != 0

        let shouldExpand = inside || holdOpen
        panel.ignoresMouseEvents = !shouldExpand

        if shouldExpand != viewModel.isExpanded {
            if shouldExpand, isDraggingFiles, viewModel.availablePages.contains(.shelf) {
                viewModel.page = .shelf
            }
            viewModel.isExpanded = shouldExpand
            if shouldExpand {
                NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
                calendar.reload()
                shelf.pruneMissing()
            }
        }
    }

    /// Two-finger horizontal swipe on the trackpad switches pages.
    private func handleScroll(_ event: NSEvent) {
        guard viewModel.isExpanded, event.window === panel, event.momentumPhase.isEmpty else { return }
        if event.phase == .began {
            scrollAccumulator = 0
            scrollConsumed = false
        }
        guard !scrollConsumed, abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY) else { return }

        scrollAccumulator += event.scrollingDeltaX
        if abs(scrollAccumulator) > 40 {
            viewModel.showPage(offset: scrollAccumulator < 0 ? 1 : -1)
            scrollConsumed = true
        }
        if event.phase == .ended || event.phase == .cancelled {
            scrollAccumulator = 0
            scrollConsumed = false
        }
    }
}

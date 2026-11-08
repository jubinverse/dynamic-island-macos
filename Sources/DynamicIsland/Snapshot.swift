import AppKit
import SwiftUI

/// `DynamicIsland --snapshot <dir>` renders each island state to PNGs with sample data,
/// for reviewing layout without screen recording. Not used in normal runs.
enum SnapshotRenderer {
    @MainActor
    static func run(outputDirectory: String) {
        let dir = URL(fileURLWithPath: outputDirectory, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let notch = CGSize(width: 209, height: 38) // MacBook Air 13" notch
        let battery = BatteryMonitor()
        let shelf = ShelfStore()
        let settings = AppSettings.shared

        let artwork = sampleArtwork()
        var playing = NowPlayingInfo()
        playing.title = "Midnight Drive"
        playing.artist = "Sample Artist"
        playing.duration = 256
        playing.elapsed = 74
        playing.isPlaying = false
        playing.artwork = artwork

        let now = Date()
        let whatsapp = sampleNotification(id: 1, app: "WhatsApp", bundle: "net.whatsapp.WhatsApp",
                                          title: "Arun", body: "Are we still on for dinner tonight?", ago: 60)
        let slack = sampleNotification(id: 2, app: "Slack", bundle: "com.google.Chrome",
                                       title: "#design", body: "Maya: New mockups are up in Figma 🎨", ago: 600)
        let claude = sampleNotification(id: 3, app: "Claude", bundle: "com.anthropic.claudefordesktop",
                                        title: "Claude", body: "Your research summary is ready.", ago: 3600)
        let call = sampleNotification(id: 4, app: "WhatsApp", bundle: "net.whatsapp.WhatsApp",
                                      title: "Amma", body: "Incoming voice call", ago: 0, isCall: true)

        let events = [
            UpcomingEvent(id: "1", title: "Design review", start: now.addingTimeInterval(-600),
                          end: now.addingTimeInterval(1800), isAllDay: false, color: .systemPurple,
                          meetingURL: URL(string: "https://meet.google.com/abc")),
            UpcomingEvent(id: "2", title: "1:1 with Priya", start: now.addingTimeInterval(1800 + 900),
                          end: now.addingTimeInterval(1800 + 2700), isAllDay: false, color: .systemBlue,
                          meetingURL: URL(string: "https://zoom.us/j/1")),
            UpcomingEvent(id: "3", title: "Gym", start: now.addingTimeInterval(4 * 3600),
                          end: now.addingTimeInterval(5 * 3600), isAllDay: false, color: .systemGreen,
                          meetingURL: nil),
        ]

        struct Shot {
            let name: String
            let page: IslandPage?
            let banner: IslandNotification?
            let activity: LiveActivity
            let nowPlaying: NowPlayingMonitor
            let notifications: NotificationMonitor
            let calendar: CalendarMonitor
        }

        let idleNotifications = NotificationMonitor(previewAccess: .granted, recent: [])
        let idleCalendar = CalendarMonitor(previewAccess: .granted, events: [])
        let playingMonitor = NowPlayingMonitor(preview: playing)
        let shots: [Shot] = [
            Shot(name: "1-media", page: .media, banner: nil, activity: .none,
                 nowPlaying: playingMonitor, notifications: idleNotifications, calendar: idleCalendar),
            Shot(name: "2-media-empty", page: .media, banner: nil, activity: .none,
                 nowPlaying: NowPlayingMonitor(preview: NowPlayingInfo()), notifications: idleNotifications, calendar: idleCalendar),
            Shot(name: "3-notifications-access", page: .notifications, banner: nil, activity: .none,
                 nowPlaying: playingMonitor,
                 notifications: NotificationMonitor(previewAccess: .needsFullDiskAccess, recent: []),
                 calendar: idleCalendar),
            Shot(name: "4-notifications-list", page: .notifications, banner: nil, activity: .none,
                 nowPlaying: playingMonitor,
                 notifications: NotificationMonitor(previewAccess: .granted, recent: [whatsapp, slack, claude]),
                 calendar: idleCalendar),
            Shot(name: "5-calendar", page: .calendar, banner: nil, activity: .none,
                 nowPlaying: playingMonitor, notifications: idleNotifications,
                 calendar: CalendarMonitor(previewAccess: .granted, events: events)),
            Shot(name: "6-shelf-empty", page: .shelf, banner: nil, activity: .none,
                 nowPlaying: playingMonitor, notifications: idleNotifications, calendar: idleCalendar),
            Shot(name: "7-banner", page: nil, banner: whatsapp, activity: .none,
                 nowPlaying: playingMonitor, notifications: idleNotifications, calendar: idleCalendar),
            Shot(name: "8-banner-call", page: nil, banner: call, activity: .none,
                 nowPlaying: playingMonitor, notifications: idleNotifications, calendar: idleCalendar),
            Shot(name: "9-closed-media", page: nil, banner: nil, activity: .media,
                 nowPlaying: playingMonitor, notifications: idleNotifications, calendar: idleCalendar),
        ]

        // Charging banner
        do {
            let vm = NotchViewModel()
            vm.configurePreview(notchSize: notch)
            vm.isSnapshot = true
            vm.charging = ChargingInfo(level: 82, minutesToFull: 38)
            render(NotchView(vm: vm, battery: battery, nowPlaying: playingMonitor, calendar: idleCalendar,
                             shelf: shelf, notifications: idleNotifications, settings: settings, onBannerTap: {}),
                   to: dir.appendingPathComponent("11-charging.png"))
        }

        // AirPods connect banner
        do {
            let vm = NotchViewModel()
            vm.configurePreview(notchSize: notch)
            vm.airPods = AirPodsInfo(name: "AirPods Pro", model: .airpodsPro,
                                     left: 100, right: 96, caseLevel: 83, single: nil)
            render(NotchView(vm: vm, battery: battery, nowPlaying: playingMonitor, calendar: idleCalendar,
                             shelf: shelf, notifications: idleNotifications, settings: settings, onBannerTap: {}),
                   to: dir.appendingPathComponent("10-airpods.png"))
        }

        for shot in shots {
            let vm = NotchViewModel()
            vm.configurePreview(notchSize: notch)
            vm.availablePages = [.media, .notifications, .calendar, .shelf]
            if let page = shot.page {
                vm.page = page
                vm.isExpanded = true
            }
            vm.banner = shot.banner
            vm.activity = shot.activity

            render(NotchView(
                vm: vm, battery: battery, nowPlaying: shot.nowPlaying, calendar: shot.calendar,
                shelf: shelf, notifications: shot.notifications, settings: settings, onBannerTap: {}
            ), to: dir.appendingPathComponent("\(shot.name).png"))
        }
        print("Snapshots written to \(dir.path)")
    }

    @MainActor
    private static func render(_ notch: NotchView, to url: URL) {
        let view = notch
            .frame(width: 700, height: 250, alignment: .top)
            .background(Color(red: 0.25, green: 0.3, blue: 0.75)) // stand-in wallpaper
            .environment(\.colorScheme, .dark)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        guard let image = renderer.nsImage,
              let tiff = image.tiffRepresentation,
              let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:])
        else { return }
        try? png.write(to: url)
    }

    private static func sampleNotification(id: Int64, app: String, bundle: String, title: String,
                                           body: String, ago: TimeInterval, isCall: Bool = false) -> IslandNotification {
        let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundle)
        let icon = url.map { NSWorkspace.shared.icon(forFile: $0.path) } ?? NSImage()
        return IslandNotification(id: id, bundleID: bundle, appName: app, title: title, subtitle: "",
                                  body: body, date: Date().addingTimeInterval(-ago), isCall: isCall,
                                  icon: icon, appURL: url)
    }

    private static func sampleArtwork() -> NSImage {
        let size = NSSize(width: 300, height: 300)
        let image = NSImage(size: size)
        image.lockFocus()
        NSGradient(colors: [.systemTeal, .systemIndigo])?.draw(in: NSRect(origin: .zero, size: size), angle: -60)
        image.unlockFocus()
        return image
    }
}

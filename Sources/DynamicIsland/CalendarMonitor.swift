import AppKit
import EventKit

struct UpcomingEvent: Identifiable, Equatable {
    let id: String
    let title: String
    let start: Date
    let end: Date
    let isAllDay: Bool
    let color: NSColor
    let meetingURL: URL?

    var isHappeningNow: Bool { start <= Date() && end > Date() }
}

/// Today's and tomorrow's upcoming events from the macOS Calendar database.
final class CalendarMonitor: ObservableObject {
    enum Access { case unknown, granted, denied, unavailable }

    @Published private(set) var access: Access = .unknown
    @Published private(set) var events: [UpcomingEvent] = []

    private let store = EKEventStore()
    private var timer: Timer?

    /// Requesting access without a usage description in Info.plist would crash the app,
    /// which is what happens when it's run as a bare executable from Xcode.
    var canRequestAccess: Bool {
        Bundle.main.object(forInfoDictionaryKey: "NSCalendarsFullAccessUsageDescription") != nil
    }

    init() {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess: access = .granted
        case .denied, .restricted, .writeOnly: access = .denied
        default: access = canRequestAccess ? .unknown : .unavailable
        }

        NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged, object: store, queue: .main
        ) { [weak self] _ in self?.reload() }

        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in self?.reload() }
        reload()
    }

    /// Static instance for snapshots; doesn't read the calendar.
    init(previewAccess: Access, events: [UpcomingEvent]) {
        access = previewAccess
        self.events = events
    }

    func requestAccess() {
        guard canRequestAccess else { return }
        store.requestFullAccessToEvents { [weak self] granted, _ in
            DispatchQueue.main.async {
                self?.access = granted ? .granted : .denied
                self?.reload()
            }
        }
    }

    func openPrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
            NSWorkspace.shared.open(url)
        }
    }

    func reload() {
        guard access == .granted else { return }
        let now = Date()
        let calendar = Calendar.current
        let end = calendar.date(byAdding: .day, value: 2, to: calendar.startOfDay(for: now))!
        let predicate = store.predicateForEvents(withStart: now, end: end, calendars: nil)

        events = store.events(matching: predicate)
            .filter { !$0.isAllDay && $0.endDate > now && $0.status != .canceled }
            .sorted { $0.startDate < $1.startDate }
            .prefix(3)
            .map { event in
                UpcomingEvent(
                    id: event.eventIdentifier ?? UUID().uuidString,
                    title: event.title ?? "Untitled",
                    start: event.startDate,
                    end: event.endDate,
                    isAllDay: event.isAllDay,
                    color: event.calendar.color ?? .systemBlue,
                    meetingURL: Self.meetingURL(in: event)
                )
            }
    }

    /// Finds a Zoom / Meet / Teams / Webex link in the event's URL, location or notes.
    private static func meetingURL(in event: EKEvent) -> URL? {
        let hosts = ["zoom.us", "meet.google.com", "teams.microsoft.com", "teams.live.com", "webex.com", "facetime.apple.com"]
        if let url = event.url, hosts.contains(where: { url.host?.hasSuffix($0) == true }) {
            return url
        }
        let text = [event.location, event.notes].compactMap { $0 }.joined(separator: "\n")
        guard !text.isEmpty,
              let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        else { return nil }
        let matches = detector.matches(in: text, range: NSRange(text.startIndex..., in: text))
        return matches.compactMap(\.url).first { url in
            hosts.contains { url.host?.hasSuffix($0) == true }
        }
    }
}

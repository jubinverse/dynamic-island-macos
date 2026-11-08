import SwiftUI

struct CalendarPage: View {
    @ObservedObject var calendar: CalendarMonitor

    var body: some View {
        switch calendar.access {
        case .granted:
            HStack(alignment: .center, spacing: 28) {
                clock
                events
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: .infinity)
        case .unknown:
            IslandMessageCard(
                symbol: "calendar", tint: .red,
                title: "See Your Next Meetings",
                message: "Upcoming events with a Join button for Zoom, Meet and Teams.",
                primary: ("Allow Access", {
                    NSApp.activate(ignoringOtherApps: true)
                    calendar.requestAccess()
                })
            )
        case .denied:
            IslandMessageCard(
                symbol: "calendar", tint: .red,
                title: "Calendar Access Is Off",
                message: "Turn on Calendars for Dynamic Island in Privacy & Security.",
                primary: ("Open Settings", calendar.openPrivacySettings)
            )
        case .unavailable:
            IslandMessageCard(
                symbol: "calendar", tint: .red,
                title: "Calendar Unavailable",
                message: "Apps run from Xcode can’t access Calendar. Launch the built app instead."
            )
        }
    }

    private var clock: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            VStack(alignment: .leading, spacing: 0) {
                Text(context.date, format: .dateTime.hour().minute())
                    .font(Island.largeTitle)
                    .foregroundStyle(Island.primary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(context.date, format: .dateTime.weekday(.wide).day().month(.wide))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Island.secondary)
            }
        }
        .frame(width: 150, alignment: .leading)
    }

    @ViewBuilder private var events: some View {
        if calendar.events.isEmpty {
            VStack(alignment: .leading, spacing: Island.tightGap) {
                Text("No More Events")
                    .font(Island.headline)
                    .foregroundStyle(Island.primary)
                Text("Nothing else is scheduled for today or tomorrow.")
                    .font(Island.body)
                    .foregroundStyle(Island.secondary)
            }
        } else {
            VStack(alignment: .leading, spacing: Island.rowGap) {
                ForEach(calendar.events) { EventRow(event: $0) }
            }
        }
    }
}

private struct EventRow: View {
    let event: UpcomingEvent

    var body: some View {
        HStack(spacing: 10) {
            Capsule()
                .fill(Color(nsColor: event.color))
                .frame(width: 3, height: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text(event.title)
                    .font(Island.headline)
                    .foregroundStyle(Island.primary)
                    .lineLimit(1)
                Text(timeLabel)
                    .font(Island.caption)
                    .foregroundStyle(event.isHappeningNow ? Color.green : Island.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            if let url = event.meetingURL {
                IslandButton(title: "Join", tint: .green) { NSWorkspace.shared.open(url) }
            }
        }
        .frame(height: 32)
    }

    private var timeLabel: String {
        let now = Date()
        let endTime = event.end.formatted(date: .omitted, time: .shortened)
        if event.isHappeningNow {
            return "Now · until \(endTime)"
        }
        let minutes = Int(event.start.timeIntervalSince(now) / 60)
        if minutes < 60 {
            return "In \(max(minutes, 1)) min"
        }
        let range = "\(event.start.formatted(date: .omitted, time: .shortened)) – \(endTime)"
        return Calendar.current.isDateInToday(event.start) ? range : "Tomorrow · \(range)"
    }
}

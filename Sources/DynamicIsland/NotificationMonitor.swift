import AppKit
import Combine
import SQLite3

struct IslandNotification: Identifiable, Equatable {
    let id: Int64
    let bundleID: String
    let appName: String
    let title: String
    let subtitle: String
    let body: String
    let date: Date
    let isCall: Bool
    let icon: NSImage
    let appURL: URL?

    static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }

    func openApp() {
        guard let appURL else { return }
        NSWorkspace.shared.openApplication(at: appURL, configuration: NSWorkspace.OpenConfiguration())
    }
}

/// Watches the Notification Center database for newly delivered notifications.
///
/// macOS has no public API for reading other apps' notifications, but every delivered
/// notification is recorded in usernoted's SQLite database. Reading it requires the
/// user to grant this app Full Disk Access.
final class NotificationMonitor: ObservableObject {
    enum Access: Equatable {
        case granted
        case needsFullDiskAccess
        case unsupported(String) // database layout not recognised
    }

    @Published private(set) var access: Access = .needsFullDiskAccess
    @Published private(set) var recent: [IslandNotification] = []

    /// Emits each notification as it arrives (not the ones that existed at launch).
    let incoming = PassthroughSubject<IslandNotification, Never>()

    static let databasePath = NSHomeDirectory()
        + "/Library/Group Containers/group.com.apple.usernoted/db2/db"
    private static let maxRecent = 30
    private static let callBundleIDs: Set<String> = ["com.apple.facetime", "com.apple.telephonyutilities"]

    private var db: OpaquePointer?
    private var lastID: Int64 = -1
    private var timer: Timer?
    private var appCache: [String: (name: String, icon: NSImage, url: URL?)] = [:]
    private let ownBundleID = Bundle.main.bundleIdentifier ?? "local.dynamicisland.app"

    init() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in self?.poll() }
        poll()
    }

    /// Static instance for snapshots; doesn't touch the database.
    init(previewAccess: Access, recent: [IslandNotification]) {
        access = previewAccess
        self.recent = recent
    }

    deinit {
        timer?.invalidate()
        sqlite3_close(db)
    }

    func clearRecent() {
        recent.removeAll()
    }

    func openFullDiskAccessSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Polling

    private func poll() {
        if case .unsupported = access { return }
        guard openDatabase() else {
            if access != .needsFullDiskAccess { access = .needsFullDiskAccess }
            return
        }
        if access != .granted { access = .granted }

        if lastID < 0 {
            // First successful read: show a little history, but don't pop banners for it.
            guard let maxID = scalar("SELECT IFNULL(MAX(rec_id), 0) FROM record") else { return }
            lastID = maxID
            recent = fetch(where: "r.rec_id <= \(maxID)", order: "DESC", limit: 10)
            NSLog("DynamicIsland: notification database readable, %d recent", recent.count)
            return
        }

        let new = fetch(where: "r.rec_id > \(lastID)", order: "ASC", limit: 50)
        guard !new.isEmpty else { return }
        lastID = new.map(\.id).max() ?? lastID
        for item in new {
            recent.insert(item, at: 0)
            incoming.send(item)
        }
        if recent.count > Self.maxRecent {
            recent.removeLast(recent.count - Self.maxRecent)
        }
    }

    private func openDatabase() -> Bool {
        if db != nil { return true }
        var handle: OpaquePointer?
        guard sqlite3_open_v2(Self.databasePath, &handle, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            sqlite3_close(handle)
            return false
        }
        // Opening is lazy; a real query tells us whether we're actually allowed in.
        var stmt: OpaquePointer?
        let readable = sqlite3_prepare_v2(handle, "SELECT COUNT(*) FROM sqlite_master", -1, &stmt, nil) == SQLITE_OK
            && sqlite3_step(stmt) == SQLITE_ROW
        sqlite3_finalize(stmt)
        guard readable else {
            sqlite3_close(handle)
            return false
        }
        db = handle
        return true
    }

    private func scalar(_ sql: String) -> Int64? {
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            reportPrepareFailure()
            return nil
        }
        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
        return sqlite3_column_int64(stmt, 0)
    }

    private func fetch(where condition: String, order: String, limit: Int) -> [IslandNotification] {
        let sql = """
        SELECT r.rec_id, a.identifier, r.data, r.delivered_date
        FROM record r LEFT JOIN app a ON a.app_id = r.app_id
        WHERE \(condition) ORDER BY r.rec_id \(order) LIMIT \(limit)
        """
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            reportPrepareFailure()
            return []
        }

        var items: [IslandNotification] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let id = sqlite3_column_int64(stmt, 0)
            let identifier = sqlite3_column_text(stmt, 1).map { String(cString: $0) } ?? ""
            var data = Data()
            if let blob = sqlite3_column_blob(stmt, 2) {
                data = Data(bytes: blob, count: Int(sqlite3_column_bytes(stmt, 2)))
            }
            let delivered = sqlite3_column_double(stmt, 3)
            if let item = parse(id: id, identifier: identifier, data: data, delivered: delivered) {
                items.append(item)
            }
        }
        return items
    }

    private func reportPrepareFailure() {
        guard let db else { return }
        let message = String(cString: sqlite3_errmsg(db))
        // A permission problem shows up as "authorization denied"; anything else means
        // the database layout differs from what we expect.
        if message.contains("authorization") || message.contains("unable to open") {
            sqlite3_close(db)
            self.db = nil
        } else {
            NSLog("DynamicIsland: notification database query failed: %@", message)
            access = .unsupported(message)
        }
    }

    // MARK: - Parsing

    private func parse(id: Int64, identifier: String, data: Data, delivered: Double) -> IslandNotification? {
        guard let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else { return nil }
        let request = plist["req"] as? [String: Any] ?? [:]
        let title = request["titl"] as? String ?? ""
        let subtitle = request["subt"] as? String ?? ""
        let body = request["body"] as? String ?? ""
        let category = request["cate"] as? String ?? ""
        let bundleID = (plist["app"] as? String) ?? identifier

        guard !(title.isEmpty && body.isEmpty),
              bundleID.caseInsensitiveCompare(ownBundleID) != .orderedSame
        else { return nil }

        let browserID = Self.canonicalBrowserID(bundleID)
        var app = appInfo(for: browserID ?? bundleID)
        var shownSubtitle = subtitle

        // Website notifications (Slack in Chrome, etc.): show the site, not the browser.
        if browserID != nil, let site = Self.webApp(in: [subtitle, title]) {
            let native = site.nativeBundleID.map { appInfo(for: $0) }
            app = (name: site.name,
                   icon: (native?.url != nil ? native?.icon : nil) ?? app.icon,
                   url: app.url)
            if subtitle.lowercased().contains(site.domain) { shownSubtitle = "" }
        }

        let date = delivered > 0 ? Date(timeIntervalSinceReferenceDate: delivered) : Date()

        return IslandNotification(
            id: id,
            bundleID: browserID ?? bundleID,
            appName: app.name,
            title: title,
            subtitle: shownSubtitle,
            body: body,
            date: date,
            isCall: Self.looksLikeCall(bundleID: bundleID, category: category, text: [title, subtitle, body]),
            icon: app.icon,
            appURL: app.url
        )
    }

    // MARK: - Browsers and web apps

    /// Browsers (and their notification helper processes) mapped to the main app's bundle ID.
    private static let browsers: [(prefix: String, bundleID: String)] = [
        ("com.google.chrome", "com.google.Chrome"),
        ("com.apple.safari", "com.apple.Safari"),
        ("company.thebrowser", "company.thebrowser.Browser"),
        ("com.microsoft.edgemac", "com.microsoft.edgemac"),
        ("org.mozilla.firefox", "org.mozilla.firefox"),
        ("com.brave.browser", "com.brave.Browser"),
        ("com.operasoftware.opera", "com.operasoftware.Opera"),
        ("com.vivaldi.vivaldi", "com.vivaldi.Vivaldi"),
    ]

    private static func canonicalBrowserID(_ bundleID: String) -> String? {
        let lower = bundleID.lowercased()
        return browsers.first { lower.hasPrefix($0.prefix) }?.bundleID
    }

    private struct WebApp {
        let domain: String
        let name: String
        let nativeBundleID: String?
    }

    private static let webApps: [WebApp] = [
        WebApp(domain: "slack.com", name: "Slack", nativeBundleID: "com.tinyspeck.slackmacgap"),
        WebApp(domain: "whatsapp.com", name: "WhatsApp", nativeBundleID: "net.whatsapp.WhatsApp"),
        WebApp(domain: "claude.ai", name: "Claude", nativeBundleID: "com.anthropic.claudefordesktop"),
        WebApp(domain: "chatgpt.com", name: "ChatGPT", nativeBundleID: nil),
        WebApp(domain: "teams.microsoft.com", name: "Teams", nativeBundleID: "com.microsoft.teams2"),
        WebApp(domain: "teams.live.com", name: "Teams", nativeBundleID: "com.microsoft.teams2"),
        WebApp(domain: "mail.google.com", name: "Gmail", nativeBundleID: nil),
        WebApp(domain: "discord.com", name: "Discord", nativeBundleID: "com.hnc.Discord"),
        WebApp(domain: "telegram.org", name: "Telegram", nativeBundleID: "ru.keepcoder.Telegram"),
        WebApp(domain: "linkedin.com", name: "LinkedIn", nativeBundleID: nil),
        WebApp(domain: "meet.google.com", name: "Google Meet", nativeBundleID: nil),
    ]

    private static func webApp(in fields: [String]) -> WebApp? {
        for field in fields {
            let lower = field.lowercased()
            if let match = webApps.first(where: { lower.contains($0.domain) }) { return match }
        }
        return nil
    }

    private static func looksLikeCall(bundleID: String, category: String, text: [String]) -> Bool {
        let joined = text.joined(separator: " ").lowercased()
        if joined.contains("missed") { return false }
        if callBundleIDs.contains(bundleID.lowercased()) { return true }
        if category.lowercased().contains("call") { return true }
        let phrases = ["incoming call", "incoming voice call", "incoming video call",
                       "incoming audio call", "is calling", "calling you", "voice call", "video call",
                       "huddle"]
        return phrases.contains { joined.contains($0) }
    }

    private func appInfo(for bundleID: String) -> (name: String, icon: NSImage, url: URL?) {
        if let cached = appCache[bundleID] { return cached }
        let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
        let name = url.map { FileManager.default.displayName(atPath: $0.path) }?
            .replacingOccurrences(of: ".app", with: "")
            ?? bundleID.split(separator: ".").last.map(String.init)?.capitalized
            ?? bundleID
        let icon = url.map { NSWorkspace.shared.icon(forFile: $0.path) }
            ?? NSImage(systemSymbolName: "app.badge", accessibilityDescription: nil)
            ?? NSImage()
        let info = (name: name, icon: icon, url: url)
        appCache[bundleID] = info
        return info
    }
}

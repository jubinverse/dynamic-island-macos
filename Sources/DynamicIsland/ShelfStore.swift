import AppKit

/// Files dropped on the island. Stores references (not copies); items whose file
/// has been moved or deleted drop off the shelf automatically.
final class ShelfStore: ObservableObject {
    @Published private(set) var items: [URL] = []

    private let defaultsKey = "shelfItems"
    private static let maxItems = 20

    init() {
        let paths = UserDefaults.standard.stringArray(forKey: defaultsKey) ?? []
        items = paths.map { URL(fileURLWithPath: $0) }
        pruneMissing()
    }

    func add(_ urls: [URL]) {
        for url in urls where url.isFileURL && !items.contains(url) {
            items.append(url)
        }
        if items.count > Self.maxItems {
            items.removeFirst(items.count - Self.maxItems)
        }
        save()
    }

    func remove(_ url: URL) {
        items.removeAll { $0 == url }
        save()
    }

    func clear() {
        items.removeAll()
        save()
    }

    func open(_ url: URL) {
        NSWorkspace.shared.open(url)
    }

    func revealInFinder(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func pruneMissing() {
        let existing = items.filter { FileManager.default.fileExists(atPath: $0.path) }
        if existing != items {
            items = existing
            save()
        }
    }

    private func save() {
        UserDefaults.standard.set(items.map(\.path), forKey: defaultsKey)
    }
}

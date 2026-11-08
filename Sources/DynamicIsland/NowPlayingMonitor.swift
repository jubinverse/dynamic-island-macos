import AppKit
import Combine

struct NowPlayingInfo: Equatable {
    var title = ""
    var artist = ""
    var album = ""
    var duration: Double = 0
    var elapsed: Double = 0
    var timestamp = Date()
    var playbackRate: Double = 0
    var isPlaying = false
    var artwork: NSImage?
    var appPID: pid_t = 0

    var hasContent: Bool { !title.isEmpty }

    /// Current position, extrapolated from the last update while playing.
    func elapsed(at date: Date) -> Double {
        guard isPlaying else { return elapsed }
        let rate = playbackRate == 0 ? 1 : playbackRate
        let value = elapsed + date.timeIntervalSince(timestamp) * rate
        return duration > 0 ? min(max(value, 0), duration) : max(value, 0)
    }

    var sourceApp: NSRunningApplication? {
        appPID > 0 ? NSRunningApplication(processIdentifier: appPID) : nil
    }
}

/// Reads system-wide now-playing state through a helper running inside /usr/bin/perl.
/// See Sources/NowPlayingHelper/include/NowPlayingHelper.h for why.
final class NowPlayingMonitor: ObservableObject {
    enum Command: String { case toggle, next, previous }

    @Published private(set) var info = NowPlayingInfo()

    private var process: Process?
    private var commandPipe: Pipe?
    private var buffer = Data()
    private var restartCount = 0

    init() {
        start()
    }

    /// Static instance for snapshots; doesn't start the helper.
    init(preview: NowPlayingInfo) {
        info = preview
    }

    deinit {
        process?.terminate()
    }

    func send(_ command: Command) {
        guard let pipe = commandPipe else { return }
        try? pipe.fileHandleForWriting.write(contentsOf: Data((command.rawValue + "\n").utf8))
        if command == .toggle {
            // Optimistic update so the button responds instantly.
            info.elapsed = info.elapsed(at: Date())
            info.timestamp = Date()
            info.isPlaying.toggle()
        }
    }

    func openSourceApp() {
        info.sourceApp?.activate()
    }

    /// Perl program that loads the helper library into this (Apple-signed) perl
    /// process and calls its entry point. Args: <library path> <symbol>.
    private static let loaderScript = """
    use strict; use DynaLoader;
    my ($lib, $sym) = @ARGV;
    my $h = DynaLoader::dl_load_file($lib, 0) or die DynaLoader::dl_error();
    my $f = DynaLoader::dl_find_symbol($h, $sym) or die DynaLoader::dl_error();
    DynaLoader::dl_install_xsub("main::run", $f);
    main::run();
    """

    /// The helper ends up in a different place depending on how the app was built.
    private static func locateHelperLibrary() -> URL? {
        let exeDir = Bundle.main.executableURL?.deletingLastPathComponent()
        let candidates: [URL?] = [
            Bundle.main.resourceURL?.appendingPathComponent("libNowPlayingHelper.dylib"), // build.sh
            exeDir?.appendingPathComponent("PackageFrameworks/NowPlayingHelper.framework/NowPlayingHelper"), // Xcode
            exeDir?.appendingPathComponent("libNowPlayingHelper.dylib"), // swift build / swift run
        ]
        return candidates.compactMap { $0 }.first { FileManager.default.fileExists(atPath: $0.path) }
    }

    @Published private(set) var helperMissing = false

    private func start() {
        guard let library = Self.locateHelperLibrary() else {
            NSLog("DynamicIsland: now-playing helper library not found")
            helperMissing = true
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        process.arguments = ["-e", Self.loaderScript, library.path, "np_stream"]

        let output = Pipe()
        let input = Pipe()
        process.standardOutput = output
        process.standardInput = input
        process.standardError = FileHandle.nullDevice

        output.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else {
                handle.readabilityHandler = nil
                return
            }
            DispatchQueue.main.async { self?.consume(data) }
        }

        process.terminationHandler = { [weak self] _ in
            DispatchQueue.main.async { self?.helperDidExit() }
        }

        do {
            try process.run()
            self.process = process
            self.commandPipe = input
        } catch {
            NSLog("DynamicIsland: failed to start now-playing helper: \(error)")
        }
    }

    private func helperDidExit() {
        process = nil
        commandPipe = nil
        buffer.removeAll()
        restartCount += 1
        guard restartCount <= 5 else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in self?.start() }
    }

    private func consume(_ data: Data) {
        buffer.append(data)
        while let newline = buffer.firstIndex(of: 0x0A) {
            let line = buffer.subdata(in: buffer.startIndex..<newline)
            buffer.removeSubrange(buffer.startIndex...newline)
            if let object = try? JSONSerialization.jsonObject(with: line) as? [String: Any] {
                apply(object)
            }
        }
    }

    private func apply(_ json: [String: Any]) {
        if json["error"] != nil { return }
        restartCount = 0

        var next = info
        next.title = json["title"] as? String ?? ""
        next.artist = json["artist"] as? String ?? ""
        next.album = json["album"] as? String ?? ""
        next.duration = json["duration"] as? Double ?? 0
        next.elapsed = json["elapsed"] as? Double ?? 0
        next.playbackRate = json["rate"] as? Double ?? 0
        next.isPlaying = (json["playing"] as? NSNumber)?.boolValue ?? false
        next.appPID = pid_t((json["pid"] as? NSNumber)?.int32Value ?? 0)
        if let ts = json["timestamp"] as? Double {
            next.timestamp = Date(timeIntervalSince1970: ts)
        } else {
            next.timestamp = Date()
        }
        // Artwork is only sent when it changes; "" means none.
        if let base64 = json["artwork"] as? String {
            next.artwork = base64.isEmpty ? nil : Data(base64Encoded: base64).flatMap(NSImage.init(data:))
        }
        if !next.hasContent { next.artwork = nil }

        if next != info { info = next }
    }
}

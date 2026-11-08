import AppKit

let app = NSApplication.shared

// Developer aid: `DynamicIsland --snapshot <dir>` renders every island state to PNGs and exits.
if let flag = CommandLine.arguments.firstIndex(of: "--snapshot"),
   CommandLine.arguments.indices.contains(flag + 1) {
    MainActor.assumeIsolated {
        SnapshotRenderer.run(outputDirectory: CommandLine.arguments[flag + 1])
    }
    exit(0)
}

// Menu-bar-less agent app (LSUIElement): no Dock icon, just the island + a status item.
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()

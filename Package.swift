// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DynamicIsland",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "DynamicIsland", targets: ["DynamicIsland"]),
        // Loaded into /usr/bin/perl at runtime to read MediaRemote (see NowPlayingMonitor.loaderScript).
        .library(name: "NowPlayingHelper", type: .dynamic, targets: ["NowPlayingHelper"]),
    ],
    targets: [
        .executableTarget(
            name: "DynamicIsland",
            path: "Sources/DynamicIsland"
        ),
        .target(
            name: "NowPlayingHelper",
            path: "Sources/NowPlayingHelper",
            cSettings: [.unsafeFlags(["-fobjc-arc"])],
            linkerSettings: [.linkedFramework("Foundation")]
        ),
    ]
)

// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NotchIsland",
    platforms: [.macOS(.v15)],
    targets: [
        .executableTarget(
            name: "NotchIsland",
            path: "Sources/NotchIsland"
        )
    ],
    // Swift 5 mode: AppKit callbacks, event monitors and (later) private C APIs
    // are far less noisy without Swift 6 strict concurrency.
    swiftLanguageModes: [.v5]
)

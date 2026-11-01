// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TrackpadGestures",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "GestureCore"),
        .executableTarget(name: "TrackpadGestures", dependencies: ["GestureCore"]),
        .testTarget(name: "GestureCoreTests", dependencies: ["GestureCore"]),
    ]
)

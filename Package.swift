// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RemoteCommander",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "RemoteCommander",
            targets: ["RemoteCommander"]
        )
    ],
    targets: [
        .executableTarget(
            name: "RemoteCommander",
            path: "Sources/RemoteCommander"
        )
    ]
)

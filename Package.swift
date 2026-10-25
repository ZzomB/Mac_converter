// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MacConverter",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "MacConverter",
            targets: ["MacConverter"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "MacConverter",
            dependencies: [],
            path: "Sources/MacConverter"
        )
    ]
)

// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "AudioPromt",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "AudioPromt"
        ),
        .testTarget(
            name: "AudioPromtTests",
            dependencies: ["AudioPromt"]
        ),
    ],
    swiftLanguageModes: [.v6]
)

// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "AudioPromt",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(url: "https://github.com/argmaxinc/WhisperKit.git", from: "0.9.0")
    ],
    targets: [
        .executableTarget(
            name: "AudioPromt",
            dependencies: [
                .product(name: "WhisperKit", package: "WhisperKit")
            ]
        ),
        .testTarget(
            name: "AudioPromtTests",
            dependencies: ["AudioPromt"]
        ),
    ],
    swiftLanguageModes: [.v6]
)

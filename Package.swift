// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "TextGrabber",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "TextGrabberKit",
            targets: ["TextGrabberKit"]
        ),
        .executable(
            name: "TextGrabber",
            targets: ["TextGrabberApp"]
        )
    ],
    targets: [
        .target(
            name: "TextGrabberKit",
            path: "Sources/TextGrabberKit"
        ),
        .executableTarget(
            name: "TextGrabberApp",
            dependencies: ["TextGrabberKit"],
            path: "Sources/TextGrabberApp"
        ),
        .testTarget(
            name: "TextGrabberTests",
            dependencies: ["TextGrabberKit"],
            path: "Tests/TextGrabberTests"
        )
    ]
)

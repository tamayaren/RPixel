// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "RPixel",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "RPixelCore",
            targets: ["RPixelCore"]
        ),
        .executable(
            name: "RPixel",
            targets: ["RPixel"]
        ),
        .executable(
            name: "RPixelApp",
            targets: ["RPixelApp"]
        ),
        .executable(
            name: "RPixelTests",
            targets: ["RPixelTests"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "RPixelCore",
            dependencies: [],
            path: "Sources/RPixelCore"
        ),
        .executableTarget(
            name: "RPixel",
            dependencies: ["RPixelCore"],
            path: "Sources/RPixel"
        ),
        .executableTarget(
            name: "RPixelApp",
            dependencies: ["RPixelCore"],
            path: "Sources/RPixelApp"
        ),
        .executableTarget(
            name: "RPixelTests",
            dependencies: ["RPixelCore"],
            path: "Tests/RPixelTests"
        )
    ]
)

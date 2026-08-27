// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "StaticRe",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "StaticReKit",
            targets: ["StaticReKit"]
        ),
        .executable(
            name: "static-re",
            targets: ["CLI"]
        ),
        .executable(
            name: "StaticReApp",
            targets: ["StaticReApp"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "StaticReKit",
            dependencies: [],
            path: "Sources/StaticReKit"
        ),
        .executableTarget(
            name: "CLI",
            dependencies: ["StaticReKit"],
            path: "Sources/CLI"
        ),
        .executableTarget(
            name: "StaticReApp",
            dependencies: ["StaticReKit"],
            path: "Sources/StaticReApp"
        ),
        .testTarget(
            name: "StaticReKitTests",
            dependencies: ["StaticReKit"],
            path: "Tests/StaticReKitTests"
        )
    ]
)

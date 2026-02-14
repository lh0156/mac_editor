// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "InkArc",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "InkArc", targets: ["InkArc"])
    ],
    targets: [
        .executableTarget(
            name: "InkArc",
            path: "Sources"
        ),
        .testTarget(
            name: "InkArcTests",
            dependencies: ["InkArc"],
            path: "Tests/InkArcTests"
        )
    ]
)

// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LocationAutomation",
    platforms: [
        .macOS(.v12),
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "LocationAutomation",
            targets: ["Core"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/stephencelis/SQLite.swift.git", from: "0.15.0")
    ],
    targets: [
        .executableTarget(
            name: "App",
            dependencies: ["Core"]
        ),
        .target(
            name: "Core",
            dependencies: [.product(name: "SQLite", package: "sqlite.swift")]
        ),
        .testTarget(
            name: "LocationAutomationTests",
            dependencies: ["Core"]
        )
    ]
)

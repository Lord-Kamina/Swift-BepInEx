// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Swift-BepInEx-Launcher",
	platforms: [.macOS(.v11)],
    dependencies: [
        // Add the dependency here
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.1"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .executableTarget(
            name: "Swift-BepInEx-Launcher",
            dependencies: [
                // Make the executable target depend on the argument parser
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]),
        .testTarget(
            name: "Swift-BepInEx-Test",
            dependencies: ["Swift-BepInEx-Launcher"]
            )
    ]
)

// swift-tools-version: 6.0
// Package.swift provides SPM build verification and test support.
// The primary build system is the Xcode project (Fallow.xcodeproj).

import PackageDescription

let package = Package(
    name: "Fallow",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/apple/swift-testing.git", from: "0.12.0"),
    ],
    targets: [
        .target(
            name: "FallowCore",
            path: "Fallow",
            exclude: [
                "Entry",
                "Info.plist",
                "Fallow.entitlements",
                "FallowRelease.entitlements",
                "Resources",
            ]
        ),
        .executableTarget(
            name: "Fallow",
            dependencies: ["FallowCore"],
            path: "Fallow/Entry"
        ),
        .testTarget(
            name: "FallowTests",
            dependencies: [
                "FallowCore",
                .product(name: "Testing", package: "swift-testing"),
            ],
            path: "Tests/FallowTests"
        ),
    ]
)

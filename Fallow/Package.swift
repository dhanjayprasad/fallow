// swift-tools-version: 6.0
// Package.swift is used for command-line build verification.
// The primary build system is the Xcode project (Fallow.xcodeproj).

import PackageDescription

let package = Package(
    name: "Fallow",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Fallow",
            path: "Fallow",
            exclude: [
                "Info.plist",
                "Fallow.entitlements",
                "Resources",
            ]
        ),
    ]
)

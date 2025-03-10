// swift-tools-version:6.0

//
// This source file is part of the Stanford XCTRuntimeAssertions open-source project
// 
// SPDX-FileCopyrightText: 2022 Stanford University and the project authors (see CONTRIBUTORS.md)
// 
// SPDX-License-Identifier: MIT
//

import class Foundation.ProcessInfo
import PackageDescription


let package = Package(
    name: "RuntimeAssertions",
    platforms: [
        .iOS(.v16),
        .visionOS(.v1),
        .watchOS(.v9),
        .tvOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(name: "RuntimeAssertions", targets: ["RuntimeAssertions"]),
        .library(name: "RuntimeAssertionsTesting", targets: ["RuntimeAssertionsTesting"]),
        .library(name: "XCTRuntimeAssertions", targets: ["XCTRuntimeAssertions"])
    ],
    dependencies: swiftLintPackage(),
    targets: [
        .target(
            name: "RuntimeAssertions",
            plugins: [] + swiftLintPlugin()
        ),
        .target(
            name: "RuntimeAssertionsTesting",
            dependencies: [
                .target(name: "RuntimeAssertions")
            ],
            plugins: [] + swiftLintPlugin()
        ),
        .target(
            name: "XCTRuntimeAssertions",
            dependencies: [
                .target(name: "RuntimeAssertions")
            ],
            plugins: [] + swiftLintPlugin()
        ),
        .testTarget(
            name: "RuntimeAssertionsTests",
            dependencies: [
                .target(name: "RuntimeAssertions"),
                .target(name: "RuntimeAssertionsTesting")
            ],
            plugins: [] + swiftLintPlugin()
        ),
        .testTarget(
            name: "XCTRuntimeAssertionsTests",
            dependencies: [
                .target(name: "XCTRuntimeAssertions")
            ],
            plugins: [] + swiftLintPlugin()
        )
    ],
    swiftLanguageModes: [
        .v5
    ]
)


func swiftLintPlugin() -> [Target.PluginUsage] {
    // Fully quit Xcode and open again with `open --env SPEZI_DEVELOPMENT_SWIFTLINT /Applications/Xcode.app`
    if ProcessInfo.processInfo.environment["SPEZI_DEVELOPMENT_SWIFTLINT"] != nil {
        [.plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLint")]
    } else {
        []
    }
}

func swiftLintPackage() -> [PackageDescription.Package.Dependency] {
    if ProcessInfo.processInfo.environment["SPEZI_DEVELOPMENT_SWIFTLINT"] != nil {
        [.package(url: "https://github.com/realm/SwiftLint.git", from: "0.55.1")]
    } else {
        []
    }
}

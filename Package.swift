// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "ai-prompt-manager-mac-app",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "PromptManager", targets: ["PromptManager"]),
        .library(name: "PromptManagerCore", targets: ["PromptManagerCore"])
    ],
    targets: [
        .target(name: "PromptManagerCore"),
        .executableTarget(
            name: "PromptManager",
            dependencies: ["PromptManagerCore"],
            exclude: ["Info.plist", "Resources"],
            swiftSettings: [.unsafeFlags(["-parse-as-library"])]
        ),
        .executableTarget(
            name: "PromptManagerChecks",
            dependencies: ["PromptManagerCore"],
            path: "Tests/PromptManagerTests"
        )
    ]
)

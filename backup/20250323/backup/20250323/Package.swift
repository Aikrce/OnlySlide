// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "OnlySlide",
    platforms: [
        .macOS(.v13),
        .iOS(.v16)
    ],
    products: [
        .executable(name: "OnlySlide", targets: ["OnlySlide"]),
        .library(name: "OnlySlideCore", targets: ["Core"]),
        .library(name: "OnlySlideUI", targets: ["App"]),
        .library(name: "OnlySlideFeatures", targets: ["Features"]),
        .library(name: "OnlySlideCommon", targets: ["Common"])
    ],
    dependencies: [
        // Dependencies
        .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0")
    ],
    targets: [
        // 主应用目标
        .executableTarget(
            name: "OnlySlide",
            dependencies: [
                "Core",
                "App",
                "Features",
                "Common"
            ],
            path: "Sources/OnlySlide",
            exclude: ["Info.plist"],
            resources: [
                .copy("OnlySlide.entitlements"),
                .copy("Resources")
            ]
        ),
        
        // 核心模块
        .target(
            name: "Core",
            dependencies: [
                "Common",
                .product(name: "Logging", package: "swift-log")
            ],
            path: "Sources/Core",
            resources: [
                .process("Data/Persistence/CoreData/OnlySlide.xcdatamodeld")
            ],
            swiftSettings: [
                .define("DEBUG", .when(configuration: .debug)),
                .define("RELEASE", .when(configuration: .release))
            ]
        ),
        
        // UI模块
        .target(
            name: "App",
            dependencies: ["Core", "Common"],
            path: "Sources/App",
            swiftSettings: [
                .define("DEBUG", .when(configuration: .debug))
            ]
        ),
        
        // 功能模块
        .target(
            name: "Features",
            dependencies: [
                "Core",
                "Common",
                .product(name: "Logging", package: "swift-log")
            ],
            path: "Sources/Features",
            swiftSettings: [
                .define("DEBUG", .when(configuration: .debug))
            ]
        ),
        
        // 公共模块
        .target(
            name: "Common",
            dependencies: [],
            path: "Sources/Common",
            swiftSettings: [
                .define("DEBUG", .when(configuration: .debug))
            ]
        ),
        
        // 测试目标
        .testTarget(
            name: "CoreTests",
            dependencies: ["Core"],
            path: "Tests/Core"
        ),
        .testTarget(
            name: "AppTests",
            dependencies: ["App"],
            path: "Tests/App"
        ),
        .testTarget(
            name: "FeaturesTests",
            dependencies: ["Features"],
            path: "Tests/Features"
        )
    ]
)

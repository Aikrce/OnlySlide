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
        .library(name: "OnlySlideCommon", targets: ["Common"]),
        .library(name: "OnlySlideCoreData", targets: ["CoreDataModule"]),
        .library(name: "OnlySlideLogging", targets: ["Logging"])
    ],
    dependencies: [],
    targets: [
        // 主应用目标
        .executableTarget(
            name: "OnlySlide",
            dependencies: [
                "Core",
                "App",
                "Features",
                "Common",
                "CoreDataModule"
            ],
            path: "Sources/OnlySlide",
            exclude: [
                "Tests/**/*.md",
                "Tests/**/README.md",
                "Tests/**/*_TESTING.md",
                "Tests/**/*_GUIDE.md"
            ],
            resources: [
                .copy("OnlySlide.entitlements"),
                .copy("Info.plist"),
                .process("Resources", exclude: ["*.md"])
            ]
        ),
        
        // 日志模块
        .target(
            name: "Logging",
            dependencies: ["Common"],
            path: "Sources/Logging",
            swiftSettings: [
                .define("DEBUG", .when(configuration: .debug)),
                .define("RELEASE", .when(configuration: .release))
            ]
        ),
        
        // 核心模块
        .target(
            name: "Core",
            dependencies: [
                "Common",
                "CoreDataModule",
                "Logging"
            ],
            path: "Sources/Core",
            swiftSettings: [
                .define("DEBUG", .when(configuration: .debug)),
                .define("RELEASE", .when(configuration: .release))
            ]
        ),
        
        // CoreData模块
        .target(
            name: "CoreDataModule",
            dependencies: [
                "Common",
                "Logging"
            ],
            path: "Sources/CoreDataModule",
            resources: [
                .process("Models/OnlySlide.xcdatamodeld")
            ],
            swiftSettings: [
                .define("DEBUG", .when(configuration: .debug)),
                .define("RELEASE", .when(configuration: .release))
            ]
        ),
        
        // UI模块
        .target(
            name: "App",
            dependencies: ["Core", "Common", "CoreDataModule"],
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
                "CoreDataModule",
                "Logging"
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
            dependencies: ["Core", "CoreDataModule"],
            path: "Tests/CoreTests",
            swiftSettings: [
                .define("TEST", .when(configuration: .debug))
            ]
        ),
        .testTarget(
            name: "CoreDataTests",
            dependencies: ["CoreDataModule"],
            path: "Tests/CoreDataTests",
            resources: [
                .process("TestModel.xcdatamodeld")
            ],
            swiftSettings: [
                .define("TEST", .when(configuration: .debug))
            ]
        ),
        .testTarget(
            name: "AppTests",
            dependencies: ["App"],
            path: "Tests/AppTests",
            swiftSettings: [
                .define("TEST", .when(configuration: .debug))
            ]
        ),
        .testTarget(
            name: "FeaturesTests",
            dependencies: ["Features"],
            path: "Tests/FeaturesTests",
            swiftSettings: [
                .define("TEST", .when(configuration: .debug))
            ]
        ),
        .testTarget(
            name: "CommonTests",
            dependencies: ["Common"],
            path: "Tests/CommonTests",
            swiftSettings: [
                .define("TEST", .when(configuration: .debug))
            ]
        ),
        .testTarget(
            name: "LoggingTests",
            dependencies: ["Logging", "Common"],
            path: "Tests/LoggingTests",
            swiftSettings: [
                .define("TEST", .when(configuration: .debug))
            ]
        )
    ]
)

// swift-tools-version: 6.0
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
        .library(name: "OnlySlideLogging", targets: ["Logging"]),
        .library(name: "OnlySlideTesting", targets: ["Testing"]),
        .library(name: "OnlySlideDocumentAnalysis", targets: ["DocumentAnalysis"])
    ],
    dependencies: [
        // 添加ZIP文件处理库，用于解析.docx文件
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", from: "0.9.0"),
        // 添加XML解析库，用于处理Office XML格式
        .package(url: "https://github.com/MaxDesiatov/XMLCoder.git", from: "0.13.0")
    ],
    targets: [
        // 主应用目标
        .executableTarget(
            name: "OnlySlide",
            dependencies: [
                "Core",
                "App",
                "Features",
                "Common",
                "CoreDataModule",
                "DocumentAnalysis"
            ],
            path: "Sources/OnlySlide",
            exclude: [],
            resources: []
        ),
        
        // 文档分析模块
        .target(
            name: "DocumentAnalysis",
            dependencies: [
                "Common",
                .product(name: "ZIPFoundation", package: "ZIPFoundation"),
                .product(name: "XMLCoder", package: "XMLCoder")
            ],
            path: "Sources/DocumentAnalysis",
            swiftSettings: [
                .define("DEBUG", .when(configuration: .debug))
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
        
        // 测试支持模块
        .target(
            name: "Testing",
            dependencies: ["Common"],
            path: "Sources/Testing",
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
            resources: [],
            swiftSettings: [
                .define("DEBUG", .when(configuration: .debug)),
                .define("RELEASE", .when(configuration: .release))
            ]
        ),
        
        // UI模块
        .target(
            name: "App",
            dependencies: ["Core", "Common", "CoreDataModule", "DocumentAnalysis"],
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
                "Logging",
                "DocumentAnalysis"
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
            dependencies: ["Core", "CoreDataModule", "Testing"],
            path: "Tests/CoreTests",
            swiftSettings: [
                .define("TEST", .when(configuration: .debug))
            ]
        ),
        .testTarget(
            name: "CoreDataTests",
            dependencies: ["CoreDataModule", "Testing"],
            path: "Tests/CoreDataTests",
            resources: [],
            swiftSettings: [
                .define("TEST", .when(configuration: .debug))
            ]
        ),
        .testTarget(
            name: "AppTests",
            dependencies: ["App", "Testing"],
            path: "Tests/AppTests",
            swiftSettings: [
                .define("TEST", .when(configuration: .debug))
            ]
        ),
        .testTarget(
            name: "FeaturesTests",
            dependencies: ["Features", "Testing"],
            path: "Tests/FeaturesTests",
            swiftSettings: [
                .define("TEST", .when(configuration: .debug))
            ]
        ),
        // 暂时注释掉 CommonTests 测试目标以解决多重编译问题
        /* 
        .testTarget(
            name: "CommonTests",
            dependencies: ["Common", "Testing"],
            path: "Tests/CommonTests",
            swiftSettings: [
                .define("TEST", .when(configuration: .debug))
            ]
        ),
        */
        .testTarget(
            name: "LoggingTests",
            dependencies: ["Logging", "Common", "Testing"],
            path: "Tests/LoggingTests",
            swiftSettings: [
                .define("TEST", .when(configuration: .debug))
            ]
        ),
        // 文档分析模块测试
        .testTarget(
            name: "DocumentAnalysisTests",
            dependencies: ["DocumentAnalysis", "Testing"],
            path: "Tests/DocumentAnalysisTests",
            swiftSettings: [
                .define("TEST", .when(configuration: .debug))
            ]
        )
    ]
)

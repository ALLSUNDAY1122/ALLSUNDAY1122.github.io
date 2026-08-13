// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "JosanshiSprintFeature",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "JosanshiSprintFeature", targets: ["JosanshiSprintFeature"])
    ],
    dependencies: [
        .package(path: "../../../native-ios/LearningSprintCore")
    ],
    targets: [
        .target(
            name: "JosanshiSprintFeature",
            dependencies: [
                .product(name: "LearningSprintCore", package: "LearningSprintCore")
            ],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "JosanshiSprintFeatureTests",
            dependencies: [
                "JosanshiSprintFeature",
                .product(name: "LearningSprintCore", package: "LearningSprintCore")
            ]
        )
    ]
)

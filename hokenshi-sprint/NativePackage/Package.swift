// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "HokenshiSprintNative",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(name: "HokenshiSprintFeature", targets: ["HokenshiSprintFeature"])
    ],
    dependencies: [
        .package(path: "../../native-ios/LearningSprintCore")
    ],
    targets: [
        .target(
            name: "HokenshiSprintFeature",
            dependencies: ["LearningSprintCore"],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "HokenshiSprintFeatureTests",
            dependencies: ["HokenshiSprintFeature", "LearningSprintCore"]
        )
    ]
)

// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "AppShell",
    platforms: [.iOS(.v17)],
    products: [.library(name: "AppShell", targets: ["AppShell"])],
    dependencies: [
        .package(path: "../ProductFlow"),
        .package(path: ".."),
        .package(path: "../Recovery"),
        .package(path: "../ReviewCore")
    ],
    targets: [
        .target(
            name: "AppShell",
            dependencies: ["ProductFlow", "ScannerRuntime", "Recovery", "ReviewCore"],
            resources: [.copy("Resources/PrivacyInfo.xcprivacy")]
        )
    ]
)

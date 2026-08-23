// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "AppShell",
    platforms: [.iOS(.v17)],
    products: [.library(name: "AppShell", targets: ["AppShell"])],
    dependencies: [
        .package(name: "ProductFlow", path: "../ProductFlow"),
        .package(name: "ScannerParityRuntime", path: ".."),
        .package(name: "Recovery", path: "../Recovery"),
        .package(name: "ReviewCore", path: "../ReviewCore")
    ],
    targets: [
        .target(
            name: "AppShell",
            dependencies: [
                .product(name: "ProductFlow", package: "ProductFlow"),
                .product(name: "ScannerRuntime", package: "ScannerParityRuntime"),
                .product(name: "Recovery", package: "Recovery"),
                .product(name: "ReviewCore", package: "ReviewCore")
            ],
            resources: [.copy("Resources/PrivacyInfo.xcprivacy")]
        )
    ]
)

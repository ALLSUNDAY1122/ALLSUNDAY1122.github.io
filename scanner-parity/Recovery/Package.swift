// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ScannerParityRecovery",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "Recovery", targets: ["Recovery"])],
    dependencies: [
        .package(path: "../ReviewCore")
    ],
    targets: [
        .target(
            name: "Recovery",
            dependencies: [.product(name: "ReviewCore", package: "ReviewCore")],
            path: ".",
            exclude: ["Package.swift", "README.md"]
        )
    ]
)

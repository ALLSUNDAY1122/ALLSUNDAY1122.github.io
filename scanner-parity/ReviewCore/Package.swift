// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ScannerParityReviewCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "ReviewCore", targets: ["ReviewCore"])],
    targets: [
        .target(name: "ReviewCore", path: ".", exclude: ["Package.swift"], sources: ["ReviewQueueCore.swift"])
    ]
)

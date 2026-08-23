// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ScannerParityRuntime",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "ScannerRuntime", targets: ["ScannerRuntime"]),
        .library(name: "RuntimeComposition", targets: ["RuntimeComposition"]),
        .executable(name: "scanner-hq-golden-runner", targets: ["HQGoldenRunner"])
    ],
    dependencies: [
        .package(name: "ProductFlow", path: "ProductFlow")
    ],
    targets: [
        .target(
            name: "ScannerRuntime",
            path: ".",
            exclude: [
                "AppShell",
                "AppleValidation",
                "GoldenEvaluation",
                "HQGoldenRunner",
                "LongRun",
                "PackageQuality",
                "PrivacyAudit",
                "ProductFlow",
                "Recovery",
                "ReviewCore",
                "SecurityHardening",
                "Tests",
                "iOSApp"
            ],
            sources: [
                "FrameExtraction",
                "ImageCorrection",
                "PageAudit",
                "PipelineCore",
                "OCRExport/Sources/OCRExport",
                "PipelineOCR",
                "PackageValidation/Sources/PackageValidation"
            ]
        ),
        .target(
            name: "RuntimeComposition",
            dependencies: [
                "ScannerRuntime",
                .product(name: "ProductFlow", package: "ProductFlow")
            ],
            path: "AppShell/Sources/AppShell",
            sources: [
                "ProductionScannerRuntime.swift",
                "GoldenHardenedScannerRuntime.swift"
            ]
        ),
        .executableTarget(
            name: "HQGoldenRunner",
            dependencies: [
                "RuntimeComposition",
                .product(name: "ProductFlow", package: "ProductFlow")
            ],
            path: "HQGoldenRunner"
        )
    ]
)

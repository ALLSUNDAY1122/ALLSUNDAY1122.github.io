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
        .library(name: "HQGoldenSupport", targets: ["HQGoldenSupport"]),
        .executable(name: "scanner-hq-golden-runner", targets: ["HQGoldenRunner"]),
        .executable(name: "scanner-hq-golden-finalizer", targets: ["HQGoldenFinalizer"]),
        .executable(name: "scanner-hq-golden-failure-recorder", targets: ["HQGoldenFailureRecorder"])
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
                "HQGoldenFailureRecorder",
                "HQGoldenFinalizer",
                "HQGoldenRunner",
                "HQGoldenSupport",
                "LongRun",
                "PackageQuality",
                "PrivacyAudit",
                "ProductFlow",
                "Recovery",
                "ReviewCore",
                "SecurityHardening",
                "Tests",
                "iOSApp",
                "FrameExtraction/README.md",
                "ImageCorrection/README.md",
                "PipelineCore/README.md",
                "PipelineOCR/README.md",
                "OCRExport/Package.swift",
                "OCRExport/Tests",
                "PackageValidation/Package.swift",
                "PackageValidation/ROADMAP.md",
                "PackageValidation/Tests",
                "SHARED_CONTRACT.md"
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
            exclude: [
                "AppShellContract.swift",
                "BookPackageExportView.swift",
                "MediaImportCoordinator.swift",
                "ProductBackgroundTaskController.swift",
                "ProductFlowStore.swift",
                "RecoveryProductReviewWorkflow.swift",
                "Resources",
                "ScannerParityApp.swift",
                "ScannerParityRootView.swift",
                "ScannerPipelineBindings.swift"
            ],
            sources: [
                "ProductionScannerRuntime.swift",
                "GoldenHardenedScannerRuntime.swift"
            ]
        ),
        .target(
            name: "HQGoldenSupport",
            path: "HQGoldenSupport"
        ),
        .executableTarget(
            name: "HQGoldenRunner",
            dependencies: [
                "ScannerRuntime",
                "RuntimeComposition",
                "HQGoldenSupport",
                .product(name: "ProductFlow", package: "ProductFlow")
            ],
            path: "HQGoldenRunner"
        ),
        .executableTarget(
            name: "HQGoldenFinalizer",
            dependencies: ["HQGoldenSupport"],
            path: "HQGoldenFinalizer"
        ),
        .executableTarget(
            name: "HQGoldenFailureRecorder",
            dependencies: ["HQGoldenSupport"],
            path: "HQGoldenFailureRecorder"
        ),
        .testTarget(
            name: "HQGoldenSupportTests",
            dependencies: ["HQGoldenSupport"],
            path: "Tests/HQGoldenSupport"
        ),
        .testTarget(
            name: "ScannerRuntimeTests",
            dependencies: ["ScannerRuntime"],
            path: "Tests/ScannerRuntime"
        )
    ]
)

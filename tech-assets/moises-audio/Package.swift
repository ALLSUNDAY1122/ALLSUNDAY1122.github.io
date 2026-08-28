// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MoisesAudioCore",
    products: [
        .library(name: "MoisesAudioCore", targets: ["MoisesAudioCore"])
    ],
    targets: [
        .target(
            name: "MoisesAudioCore",
            path: ".",
            exclude: [
                "Tests",
                "PARITY_MATRIX.json",
                "Separation",
                "Analysis",
                "DSP",
                "IO",
                "Library",
                "reference"
            ],
            sources: [
                "AudioSeparationCore.swift",
                "Shared/DomainContracts.swift",
                "Shared/LibraryContracts.swift",
                "Processing/Sources/ProcessingLifecycleStateStore.swift",
                "Processing/Sources/ProcessingProviderCapabilities.swift",
                "Processing/Sources/ProcessingLifecycleCoordinator.swift",
                "Processing/Sources/ProcessingCrashSafeRelaunchRecovery.swift",
                "App/VerticalSliceCoordinator.swift"
            ]
        ),
        .testTarget(
            name: "MoisesAudioCoreTests",
            dependencies: ["MoisesAudioCore"],
            path: "Tests/MoisesAudioCoreTests"
        )
    ]
)

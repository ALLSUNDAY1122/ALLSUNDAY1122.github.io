// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MoisesAudioCore",
    products: [
        .library(name: "MoisesAudioCore", targets: ["MoisesAudioCore"]),
        .library(name: "MoisesAudioLane2", targets: ["MoisesAudioLane2"])
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
                "App/VerticalSliceCoordinator.swift",
                "App/AccountDataDeletionCoordinator.swift"
            ]
        ),
        .target(
            name: "MoisesAudioLane2",
            dependencies: ["MoisesAudioCore"],
            path: ".",
            exclude: [
                "Tests",
                "PARITY_MATRIX.json",
                "AudioSeparationCore.swift",
                "Separation",
                "Analysis",
                "DSP",
                "Processing",
                "App",
                "Shared",
                "reference"
            ],
            sources: [
                "IO/Sources",
                "Library/Sources"
            ]
        ),
        .testTarget(
            name: "MoisesAudioCoreTests",
            dependencies: ["MoisesAudioCore"],
            path: "Tests/MoisesAudioCoreTests"
        ),
        .testTarget(
            name: "MoisesAudioLane2CompositionTests",
            dependencies: ["MoisesAudioCore", "MoisesAudioLane2"],
            path: "Tests/MoisesAudioLane2CompositionTests"
        )
    ]
)

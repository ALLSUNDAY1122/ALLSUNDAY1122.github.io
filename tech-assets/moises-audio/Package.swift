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
                "reference",
                "iOS/App",
                "iOS/project.yml",
                "iOS/README.md"
            ],
            sources: [
                "AudioSeparationCore.swift",
                "Shared/DomainContracts.swift",
                "Shared/LibraryContracts.swift",
                "App/VerticalSliceCoordinator.swift",
                "iOS/HostCore/HostModuleSlots.swift",
                "iOS/HostCore/ApplePlatformSmoke.swift"
            ]
        ),
        .testTarget(
            name: "MoisesAudioCoreTests",
            dependencies: ["MoisesAudioCore"],
            path: "Tests/MoisesAudioCoreTests"
        )
    ]
)

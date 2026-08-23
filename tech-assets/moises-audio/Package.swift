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
                "Analysis/benchmarks",
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
                "Analysis/AnalysisSignal.swift",
                "Analysis/TempoBeatAnalyzer.swift",
                "Analysis/MusicalKeyAnalyzer.swift",
                "Analysis/ChordVocabularyClassifier.swift",
                "Analysis/ChordTimelineAnalyzer.swift",
                "Analysis/SongSectionAnalyzer.swift",
                "Analysis/SongSectionHardener.swift",
                "Analysis/AnalysisSnapshotRobustness.swift",
                "Analysis/AnalysisBenchmarkRunner.swift",
                "Analysis/SectionBenchmarkEvaluator.swift",
                "Analysis/RealAudioBenchmarkSuite.swift",
                "Analysis/RealAudioBenchmarkCodec.swift",
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

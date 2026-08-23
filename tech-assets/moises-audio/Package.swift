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
                "Analysis/AnalysisCancellation.swift",
                "Analysis/AnalysisWorkingSetPolicy.swift",
                "Analysis/BoundedTempoBeatAnalyzer.swift",
                "Analysis/BoundedMusicalKeyAnalyzer.swift",
                "Analysis/ChordVocabularyClassifier.swift",
                "Analysis/BoundedChordTimelineAnalyzer.swift",
                "Analysis/SectionAnalysisIndex.swift",
                "Analysis/CancellableSongSectionPipeline.swift",
                "Analysis/SongSectionBoundaryHardener.swift",
                "Analysis/TempoBeatAnalyzer.swift",
                "Analysis/MusicalKeyAnalyzer.swift",
                "Analysis/ChordTimelineAnalyzer.swift",
                "Analysis/SongSectionAnalyzer.swift",
                "Analysis/SongSectionHardener.swift",
                "Analysis/AnalysisSnapshotRobustness.swift",
                "Analysis/AnalysisSnapshotCancellable.swift",
                "Analysis/AnalysisBenchmarkRunner.swift",
                "Analysis/AnalysisSnapshotHealthBenchmark.swift",
                "Analysis/AnalysisLongAudioPerformanceBenchmark.swift",
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

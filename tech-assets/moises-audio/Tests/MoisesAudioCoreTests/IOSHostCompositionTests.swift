import XCTest

#if canImport(MoisesAudioCore)
@testable import MoisesAudioCore
#else
@testable import MoisesLane4Host
#endif

final class IOSHostCompositionTests: XCTestCase {
    func testEmptySlotsFailClosedAndExposeDeterministicMissingModules() {
        let slots = HostModuleSlots.empty

        XCTAssertEqual(
            slots.missingCoordinatorModules,
            [.io, .separation, .playback, .analysis, .library, .export]
        )
        XCTAssertEqual(
            slots.missingLateIntegrationModules,
            [.io, .separation, .playback, .analysis, .library, .export, .dsp]
        )

        XCTAssertThrowsError(try slots.makeCoordinator()) { error in
            XCTAssertEqual(
                error as? HostCompositionError,
                .missingRequiredModules([.io, .separation, .playback, .analysis, .library, .export])
            )
        }
    }

    func testFrozenCoordinatorCanBeConstructedFromProtocolSlotsWithoutCrossLaneCode() async throws {
        let slots = HostModuleSlots(
            importer: ImporterStub(),
            separator: SeparatorStub(),
            playback: PlaybackStub(),
            analysis: AnalysisStub(),
            persistence: PersistenceStub(),
            exporter: ExporterStub()
        )

        XCTAssertTrue(slots.missingCoordinatorModules.isEmpty)
        XCTAssertEqual(slots.missingLateIntegrationModules, [.dsp])

        let coordinator = try slots.makeCoordinator()
        let route = await coordinator.route
        XCTAssertEqual(route, .library)
    }

    func testDSPRemainsAnExplicitLateIntegrationSlot() {
        let slots = HostModuleSlots(
            importer: ImporterStub(),
            separator: SeparatorStub(),
            playback: PlaybackStub(),
            analysis: AnalysisStub(),
            persistence: PersistenceStub(),
            exporter: ExporterStub(),
            practiceDSP: DSPStub()
        )

        XCTAssertTrue(slots.missingCoordinatorModules.isEmpty)
        XCTAssertTrue(slots.missingLateIntegrationModules.isEmpty)
    }

    func testApplePlatformSmokeFailsClosedOffAppleAndLinksOnApple() {
        let report = ApplePlatformSmoke.run()
#if canImport(AVFoundation) && canImport(AVFAudio)
        XCTAssertTrue(report.avFoundationAvailable)
        XCTAssertTrue(report.avFAudioAvailable)
        XCTAssertFalse(report.linkedTypeNames.isEmpty)
#else
        XCTAssertFalse(report.avFoundationAvailable)
        XCTAssertFalse(report.avFAudioAvailable)
        XCTAssertTrue(report.linkedTypeNames.isEmpty)
#endif
    }
}

private struct ImporterStub: AudioImporting {
    func importAudio(from request: ImportRequest) async throws -> LocalAudioAsset {
        throw DomainFailure.accessDenied
    }
}

private struct SeparatorStub: SourceSeparationProviding {
    func start(_ request: SeparationRequest) async throws -> ProcessingJobID { ProcessingJobID() }

    func snapshot(jobID: ProcessingJobID) async throws -> ProcessingSnapshot {
        ProcessingSnapshot(jobID: jobID, phase: .queued, fractionComplete: 0)
    }

    func result(jobID: ProcessingJobID) async throws -> [StemArtifact] { [] }

    func cancel(jobID: ProcessingJobID) async {}
}

private struct PlaybackStub: PlaybackPreparing {
    func prepareSource(projectID: ProjectID, asset: LocalAudioAsset) async throws {}
    func replaceWithStems(projectID: ProjectID, stems: [StemArtifact]) async throws {}
}

private struct AnalysisStub: MusicAnalyzing {
    func analyze(projectID: ProjectID, asset: LocalAudioAsset) async throws -> AnalysisSnapshot {
        AnalysisSnapshot(tempo: nil, key: nil, chords: [], sections: [])
    }
}

private struct PersistenceStub: ProjectPersisting {
    func createProject(source: LocalAudioAsset) async throws -> ProjectID { ProjectID() }
    func recordProcessing(projectID: ProjectID, snapshot: ProcessingSnapshot) async throws {}
    func recordStems(projectID: ProjectID, stems: [StemArtifact]) async throws {}
}

private struct ExporterStub: AudioExporting {
    func export(_ request: ExportRequest) async throws -> [ExportArtifact] { [] }
}

private struct DSPStub: PracticeDSPConfiguring {
    func setTempoRatio(_ ratio: Double, projectID: ProjectID) async throws {}
    func setPitchSemitones(_ semitones: Double, projectID: ProjectID) async throws {}
    func setMetronomeEnabled(_ enabled: Bool, projectID: ProjectID) async throws {}
    func scheduleCountIn(clicks: Int, projectID: ProjectID) async throws {}
}

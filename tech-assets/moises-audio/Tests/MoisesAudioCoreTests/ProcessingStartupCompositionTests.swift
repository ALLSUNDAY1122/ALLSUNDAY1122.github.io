import Foundation
import XCTest
@testable import MoisesAudioCore

final class ProcessingStartupCompositionTests: XCTestCase {
    func testRelaunchRecoveryInvokesConfiguredLane1RecoveryWithExactProjectID() async throws {
        let projectID = ProjectID(rawValue: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!)
        let jobID = ProcessingJobID(rawValue: UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!)
        let recovery = ProcessingRecoveryStub(action: .reconnect(jobID: jobID))
        let coordinator = makeCoordinator(processingRecovery: recovery)

        let action = try await coordinator.recoverProcessingAfterRelaunch(projectID: projectID)
        let recoveredProjectIDs = await recovery.recoveredProjectIDs
        let storedAction = await coordinator.processingRecoveryAction

        XCTAssertEqual(action, .reconnect(jobID: jobID))
        XCTAssertEqual(storedAction, action)
        XCTAssertEqual(recoveredProjectIDs, [projectID])
    }

    func testRelaunchRecoveryFailsClosedWhenRecoveryDependencyIsNotConfigured() async {
        let projectID = ProjectID(rawValue: UUID(uuidString: "cccccccc-cccc-cccc-cccc-cccccccccccc")!)
        let coordinator = makeCoordinator(processingRecovery: nil)

        do {
            _ = try await coordinator.recoverProcessingAfterRelaunch(projectID: projectID)
            XCTFail("expected fail-closed recovery configuration error")
        } catch let failure as DomainFailure {
            switch failure {
            case .processingFailed(let code, let retryable):
                XCTAssertEqual(code, "PROC_RECOVERY_NOT_CONFIGURED")
                XCTAssertFalse(retryable)
            default:
                XCTFail("unexpected DomainFailure: \(failure)")
            }
        } catch {
            XCTFail("unexpected error: \(error)")
        }

        let storedAction = await coordinator.processingRecoveryAction
        XCTAssertNil(storedAction)
    }

    private func makeCoordinator(
        processingRecovery: (any ProcessingAppRelaunchRecovering)?
    ) -> VerticalSliceCoordinator {
        VerticalSliceCoordinator(
            importer: StartupImporterStub(),
            separator: StartupSeparatorStub(),
            playback: StartupPlaybackStub(),
            analysisEngine: StartupAnalysisStub(),
            persistence: StartupPersistenceStub(),
            exporter: StartupExporterStub(),
            processingRecovery: processingRecovery
        )
    }
}

private actor ProcessingRecoveryStub: ProcessingAppRelaunchRecovering {
    let action: ProcessingRecoveryAction
    private(set) var recoveredProjectIDs: [ProjectID] = []

    init(action: ProcessingRecoveryAction) {
        self.action = action
    }

    func recover(projectID: ProjectID) async throws -> ProcessingRecoveryAction {
        recoveredProjectIDs.append(projectID)
        return action
    }
}

private actor StartupImporterStub: AudioImporting {
    func importAudio(from request: ImportRequest) async throws -> LocalAudioAsset {
        throw DomainFailure.processingFailed(code: "TEST_UNUSED_IMPORT", retryable: false)
    }
}

private actor StartupSeparatorStub: SourceSeparationProviding {
    func start(_ request: SeparationRequest) async throws -> ProcessingJobID {
        throw DomainFailure.processingFailed(code: "TEST_UNUSED_START", retryable: false)
    }

    func snapshot(jobID: ProcessingJobID) async throws -> ProcessingSnapshot {
        throw DomainFailure.processingFailed(code: "TEST_UNUSED_SNAPSHOT", retryable: false)
    }

    func result(jobID: ProcessingJobID) async throws -> [StemArtifact] { [] }
    func cancel(jobID: ProcessingJobID) async {}
}

private actor StartupPlaybackStub: PlaybackPreparing {
    func prepareSource(projectID: ProjectID, asset: LocalAudioAsset) async throws {}
    func replaceWithStems(projectID: ProjectID, stems: [StemArtifact]) async throws {}
}

private actor StartupAnalysisStub: MusicAnalyzing {
    func analyze(projectID: ProjectID, asset: LocalAudioAsset) async throws -> AnalysisSnapshot {
        AnalysisSnapshot(tempo: nil, key: nil, chords: [], sections: [])
    }
}

private actor StartupPersistenceStub: ProjectPersisting {
    func createProject(source: LocalAudioAsset) async throws -> ProjectID {
        ProjectID(rawValue: UUID())
    }

    func recordProcessing(projectID: ProjectID, snapshot: ProcessingSnapshot) async throws {}
    func recordStems(projectID: ProjectID, stems: [StemArtifact]) async throws {}
}

private actor StartupExporterStub: AudioExporting {
    func export(_ request: ExportRequest) async throws -> [ExportArtifact] { [] }
}

import Foundation
import XCTest
@testable import MoisesAudioCore

final class DomainContractCoordinatorTests: XCTestCase {
    func testProcessingSnapshotCodableRoundTripPreservesStableState() throws {
        let jobID = ProcessingJobID(rawValue: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!)
        let snapshot = ProcessingSnapshot(
            jobID: jobID,
            phase: .failed,
            fractionComplete: 0.75,
            retryable: true,
            stableErrorCode: "NETWORK_TIMEOUT"
        )

        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(ProcessingSnapshot.self, from: data)
        XCTAssertEqual(decoded, snapshot)
    }

    func testImportSourceCreatesProjectPreparesSourceAndRoutesToSeparationSelection() async throws {
        let fixture = Fixture()
        let coordinator = fixture.makeCoordinator()

        let returnedID = try await coordinator.importSource(.appOwnedFile(relativePath: "imports/song.m4a"))
        let route = await coordinator.route
        let project = await coordinator.project
        let prepared = await fixture.playback.preparedProjectID

        XCTAssertEqual(returnedID, fixture.projectID)
        XCTAssertEqual(route, .separationSelection(fixture.projectID))
        XCTAssertEqual(project?.projectID, fixture.projectID)
        XCTAssertEqual(project?.playbackReadiness, .sourceOnly)
        XCTAssertEqual(prepared, fixture.projectID)
    }

    func testStartSeparationPresentsProjectWhileStemsArePreparing() async throws {
        let fixture = Fixture()
        let coordinator = fixture.makeCoordinator()
        _ = try await coordinator.importSource(.appOwnedFile(relativePath: "imports/song.m4a"))

        let jobID = try await coordinator.startSeparation(
            asset: fixture.asset,
            roles: [.vocals, .drums, .bass, .other],
            qualityProfile: "standard"
        )
        let route = await coordinator.route
        let project = await coordinator.project
        let persisted = await fixture.persistence.lastProcessing

        XCTAssertEqual(jobID, fixture.jobID)
        XCTAssertEqual(route, .project(fixture.projectID))
        XCTAssertEqual(project?.processing, fixture.separatingSnapshot)
        XCTAssertEqual(project?.playbackReadiness, .stemsPreparing)
        XCTAssertEqual(persisted, fixture.separatingSnapshot)
    }

    func testRefreshReadyReplacesStemsPersistsArtifactsAndMarksReady() async throws {
        let fixture = Fixture()
        let coordinator = fixture.makeCoordinator()
        _ = try await coordinator.importSource(.appOwnedFile(relativePath: "imports/song.m4a"))
        _ = try await coordinator.startSeparation(asset: fixture.asset, roles: [.vocals, .other], qualityProfile: "standard")
        await fixture.separator.setSnapshot(fixture.readySnapshot)

        try await coordinator.refreshProcessing(jobID: fixture.jobID)
        let project = await coordinator.project
        let replaced = await fixture.playback.replacedStems
        let persisted = await fixture.persistence.lastStems

        XCTAssertEqual(project?.processing, fixture.readySnapshot)
        XCTAssertEqual(project?.playbackReadiness, .stemsReady(fixture.stems))
        XCTAssertEqual(replaced, fixture.stems)
        XCTAssertEqual(persisted, fixture.stems)
    }

    func testRefreshFailedKeepsProjectVisibleAndMarksPlaybackUnavailable() async throws {
        let fixture = Fixture()
        let coordinator = fixture.makeCoordinator()
        _ = try await coordinator.importSource(.appOwnedFile(relativePath: "imports/song.m4a"))
        _ = try await coordinator.startSeparation(asset: fixture.asset, roles: [.vocals, .other], qualityProfile: "standard")
        let failed = ProcessingSnapshot(
            jobID: fixture.jobID,
            phase: .failed,
            fractionComplete: 0.4,
            retryable: true,
            stableErrorCode: "SEPARATION_BACKEND_TIMEOUT"
        )
        await fixture.separator.setSnapshot(failed)

        try await coordinator.refreshProcessing(jobID: fixture.jobID)
        let route = await coordinator.route
        let project = await coordinator.project

        XCTAssertEqual(route, .project(fixture.projectID))
        XCTAssertEqual(project?.processing, failed)
        XCTAssertEqual(project?.playbackReadiness, .unavailable(stableErrorCode: "SEPARATION_BACKEND_TIMEOUT"))
    }
}

private struct Fixture {
    let projectID: ProjectID
    let jobID: ProcessingJobID
    let asset: LocalAudioAsset
    let separatingSnapshot: ProcessingSnapshot
    let readySnapshot: ProcessingSnapshot
    let stems: [StemArtifact]
    let importer: ImporterStub
    let separator: SeparatorStub
    let playback: PlaybackStub
    let analysis: AnalysisStub
    let persistence: PersistenceStub
    let exporter: ExporterStub

    init() {
        let projectID = ProjectID(rawValue: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!)
        let jobID = ProcessingJobID(rawValue: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!)
        let asset = LocalAudioAsset(
            id: AssetID(rawValue: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!),
            relativePath: "imports/song.m4a",
            mediaKind: .audio,
            durationSeconds: 120
        )
        let separatingSnapshot = ProcessingSnapshot(jobID: jobID, phase: .separating, fractionComplete: 0.25)
        let readySnapshot = ProcessingSnapshot(jobID: jobID, phase: .ready, fractionComplete: 1)
        let stems = [
            StemArtifact(
                id: StemID(rawValue: UUID(uuidString: "55555555-5555-5555-5555-555555555555")!),
                projectID: projectID,
                role: .vocals,
                relativePath: "stems/vocals.m4a",
                sampleRate: 44_100,
                channels: 2,
                frameCount: 5_292_000
            ),
            StemArtifact(
                id: StemID(rawValue: UUID(uuidString: "66666666-6666-6666-6666-666666666666")!),
                projectID: projectID,
                role: .other,
                relativePath: "stems/other.m4a",
                sampleRate: 44_100,
                channels: 2,
                frameCount: 5_292_000
            )
        ]
        self.projectID = projectID
        self.jobID = jobID
        self.asset = asset
        self.separatingSnapshot = separatingSnapshot
        self.readySnapshot = readySnapshot
        self.stems = stems
        self.importer = ImporterStub(asset: asset)
        self.separator = SeparatorStub(jobID: jobID, snapshot: separatingSnapshot, stems: stems)
        self.playback = PlaybackStub()
        self.analysis = AnalysisStub()
        self.persistence = PersistenceStub(projectID: projectID)
        self.exporter = ExporterStub()
    }

    func makeCoordinator() -> VerticalSliceCoordinator {
        VerticalSliceCoordinator(
            importer: importer,
            separator: separator,
            playback: playback,
            analysisEngine: analysis,
            persistence: persistence,
            exporter: exporter
        )
    }
}

private actor ImporterStub: AudioImporting {
    let asset: LocalAudioAsset
    init(asset: LocalAudioAsset) { self.asset = asset }
    func importAudio(from request: ImportRequest) async throws -> LocalAudioAsset { asset }
}

private actor SeparatorStub: SourceSeparationProviding {
    let jobID: ProcessingJobID
    private var currentSnapshot: ProcessingSnapshot
    let stems: [StemArtifact]

    init(jobID: ProcessingJobID, snapshot: ProcessingSnapshot, stems: [StemArtifact]) {
        self.jobID = jobID
        self.currentSnapshot = snapshot
        self.stems = stems
    }

    func start(_ request: SeparationRequest) async throws -> ProcessingJobID { jobID }
    func snapshot(jobID: ProcessingJobID) async throws -> ProcessingSnapshot { currentSnapshot }
    func result(jobID: ProcessingJobID) async throws -> [StemArtifact] { stems }
    func cancel(jobID: ProcessingJobID) async {}
    func setSnapshot(_ snapshot: ProcessingSnapshot) { currentSnapshot = snapshot }
}

private actor PlaybackStub: PlaybackPreparing {
    private(set) var preparedProjectID: ProjectID?
    private(set) var replacedStems: [StemArtifact] = []

    func prepareSource(projectID: ProjectID, asset: LocalAudioAsset) async throws { preparedProjectID = projectID }
    func replaceWithStems(projectID: ProjectID, stems: [StemArtifact]) async throws { replacedStems = stems }
}

private actor AnalysisStub: MusicAnalyzing {
    func analyze(projectID: ProjectID, asset: LocalAudioAsset) async throws -> AnalysisSnapshot {
        AnalysisSnapshot(tempo: nil, key: nil, chords: [], sections: [])
    }
}

private actor PersistenceStub: ProjectPersisting {
    let projectID: ProjectID
    private(set) var lastProcessing: ProcessingSnapshot?
    private(set) var lastStems: [StemArtifact] = []

    init(projectID: ProjectID) { self.projectID = projectID }
    func createProject(source: LocalAudioAsset) async throws -> ProjectID { projectID }
    func recordProcessing(projectID: ProjectID, snapshot: ProcessingSnapshot) async throws { lastProcessing = snapshot }
    func recordStems(projectID: ProjectID, stems: [StemArtifact]) async throws { lastStems = stems }
}

private actor ExporterStub: AudioExporting {
    func export(_ request: ExportRequest) async throws -> [ExportArtifact] { [] }
}

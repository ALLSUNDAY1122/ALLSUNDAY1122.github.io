import Foundation
import XCTest

#if canImport(CoreData)
import CoreData

#if canImport(MoisesAudioCore)
import MoisesAudioCore
#endif

final class CoreDataProjectLibraryStoreTests: XCTestCase {
    func testProjectRoundTripPersistsSourceProcessingStemsAndEdits() async throws {
        let store = try CoreDataProjectLibraryStore(configuration: .init(inMemory: true))
        let source = makeSource()
        let projectID = try await store.createProject(source: source)
        let jobID = ProcessingJobID()
        let processing = ProcessingSnapshot(jobID: jobID, phase: .separating, fractionComplete: 0.45, retryable: true)
        try await store.recordProcessing(projectID: projectID, snapshot: processing)

        let vocals = makeStem(projectID: projectID, role: .vocals, name: "vocals")
        let drums = makeStem(projectID: projectID, role: .drums, name: "drums")
        try await store.recordStems(projectID: projectID, stems: [vocals, drums])

        let edits = ProjectUserEdits(
            schemaVersion: 1,
            tempoRatio: 0.85,
            pitchSemitones: 2,
            metronomeEnabled: true,
            countInClicks: 4,
            loopStartSeconds: 12,
            loopEndSeconds: 36,
            stemMix: [
                StemMixEdit(stemID: vocals.id, gain: 0.4, isMuted: false, isSoloed: true),
                StemMixEdit(stemID: drums.id, gain: 0.8, isMuted: true, isSoloed: false)
            ]
        )
        try await store.saveUserEdits(projectID: projectID, edits: edits)

        let loaded = try XCTUnwrap(await store.loadProject(projectID: projectID))
        XCTAssertEqual(loaded.projectID, projectID)
        XCTAssertEqual(loaded.source, source)
        XCTAssertEqual(loaded.processing, processing)
        XCTAssertEqual(Set(loaded.stems.map(\.id)), Set([vocals.id, drums.id]))
        XCTAssertEqual(loaded.edits, edits)
        XCTAssertEqual(try await store.listProjects().count, 1)
    }

    func testSQLiteStoreReopensAndPreservesProjectAndSetlist() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let storeURL = root.appendingPathComponent("Library.sqlite")
        defer { try? FileManager.default.removeItem(at: root) }

        var projectID: ProjectID!
        var setlistID: SetlistID!
        do {
            let first = try CoreDataProjectLibraryStore(configuration: .init(storeURL: storeURL))
            projectID = try await first.createProject(source: makeSource())
            try await first.recordProcessing(
                projectID: projectID,
                snapshot: ProcessingSnapshot(jobID: ProcessingJobID(), phase: .uploading, fractionComplete: 0.3)
            )
            setlistID = try await first.createSetlist(name: "Practice")
            try await first.replaceSetlistEntries(setlistID: setlistID, orderedProjectIDs: [projectID])
        }

        let reopened = try CoreDataProjectLibraryStore(configuration: .init(storeURL: storeURL))
        let loaded = try XCTUnwrap(await reopened.loadProject(projectID: projectID))
        XCTAssertEqual(loaded.projectID, projectID)
        XCTAssertEqual(try await reopened.recoveryPlan(projectID: projectID), .resume(jobID: try XCTUnwrap(loaded.processing?.jobID)))
        let setlists = try await reopened.listSetlists()
        XCTAssertEqual(setlists.count, 1)
        XCTAssertEqual(setlists.first?.id, setlistID)
        XCTAssertEqual(setlists.first?.entries.map(\.projectID), [projectID])
    }

    func testSetlistCreateRenameReplaceOrderAndDelete() async throws {
        let store = try CoreDataProjectLibraryStore(configuration: .init(inMemory: true))
        let first = try await store.createProject(source: makeSource(path: "Imports/a/song.m4a"))
        let second = try await store.createProject(source: makeSource(path: "Imports/b/song.m4a"))
        let setlistID = try await store.createSetlist(name: "  Rehearsal  ")
        try await store.replaceSetlistEntries(setlistID: setlistID, orderedProjectIDs: [second, first, second])
        try await store.renameSetlist(setlistID: setlistID, name: "Live")

        let snapshot = try XCTUnwrap((try await store.listSetlists()).first)
        XCTAssertEqual(snapshot.name, "Live")
        XCTAssertEqual(snapshot.entries.map(\.projectID), [second, first, second])
        XCTAssertEqual(snapshot.entries.map(\.position), [0, 1, 2])
        XCTAssertEqual(Set(snapshot.entries.map(\.id)).count, 3)

        try await store.deleteSetlist(setlistID: setlistID)
        try await store.deleteSetlist(setlistID: setlistID)
        XCTAssertTrue(try await store.listSetlists().isEmpty)
    }

    func testInvalidPathCrossProjectStemAndAssetIdentityConflictAreRejected() async throws {
        let store = try CoreDataProjectLibraryStore(configuration: .init(inMemory: true))
        let badSource = makeSource(path: "../escape.m4a")
        await XCTAssertThrowsErrorAsync { _ = try await store.createProject(source: badSource) }

        let source = makeSource()
        let projectID = try await store.createProject(source: source)
        let otherProject = ProjectID()
        let foreignStem = makeStem(projectID: otherProject, role: .vocals, name: "foreign")
        await XCTAssertThrowsErrorAsync { try await store.recordStems(projectID: projectID, stems: [foreignStem]) }
        XCTAssertTrue(try XCTUnwrap(await store.loadProject(projectID: projectID)).stems.isEmpty)

        let conflicting = LocalAudioAsset(
            id: source.id,
            relativePath: "Imports/different/song.m4a",
            mediaKind: source.mediaKind,
            durationSeconds: source.durationSeconds
        )
        await XCTAssertThrowsErrorAsync { _ = try await store.createProject(source: conflicting) }
    }

    func testRecoveryPlanUpdatesAcrossInterruptedFailedAndReadyStates() async throws {
        let store = try CoreDataProjectLibraryStore(configuration: .init(inMemory: true))
        let projectID = try await store.createProject(source: makeSource())
        let jobID = ProcessingJobID()

        try await store.recordProcessing(
            projectID: projectID,
            snapshot: ProcessingSnapshot(jobID: jobID, phase: .finalizing, fractionComplete: 0.9)
        )
        XCTAssertEqual(try await store.recoveryPlan(projectID: projectID), .resume(jobID: jobID))

        try await store.recordProcessing(
            projectID: projectID,
            snapshot: ProcessingSnapshot(jobID: jobID, phase: .failed, fractionComplete: 0.9, retryable: true, stableErrorCode: "NETWORK_TIMEOUT")
        )
        XCTAssertEqual(try await store.recoveryPlan(projectID: projectID), .retryRequired(stableErrorCode: "NETWORK_TIMEOUT"))

        try await store.recordProcessing(
            projectID: projectID,
            snapshot: ProcessingSnapshot(jobID: jobID, phase: .ready, fractionComplete: 1)
        )
        XCTAssertEqual(try await store.recoveryPlan(projectID: projectID), .none)
    }

    func testDeleteProjectIsIdempotentAndCompactsSetlistPositions() async throws {
        let store = try CoreDataProjectLibraryStore(configuration: .init(inMemory: true))
        let first = try await store.createProject(source: makeSource(path: "Imports/first/song.m4a"))
        let second = try await store.createProject(source: makeSource(path: "Imports/second/song.m4a"))
        let setlistID = try await store.createSetlist(name: "Practice")
        try await store.replaceSetlistEntries(setlistID: setlistID, orderedProjectIDs: [first, second])

        try await store.deleteProject(projectID: first)
        try await store.deleteProject(projectID: first)

        XCTAssertNil(try await store.loadProject(projectID: first))
        XCTAssertEqual(try await store.listProjects().map(\.projectID), [second])
        let setlist = try XCTUnwrap((try await store.listSetlists()).first)
        XCTAssertEqual(setlist.entries.map(\.projectID), [second])
        XCTAssertEqual(setlist.entries.map(\.position), [0])
    }

    private func makeSource(path: String = "Imports/source/song.m4a") -> LocalAudioAsset {
        LocalAudioAsset(id: AssetID(), relativePath: path, mediaKind: .audio, durationSeconds: 120)
    }

    private func makeStem(projectID: ProjectID, role: StemRole, name: String) -> StemArtifact {
        StemArtifact(
            id: StemID(),
            projectID: projectID,
            role: role,
            relativePath: "Stems/\(projectID.rawValue.uuidString)/\(name).m4a",
            sampleRate: 44_100,
            channels: 2,
            frameCount: 5_292_000,
            startTimeSeconds: 0
        )
    }
}

private func XCTAssertThrowsErrorAsync(
    _ operation: () async throws -> Void,
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    do {
        try await operation()
        XCTFail("Expected error", file: file, line: line)
    } catch {
        // Expected.
    }
}
#endif

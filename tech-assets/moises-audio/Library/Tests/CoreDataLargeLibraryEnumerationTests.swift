import Foundation
import XCTest

#if canImport(CoreData)
import CoreData

#if canImport(MoisesAudioCore)
import MoisesAudioCore
#endif

final class CoreDataLargeLibraryEnumerationTests: XCTestCase {
    func testProjectEnumerationAcrossManyBatchesPreservesCompleteSnapshots() async throws {
        let store = try CoreDataProjectLibraryStore(
            configuration: .init(inMemory: true, enumerationBatchSize: 17)
        )

        var projectIDs: [ProjectID] = []
        projectIDs.reserveCapacity(257)
        for index in 0..<257 {
            let source = LocalAudioAsset(
                id: AssetID(),
                relativePath: "Imports/large/\(index)/source.m4a",
                mediaKind: .audio,
                durationSeconds: Double(index + 1)
            )
            projectIDs.append(try await store.createProject(source: source))
        }

        for index in [0, 128, 256] {
            let projectID = projectIDs[index]
            let stem = StemArtifact(
                id: StemID(),
                projectID: projectID,
                role: .vocals,
                relativePath: "Stems/\(projectID.rawValue.uuidString)/vocals.m4a",
                sampleRate: 44_100,
                channels: 2,
                frameCount: 44_100,
                startTimeSeconds: 0
            )
            try await store.recordProcessing(
                projectID: projectID,
                snapshot: ProcessingSnapshot(
                    jobID: ProcessingJobID(),
                    phase: .ready,
                    fractionComplete: 1
                )
            )
            try await store.recordStems(projectID: projectID, stems: [stem])
            try await store.saveUserEdits(
                projectID: projectID,
                edits: ProjectUserEdits(
                    schemaVersion: 1,
                    tempoRatio: 1,
                    pitchSemitones: 0,
                    metronomeEnabled: false,
                    countInClicks: 0,
                    loopStartSeconds: nil,
                    loopEndSeconds: nil,
                    stemMix: [StemMixEdit(stemID: stem.id, gain: 1, isMuted: false, isSoloed: false)]
                )
            )
        }

        let snapshots = try await store.listProjects()
        XCTAssertEqual(snapshots.count, 257)
        XCTAssertEqual(Set(snapshots.map(\.projectID)), Set(projectIDs))

        for index in [0, 128, 256] {
            let snapshot = try XCTUnwrap(snapshots.first { $0.projectID == projectIDs[index] })
            XCTAssertEqual(snapshot.processing?.phase, .ready)
            XCTAssertEqual(snapshot.stems.count, 1)
            XCTAssertEqual(snapshot.edits?.stemMix.count, 1)
        }

        try await store.deleteProject(projectID: projectIDs[128])
        let afterDelete = try await store.listProjects()
        XCTAssertEqual(afterDelete.count, 256)
        XCTAssertFalse(afterDelete.contains { $0.projectID == projectIDs[128] })
    }

    func testSetlistEnumerationBatchesEntriesWithoutChangingEntryOrder() async throws {
        let store = try CoreDataProjectLibraryStore(
            configuration: .init(inMemory: true, enumerationBatchSize: 17)
        )
        let first = try await store.createProject(
            source: LocalAudioAsset(id: AssetID(), relativePath: "Imports/setlists/a.m4a", mediaKind: .audio, durationSeconds: 1)
        )
        let second = try await store.createProject(
            source: LocalAudioAsset(id: AssetID(), relativePath: "Imports/setlists/b.m4a", mediaKind: .audio, durationSeconds: 1)
        )

        var setlistIDs: [SetlistID] = []
        for index in 0..<70 {
            let id = try await store.createSetlist(name: "Set \(index)")
            try await store.replaceSetlistEntries(setlistID: id, orderedProjectIDs: [second, first, second])
            setlistIDs.append(id)
        }

        let snapshots = try await store.listSetlists()
        XCTAssertEqual(snapshots.count, 70)
        XCTAssertEqual(Set(snapshots.map(\.id)), Set(setlistIDs))
        for snapshot in snapshots {
            XCTAssertEqual(snapshot.entries.map(\.projectID), [second, first, second])
            XCTAssertEqual(snapshot.entries.map(\.position), [0, 1, 2])
        }
    }

    func testEnumerationBatchSizeIsClampedBeforeCoreDataUse() {
        XCTAssertEqual(CoreDataProjectLibraryStore.Configuration(inMemory: true, enumerationBatchSize: 0).enumerationPolicy.batchSize, 16)
        XCTAssertEqual(CoreDataProjectLibraryStore.Configuration(inMemory: true, enumerationBatchSize: 4_096).enumerationPolicy.batchSize, 1024)
    }
}
#endif

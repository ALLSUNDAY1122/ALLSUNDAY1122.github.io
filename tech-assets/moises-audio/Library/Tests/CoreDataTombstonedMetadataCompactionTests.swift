import Foundation
import XCTest

#if canImport(CoreData)
import CoreData

#if canImport(MoisesAudioCore)
import MoisesAudioCore
#endif

final class CoreDataTombstonedMetadataCompactionTests: XCTestCase {
    func testCompactionRemovesProjectChildrenButRetainsSharedAsset() async throws {
        let store = try CoreDataProjectLibraryStore(configuration: .init(inMemory: true))
        let source = LocalAudioAsset(
            id: AssetID(),
            relativePath: "Imports/shared/source.m4a",
            mediaKind: .audio,
            durationSeconds: 90
        )
        let first = try await store.createProject(source: source)
        let second = try await store.createProject(source: source)
        try await store.recordProcessing(
            projectID: first,
            snapshot: ProcessingSnapshot(
                jobID: ProcessingJobID(),
                phase: .separating,
                fractionComplete: 0.5
            )
        )
        let stem = StemArtifact(
            id: StemID(),
            projectID: first,
            role: .vocals,
            relativePath: "Stems/\(first.rawValue.uuidString)/vocals.m4a",
            sampleRate: 44_100,
            channels: 2,
            frameCount: 4_000,
            startTimeSeconds: 0
        )
        try await store.recordStems(projectID: first, stems: [stem])
        try await store.deleteProject(projectID: first)

        let result = try await store.compactTombstonedProject(projectID: first)
        XCTAssertTrue(result.projectRecordRemoved)
        XCTAssertEqual(result.processingRecordsRemoved, 1)
        XCTAssertEqual(result.stemRecordsRemoved, 1)
        XCTAssertTrue(result.sourceAssetRecordRetained)
        XCTAssertFalse(result.sourceAssetRecordRemoved)
        XCTAssertNotNil(try await store.loadProject(projectID: second))
        XCTAssertFalse(try await store.listTombstonedProjectCompactionCandidates().contains { $0.projectUUID == first.rawValue })
    }

    func testHistoricalTombstoneWithoutJournalBackfillsAndConverges() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("AW21-Historical-" + UUID().uuidString, isDirectory: true)
        let artifactRoot = root.appendingPathComponent("Artifacts", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let source = LocalAudioAsset(
            id: AssetID(),
            relativePath: "Imports/historical/source.m4a",
            mediaKind: .audio,
            durationSeconds: 90
        )
        try writeArtifact(source.relativePath, under: artifactRoot)
        let raw = try CoreDataProjectLibraryStore(configuration: .init(inMemory: true))
        let projectID = try await raw.createProject(source: source)
        try await raw.deleteProject(projectID: projectID)

        let store = try CrashSafeProjectLibraryStore(metadata: raw, artifactRootURL: artifactRoot)
        let report = try await store.recoverInterruptedOperations()

        XCTAssertTrue(report.completedCommitted.contains(projectID))
        XCTAssertFalse(FileManager.default.fileExists(atPath: artifactRoot.appendingPathComponent(source.relativePath).path))
        XCTAssertTrue(try await raw.listTombstonedProjectCompactionCandidates().isEmpty)
        XCTAssertTrue(try LibraryArtifactLifecycle(rootURL: artifactRoot).pendingDeletionJournals().isEmpty)
    }

    func testArtifactsDeletedJournalResumesMetadataCompaction() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("AW21-ArtifactDeleted-" + UUID().uuidString, isDirectory: true)
        let artifactRoot = root.appendingPathComponent("Artifacts", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let source = LocalAudioAsset(
            id: AssetID(),
            relativePath: "Imports/interrupted/source.m4a",
            mediaKind: .audio,
            durationSeconds: 90
        )
        try writeArtifact(source.relativePath, under: artifactRoot)
        let raw = try CoreDataProjectLibraryStore(configuration: .init(inMemory: true))
        let projectID = try await raw.createProject(source: source)
        let lifecycle = LibraryArtifactLifecycle(rootURL: artifactRoot)
        try lifecycle.persistPreparedDeletion(projectUUID: projectID.rawValue, relativePaths: [source.relativePath])
        try await raw.deleteProject(projectID: projectID)
        try lifecycle.markDeletionCommitted(projectUUID: projectID.rawValue)
        try lifecycle.executeCommittedDeletion(projectUUID: projectID.rawValue)
        XCTAssertEqual(try lifecycle.pendingDeletionJournals().first?.phase, .artifactsDeleted)

        let store = try CrashSafeProjectLibraryStore(metadata: raw, artifactRootURL: artifactRoot)
        let report = try await store.recoverInterruptedOperations()

        XCTAssertTrue(report.completedCommitted.contains(projectID))
        XCTAssertTrue(try await raw.listTombstonedProjectCompactionCandidates().isEmpty)
        XCTAssertTrue(try lifecycle.pendingDeletionJournals().isEmpty)
    }

    private func writeArtifact(_ relativePath: String, under root: URL) throws {
        let url = root.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("artifact".utf8).write(to: url)
    }
}
#endif

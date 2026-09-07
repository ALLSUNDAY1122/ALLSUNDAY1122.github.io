import Foundation
import XCTest

#if canImport(CoreData)
#if canImport(MoisesAudioCore)
import MoisesAudioCore
#endif

final class DeletionOwnershipRecoveryTests: XCTestCase {
    func testOwnershipWithoutJournalIsDiscardedWhenProjectIsStillLive() async throws {
        try await withEnvironment { storeURL, artifactRoot in
            let raw = try CoreDataProjectLibraryStore(configuration: .init(storeURL: storeURL))
            let store = try CrashSafeProjectLibraryStore(metadata: raw, artifactRootURL: artifactRoot)
            let source = makeSource(path: "Imports/live/source.m4a")
            try writeArtifact(source.relativePath, under: artifactRoot)
            let projectID = try await store.createProject(source: source)

            let index = Lane2DeletionOwnershipIndex(rootURL: artifactRoot)
            try index.persist(try Lane2DeletionOwnershipRecord(
                projectUUID: projectID.rawValue,
                sourceAssetUUID: source.id.rawValue,
                artifactRelativePaths: [source.relativePath]
            ))

            _ = try await store.recoverInterruptedOperations()

            XCTAssertNotNil(try await store.loadProject(projectID: projectID))
            XCTAssertNil(try index.record(projectUUID: projectID.rawValue))
            XCTAssertTrue(FileManager.default.fileExists(atPath: artifactRoot.appendingPathComponent(source.relativePath).path))
        }
    }

    func testIndexedPreparedTombstoneRecoversWithoutLegacyCandidateDependency() async throws {
        try await withEnvironment { storeURL, artifactRoot in
            let raw = try CoreDataProjectLibraryStore(configuration: .init(storeURL: storeURL))
            let store = try CrashSafeProjectLibraryStore(metadata: raw, artifactRootURL: artifactRoot)
            let source = makeSource(path: "Imports/interrupted/source.m4a")
            try writeArtifact(source.relativePath, under: artifactRoot)
            let projectID = try await store.createProject(source: source)

            let index = Lane2DeletionOwnershipIndex(rootURL: artifactRoot)
            try index.markLegacyScanComplete()
            try index.persist(try Lane2DeletionOwnershipRecord(
                projectUUID: projectID.rawValue,
                sourceAssetUUID: source.id.rawValue,
                artifactRelativePaths: [source.relativePath]
            ))
            let lifecycle = LibraryArtifactLifecycle(rootURL: artifactRoot)
            try lifecycle.persistPreparedDeletion(
                projectUUID: projectID.rawValue,
                relativePaths: [source.relativePath]
            )
            try await raw.deleteProject(projectID: projectID)
            // Simulated process death: ownership + PREPARED + tombstone are durable.

            _ = try await store.recoverInterruptedOperations()

            XCTAssertNil(try await raw.loadProject(projectID: projectID))
            XCTAssertFalse(FileManager.default.fileExists(atPath: artifactRoot.appendingPathComponent(source.relativePath).path))
            XCTAssertNil(try index.record(projectUUID: projectID.rawValue))
            XCTAssertTrue(try lifecycle.pendingDeletionJournals().isEmpty)
        }
    }

    private func withEnvironment(_ body: (URL, URL) async throws -> Void) async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("AW22-DeletionRecoveryTests-" + UUID().uuidString, isDirectory: true)
        let storeURL = root.appendingPathComponent("Metadata/Library.sqlite")
        let artifactRoot = root.appendingPathComponent("Artifacts", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try await body(storeURL, artifactRoot)
    }

    private func makeSource(path: String) -> LocalAudioAsset {
        LocalAudioAsset(id: AssetID(), relativePath: path, mediaKind: .audio, durationSeconds: 90)
    }

    private func writeArtifact(_ relativePath: String, under root: URL) throws {
        let url = root.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("artifact".utf8).write(to: url)
    }
}
#endif

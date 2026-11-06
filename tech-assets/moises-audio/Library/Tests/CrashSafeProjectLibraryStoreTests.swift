import Foundation
import XCTest

#if canImport(CoreData)
#if canImport(MoisesAudioCore)
import MoisesAudioCore
#endif

final class CrashSafeProjectLibraryStoreTests: XCTestCase {
    func testPreparedJournalWithLiveMetadataIsDiscardedOnReopen() async throws {
        try await withEnvironment { storeURL, artifactRoot in
            let source = makeSource(path: "Imports/live/source.m4a")
            try writeArtifact(source.relativePath, under: artifactRoot)
            var projectID: ProjectID!
            do {
                let raw = try CoreDataProjectLibraryStore(configuration: .init(storeURL: storeURL))
                projectID = try await raw.createProject(source: source)
                try LibraryArtifactLifecycle(rootURL: artifactRoot).persistPreparedDeletion(
                    projectUUID: projectID.rawValue,
                    relativePaths: [source.relativePath]
                )
            }

            let reopened = try await CrashSafeProjectLibraryStore.open(
                metadataConfiguration: .init(storeURL: storeURL),
                artifactRootURL: artifactRoot
            )
            let liveReloaded = try await reopened.loadProject(projectID: projectID)
            XCTAssertNotNil(liveReloaded)
            XCTAssertTrue(FileManager.default.fileExists(atPath: artifactRoot.appendingPathComponent(source.relativePath).path))
            XCTAssertTrue(try LibraryArtifactLifecycle(rootURL: artifactRoot).pendingDeletionJournals().isEmpty)
        }
    }

    func testPreparedJournalAfterTombstoneCompletesCleanupOnReopen() async throws {
        try await withEnvironment { storeURL, artifactRoot in
            let source = makeSource(path: "Imports/deleted/source.m4a")
            try writeArtifact(source.relativePath, under: artifactRoot)
            var projectID: ProjectID!
            do {
                let raw = try CoreDataProjectLibraryStore(configuration: .init(storeURL: storeURL))
                projectID = try await raw.createProject(source: source)
                let lifecycle = LibraryArtifactLifecycle(rootURL: artifactRoot)
                try lifecycle.persistPreparedDeletion(projectUUID: projectID.rawValue, relativePaths: [source.relativePath])
                try await raw.deleteProject(projectID: projectID)
                // Simulated process death: tombstone committed while journal is still PREPARED.
            }

            let reopened = try await CrashSafeProjectLibraryStore.open(
                metadataConfiguration: .init(storeURL: storeURL),
                artifactRootURL: artifactRoot
            )
            let deletedReloaded = try await reopened.loadProject(projectID: projectID)
            XCTAssertNil(deletedReloaded)
            XCTAssertFalse(FileManager.default.fileExists(atPath: artifactRoot.appendingPathComponent(source.relativePath).path))
            XCTAssertTrue(try LibraryArtifactLifecycle(rootURL: artifactRoot).pendingDeletionJournals().isEmpty)
        }
    }

    func testCommittedPartialCleanupResumesIdempotently() async throws {
        try await withEnvironment { storeURL, artifactRoot in
            let source = makeSource(path: "Imports/partial/source.m4a")
            try writeArtifact(source.relativePath, under: artifactRoot)
            var projectID: ProjectID!
            var stem: StemArtifact!
            do {
                let raw = try CoreDataProjectLibraryStore(configuration: .init(storeURL: storeURL))
                projectID = try await raw.createProject(source: source)
                stem = makeStem(projectID: projectID, path: "Stems/partial/vocals.m4a")
                try writeArtifact(stem.relativePath, under: artifactRoot)
                try await raw.recordStems(projectID: projectID, stems: [stem])
                let lifecycle = LibraryArtifactLifecycle(rootURL: artifactRoot)
                try lifecycle.persistPreparedDeletion(projectUUID: projectID.rawValue, relativePaths: [source.relativePath, stem.relativePath])
                try await raw.deleteProject(projectID: projectID)
                try lifecycle.markDeletionCommitted(projectUUID: projectID.rawValue)
                try FileManager.default.removeItem(at: artifactRoot.appendingPathComponent(source.relativePath))
                // Simulated process death after one file was removed.
            }

            let reopened = try await CrashSafeProjectLibraryStore.open(
                metadataConfiguration: .init(storeURL: storeURL),
                artifactRootURL: artifactRoot
            )
            let partialReloaded = try await reopened.loadProject(projectID: projectID)
            XCTAssertNil(partialReloaded)
            XCTAssertFalse(FileManager.default.fileExists(atPath: artifactRoot.appendingPathComponent(stem.relativePath).path))
            XCTAssertTrue(try LibraryArtifactLifecycle(rootURL: artifactRoot).pendingDeletionJournals().isEmpty)
            try await reopened.deleteProject(projectID: projectID)
        }
    }

    func testDeleteRetainsArtifactReferencedByAnotherLiveProject() async throws {
        try await withEnvironment { storeURL, artifactRoot in
            let source = makeSource(path: "Imports/shared/source.m4a")
            try writeArtifact(source.relativePath, under: artifactRoot)
            let raw = try CoreDataProjectLibraryStore(configuration: .init(storeURL: storeURL))
            let store = try CrashSafeProjectLibraryStore(metadata: raw, artifactRootURL: artifactRoot)
            let first = try await store.createProject(source: source)
            let second = try await store.createProject(source: source)

            try await store.deleteProject(projectID: first)

            let survivor = try await store.loadProject(projectID: second)
            XCTAssertNotNil(survivor)
            XCTAssertTrue(FileManager.default.fileExists(atPath: artifactRoot.appendingPathComponent(source.relativePath).path))
        }
    }

    func testMissingOrEmptyArtifactsNeverBecomeVisibleMetadata() async throws {
        try await withEnvironment { storeURL, artifactRoot in
            let raw = try CoreDataProjectLibraryStore(configuration: .init(storeURL: storeURL))
            let store = try CrashSafeProjectLibraryStore(metadata: raw, artifactRootURL: artifactRoot)
            let missing = makeSource(path: "Imports/missing/source.m4a")
            await XCTAssertThrowsErrorAsync { _ = try await store.createProject(source: missing) }
            let afterMissingCreate = try await store.listProjects()
            XCTAssertTrue(afterMissingCreate.isEmpty)

            let source = makeSource(path: "Imports/ready/source.m4a")
            try writeArtifact(source.relativePath, under: artifactRoot)
            let projectID = try await store.createProject(source: source)
            let missingStem = makeStem(projectID: projectID, path: "Stems/missing/vocals.m4a")
            await XCTAssertThrowsErrorAsync { try await store.recordStems(projectID: projectID, stems: [missingStem]) }
            let loadedOptional = try await store.loadProject(projectID: projectID)
            let loaded = try XCTUnwrap(loadedOptional)
            XCTAssertTrue(loaded.stems.isEmpty)
        }
    }

    private func withEnvironment(_ body: (URL, URL) async throws -> Void) async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("CrashSafeLibraryTests-" + UUID().uuidString, isDirectory: true)
        let storeURL = root.appendingPathComponent("Metadata/Library.sqlite")
        let artifactRoot = root.appendingPathComponent("Artifacts", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try await body(storeURL, artifactRoot)
    }

    private func makeSource(path: String) -> LocalAudioAsset {
        LocalAudioAsset(id: AssetID(), relativePath: path, mediaKind: .audio, durationSeconds: 90)
    }

    private func makeStem(projectID: ProjectID, path: String) -> StemArtifact {
        StemArtifact(
            id: StemID(),
            projectID: projectID,
            role: .vocals,
            relativePath: path,
            sampleRate: 44_100,
            channels: 2,
            frameCount: 4_000,
            startTimeSeconds: 0
        )
    }

    private func writeArtifact(_ relativePath: String, under root: URL) throws {
        let url = root.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("artifact".utf8).write(to: url)
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

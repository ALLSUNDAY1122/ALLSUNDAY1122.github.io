import Foundation
import XCTest

#if canImport(CoreData)
#if canImport(MoisesAudioCore)
import MoisesAudioCore
#endif

final class Lane2ForegroundDeleteTargetedCoreDataTests: XCTestCase {
    func testTargetedDeleteRetainsSharedSourceAndStemAndRemovesExclusiveStem() async throws {
        try await withEnvironment { storeURL, artifactRoot in
            let raw = try CoreDataProjectLibraryStore(configuration: .init(storeURL: storeURL))
            let resolver = Lane2CoreDataLiveArtifactReferenceResolver(storeURL: storeURL)
            let store = try CrashSafeProjectLibraryStore(
                metadata: raw,
                artifactRootURL: artifactRoot,
                liveReferenceResolver: resolver
            )

            let source = LocalAudioAsset(
                id: AssetID(),
                relativePath: "Imports/shared/source.m4a",
                mediaKind: .audio,
                durationSeconds: 60
            )
            try writeArtifact(source.relativePath, under: artifactRoot)
            let target = try await store.createProject(source: source)
            let survivor = try await store.createProject(source: source)

            let sharedStemPath = "Stems/shared/vocals.m4a"
            let exclusiveStemPath = "Stems/target/drums.m4a"
            try writeArtifact(sharedStemPath, under: artifactRoot)
            try writeArtifact(exclusiveStemPath, under: artifactRoot)
            try await store.recordStems(projectID: target, stems: [
                stem(projectID: target, role: .vocals, path: sharedStemPath),
                stem(projectID: target, role: .drums, path: exclusiveStemPath)
            ])
            try await store.recordStems(projectID: survivor, stems: [
                stem(projectID: survivor, role: .vocals, path: sharedStemPath)
            ])

            let referenceSnapshot = try await resolver.resolveReferencesExcludingTarget(
                targetProjectUUID: target.rawValue,
                candidateArtifactPaths: [source.relativePath, sharedStemPath, exclusiveStemPath]
            )
            XCTAssertEqual(referenceSnapshot.liveReferencedArtifactPathsExcludingTarget, [
                source.relativePath,
                sharedStemPath
            ])
            XCTAssertEqual(referenceSnapshot.diagnostics.candidateArtifactPaths, 3)
            XCTAssertEqual(referenceSnapshot.diagnostics.sharedLiveArtifactPaths, 2)

            try await store.deleteProject(projectID: target)

            XCTAssertNil(try await store.loadProject(projectID: target))
            XCTAssertNotNil(try await store.loadProject(projectID: survivor))
            XCTAssertTrue(exists(source.relativePath, under: artifactRoot))
            XCTAssertTrue(exists(sharedStemPath, under: artifactRoot))
            XCTAssertFalse(exists(exclusiveStemPath, under: artifactRoot))
            XCTAssertTrue(try LibraryArtifactLifecycle(rootURL: artifactRoot).pendingDeletionJournals().isEmpty)
            XCTAssertNil(try Lane2DeletionOwnershipIndex(rootURL: artifactRoot).record(projectUUID: target.rawValue))
        }
    }

    func testMissingTargetDeleteIsIdempotentWithTargetedResolver() async throws {
        try await withEnvironment { storeURL, artifactRoot in
            let raw = try CoreDataProjectLibraryStore(configuration: .init(storeURL: storeURL))
            let store = try CrashSafeProjectLibraryStore(
                metadata: raw,
                artifactRootURL: artifactRoot,
                liveReferenceResolver: Lane2CoreDataLiveArtifactReferenceResolver(storeURL: storeURL)
            )
            try Lane2DeletionOwnershipIndex(rootURL: artifactRoot).markLegacyScanComplete()
            try await store.deleteProject(projectID: ProjectID())
            XCTAssertTrue(try LibraryArtifactLifecycle(rootURL: artifactRoot).pendingDeletionJournals().isEmpty)
        }
    }

    private func stem(projectID: ProjectID, role: StemRole, path: String) -> StemArtifact {
        StemArtifact(
            id: StemID(),
            projectID: projectID,
            role: role,
            relativePath: path,
            sampleRate: 44_100,
            channels: 2,
            frameCount: 4_000,
            startTimeSeconds: 0
        )
    }

    private func withEnvironment(_ body: (URL, URL) async throws -> Void) async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("AW27-TargetedDeleteTests-" + UUID().uuidString, isDirectory: true)
        let storeURL = root.appendingPathComponent("Metadata/Library.sqlite")
        let artifactRoot = root.appendingPathComponent("Artifacts", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: artifactRoot, withIntermediateDirectories: true)
        try await body(storeURL, artifactRoot)
    }

    private func writeArtifact(_ relativePath: String, under root: URL) throws {
        let url = root.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("artifact".utf8).write(to: url)
    }

    private func exists(_ relativePath: String, under root: URL) -> Bool {
        FileManager.default.fileExists(atPath: root.appendingPathComponent(relativePath).path)
    }
}
#endif

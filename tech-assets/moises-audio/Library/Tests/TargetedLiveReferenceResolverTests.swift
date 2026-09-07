import Foundation
import XCTest

#if canImport(CoreData)
#if canImport(MoisesAudioCore)
import MoisesAudioCore
#endif

final class Lane2TargetedLiveReferenceResolverTests: XCTestCase {
    func testResolverReturnsOnlyCandidateReferencesOwnedByLiveProjects() async throws {
        try await withEnvironment { storeURL, _ in
            let raw = try CoreDataProjectLibraryStore(configuration: .init(storeURL: storeURL))
            let sharedSource = LocalAudioAsset(
                id: AssetID(),
                relativePath: "Imports/shared/source.m4a",
                mediaKind: .audio,
                durationSeconds: 90
            )
            let liveID = try await raw.createProject(source: sharedSource)
            let tombstoneID = try await raw.createProject(source: sharedSource)
            let sharedStemPath = "Stems/shared/vocals.m4a"
            try await raw.recordStems(
                projectID: liveID,
                stems: [makeStem(projectID: liveID, path: sharedStemPath)]
            )
            try await raw.recordStems(
                projectID: tombstoneID,
                stems: [makeStem(projectID: tombstoneID, path: sharedStemPath)]
            )

            let exclusiveSource = LocalAudioAsset(
                id: AssetID(),
                relativePath: "Imports/exclusive/source.m4a",
                mediaKind: .audio,
                durationSeconds: 60
            )
            let exclusiveID = try await raw.createProject(source: exclusiveSource)
            let exclusiveStemPath = "Stems/exclusive/drums.m4a"
            try await raw.recordStems(
                projectID: exclusiveID,
                stems: [makeStem(projectID: exclusiveID, path: exclusiveStemPath)]
            )
            try await raw.deleteProject(projectID: tombstoneID)
            try await raw.deleteProject(projectID: exclusiveID)

            let resolver = Lane2CoreDataLiveArtifactReferenceResolver(storeURL: storeURL)
            let snapshot = try await resolver.resolve(
                targetProjectUUIDs: [liveID.rawValue, tombstoneID.rawValue, exclusiveID.rawValue],
                candidateArtifactPaths: [
                    sharedSource.relativePath,
                    sharedStemPath,
                    exclusiveSource.relativePath,
                    exclusiveStemPath,
                    "Imports/not-present/source.m4a"
                ]
            )

            XCTAssertEqual(snapshot.liveProjectUUIDs, [liveID.rawValue])
            XCTAssertEqual(
                snapshot.liveReferencedArtifactPaths,
                [sharedSource.relativePath, sharedStemPath]
            )
            XCTAssertTrue(snapshot.diagnostics.usedTargetedStoreQuery)
            XCTAssertEqual(snapshot.diagnostics.requestedProjectIDs, 3)
            XCTAssertEqual(snapshot.diagnostics.requestedArtifactPaths, 5)
            XCTAssertEqual(snapshot.diagnostics.liveArtifactPathsMatched, 2)
        }
    }

    func testCrashSafeRecoveryRetainsSharedSourceWithoutFullLiveProjection() async throws {
        try await withEnvironment { storeURL, artifactRoot in
            let raw = try CoreDataProjectLibraryStore(configuration: .init(storeURL: storeURL))
            let sharedSource = LocalAudioAsset(
                id: AssetID(),
                relativePath: "Imports/recovery-shared/source.m4a",
                mediaKind: .audio,
                durationSeconds: 120
            )
            try writeArtifact(sharedSource.relativePath, under: artifactRoot)
            _ = try await raw.createProject(source: sharedSource)
            let deletedID = try await raw.createProject(source: sharedSource)
            let deletedStem = "Stems/recovery-deleted/vocals.m4a"
            try writeArtifact(deletedStem, under: artifactRoot)
            try await raw.recordStems(
                projectID: deletedID,
                stems: [makeStem(projectID: deletedID, path: deletedStem)]
            )

            for index in 0..<128 {
                let source = LocalAudioAsset(
                    id: AssetID(),
                    relativePath: "Imports/unrelated-\(index)/source.m4a",
                    mediaKind: .audio,
                    durationSeconds: 30
                )
                _ = try await raw.createProject(source: source)
            }

            try await raw.deleteProject(projectID: deletedID)
            let index = Lane2DeletionOwnershipIndex(rootURL: artifactRoot)
            try index.markLegacyScanComplete()
            try index.persist(
                Lane2DeletionOwnershipRecord(
                    projectUUID: deletedID.rawValue,
                    sourceAssetUUID: sharedSource.id.rawValue,
                    artifactRelativePaths: [sharedSource.relativePath, deletedStem]
                )
            )

            let store = try CrashSafeProjectLibraryStore(
                metadata: raw,
                artifactRootURL: artifactRoot,
                ownershipOnlyRecoveryLimit: 8,
                liveReferenceResolver: Lane2CoreDataLiveArtifactReferenceResolver(storeURL: storeURL)
            )
            let report = try await store.recoverInterruptedOperations()

            XCTAssertTrue(FileManager.default.fileExists(
                atPath: artifactRoot.appendingPathComponent(sharedSource.relativePath).path
            ))
            XCTAssertFalse(FileManager.default.fileExists(
                atPath: artifactRoot.appendingPathComponent(deletedStem).path
            ))
            XCTAssertNil(try await raw.loadProject(projectID: deletedID))
            XCTAssertNil(try index.record(projectUUID: deletedID.rawValue))
            XCTAssertTrue(report.liveReferenceDiagnostics.usedTargetedStoreQuery)
            XCTAssertEqual(report.liveReferenceDiagnostics.requestedProjectIDs, 1)
            XCTAssertEqual(report.liveReferenceDiagnostics.requestedArtifactPaths, 2)
            XCTAssertEqual(report.liveReferenceDiagnostics.liveArtifactPathsMatched, 1)
        }
    }

    private func withEnvironment(_ body: (URL, URL) async throws -> Void) async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("AW26-TargetedLiveReferenceTests-" + UUID().uuidString, isDirectory: true)
        let storeURL = root.appendingPathComponent("Metadata/Library.sqlite")
        let artifactRoot = root.appendingPathComponent("Artifacts", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: artifactRoot, withIntermediateDirectories: true)
        try await body(storeURL, artifactRoot)
    }

    private func makeStem(projectID: ProjectID, path: String) -> StemArtifact {
        StemArtifact(
            id: StemID(),
            projectID: projectID,
            role: .vocals,
            relativePath: path,
            sampleRate: 44_100,
            channels: 2,
            frameCount: 44_100,
            startTimeSeconds: 0
        )
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

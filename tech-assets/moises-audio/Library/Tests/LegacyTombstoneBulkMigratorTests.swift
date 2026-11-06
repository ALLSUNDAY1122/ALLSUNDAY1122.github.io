import Foundation
import XCTest

#if canImport(CoreData)
#if canImport(MoisesAudioCore)
import MoisesAudioCore
#endif

final class Lane2LegacyTombstoneBulkMigratorTests: XCTestCase {
    func testBulkMigratorIndexesMultiBatchLegacyTombstonesAndMarksCompatibilityComplete() async throws {
        try await withEnvironment { storeURL, artifactRoot in
            let raw = try CoreDataProjectLibraryStore(
                configuration: .init(storeURL: storeURL, enumerationBatchSize: 16)
            )
            let sharedAssetID = AssetID()
            let source = LocalAudioAsset(
                id: sharedAssetID,
                relativePath: "Imports/shared/source.m4a",
                mediaKind: .audio,
                durationSeconds: 90
            )
            var projectIDs: [ProjectID] = []
            for index in 0..<40 {
                let projectID = try await raw.createProject(source: source)
                projectIDs.append(projectID)
                try await raw.recordStems(
                    projectID: projectID,
                    stems: [
                        StemArtifact(
                            id: StemID(),
                            projectID: projectID,
                            role: .vocals,
                            relativePath: "Stems/\(index)/vocals.m4a",
                            sampleRate: 44_100,
                            channels: 2,
                            frameCount: 44_100
                        ),
                        StemArtifact(
                            id: StemID(),
                            projectID: projectID,
                            role: .drums,
                            relativePath: "Stems/\(index)/drums.m4a",
                            sampleRate: 44_100,
                            channels: 2,
                            frameCount: 44_100
                        )
                    ]
                )
                try await raw.deleteProject(projectID: projectID)
            }

            let report = try await Lane2LegacyTombstoneBulkMigrator.prepareIfNeeded(
                metadataStoreURL: storeURL,
                artifactRootURL: artifactRoot,
                enumerationBatchSize: 16
            )
            XCTAssertFalse(report.skippedBecauseComplete)
            XCTAssertEqual(report.projectCount, 40)
            XCTAssertEqual(report.batchCount, 3)
            XCTAssertEqual(report.ownershipRecordsPersisted, 40)
            XCTAssertEqual(report.logicalFetchUpperBound, 7)
            XCTAssertEqual(report.legacyNPlusOneUpperBound, 81)

            let index = Lane2DeletionOwnershipIndex(rootURL: artifactRoot)
            XCTAssertTrue(index.isLegacyScanComplete)
            let records = try index.pendingRecords()
            XCTAssertEqual(records.count, 40)
            XCTAssertEqual(Set(records.map(\.projectUUID)), Set(projectIDs.map(\.rawValue)))
            XCTAssertTrue(records.allSatisfy { record in
                record.sourceAssetUUID == sharedAssetID.rawValue
                    && record.artifactRelativePaths.contains(source.relativePath)
                    && record.artifactRelativePaths.count == 3
            })

            let second = try await Lane2LegacyTombstoneBulkMigrator.prepareIfNeeded(
                metadataStoreURL: storeURL,
                artifactRootURL: artifactRoot,
                enumerationBatchSize: 16
            )
            XCTAssertTrue(second.skippedBecauseComplete)
            XCTAssertEqual(second.projectCount, 0)
        }
    }

    func testOwnershipConflictFailsWithoutMarkingLegacyComplete() async throws {
        try await withEnvironment { storeURL, artifactRoot in
            let raw = try CoreDataProjectLibraryStore(configuration: .init(storeURL: storeURL))
            let source = LocalAudioAsset(
                id: AssetID(),
                relativePath: "Imports/conflict/source.m4a",
                mediaKind: .audio,
                durationSeconds: 10
            )
            let projectID = try await raw.createProject(source: source)
            try await raw.deleteProject(projectID: projectID)

            let index = Lane2DeletionOwnershipIndex(rootURL: artifactRoot)
            try index.persist(
                Lane2DeletionOwnershipRecord(
                    projectUUID: projectID.rawValue,
                    sourceAssetUUID: UUID(),
                    artifactRelativePaths: [source.relativePath]
                )
            )

            do {
                _ = try await Lane2LegacyTombstoneBulkMigrator.prepareIfNeeded(
                    metadataStoreURL: storeURL,
                    artifactRootURL: artifactRoot
                )
                XCTFail("expected identity conflict")
            } catch Lane2DeletionOwnershipIndexFailure.identityConflict {
                // Expected fail-closed behavior.
            }
            XCTAssertFalse(index.isLegacyScanComplete)
        }
    }

    private func withEnvironment(
        _ body: (URL, URL) async throws -> Void
    ) async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("AW23-BulkMigratorTests-" + UUID().uuidString, isDirectory: true)
        let storeURL = root.appendingPathComponent("Metadata/Library.sqlite")
        let artifactRoot = root.appendingPathComponent("Artifacts", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: artifactRoot, withIntermediateDirectories: true)
        try await body(storeURL, artifactRoot)
    }
}
#endif

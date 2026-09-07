import Foundation
import XCTest

#if canImport(CoreData)
#if canImport(MoisesAudioCore)
import MoisesAudioCore
#endif

final class Lane2LegacyTombstoneBoundedMigratorTests: XCTestCase {
    func testLargeLegacyBacklogConvergesInBoundedSlices() async throws {
        try await withEnvironment { storeURL, artifactRoot in
            let raw = try CoreDataProjectLibraryStore(configuration: .init(storeURL: storeURL))
            let sharedSource = LocalAudioAsset(
                id: AssetID(),
                relativePath: "Imports/shared/source.m4a",
                mediaKind: .audio,
                durationSeconds: 120
            )
            var ids: [ProjectID] = []
            for index in 0..<130 {
                let id = try await raw.createProject(source: sharedSource)
                ids.append(id)
                try await raw.recordStems(
                    projectID: id,
                    stems: [
                        StemArtifact(
                            id: StemID(),
                            projectID: id,
                            role: .vocals,
                            relativePath: "Stems/\(index)/vocals.m4a",
                            sampleRate: 44_100,
                            channels: 2,
                            frameCount: 44_100
                        )
                    ]
                )
                try await raw.deleteProject(projectID: id)
            }

            let index = Lane2DeletionOwnershipIndex(rootURL: artifactRoot)
            let state = Lane2LegacyRecoverySliceState(rootURL: artifactRoot)
            var launches = 0
            while launches < 10 {
                let report = try await Lane2LegacyTombstoneBoundedMigrator.prepareNextSliceIfNeeded(
                    metadataStoreURL: storeURL,
                    artifactRootURL: artifactRoot,
                    projectsPerLaunch: 32
                )
                if report.skippedBecauseComplete { break }
                XCTAssertLessThanOrEqual(report.selectedLegacyProjects, 32)
                XCTAssertLessThanOrEqual(report.rootRowsMaterialized, 33)
                let crashSafe = try CrashSafeProjectLibraryStore(metadata: raw, artifactRootURL: artifactRoot)
                _ = try await crashSafe.recoverInterruptedOperations()
                launches += 1
                if !report.hasMoreLegacyProjects { break }
            }

            XCTAssertEqual(launches, 5)
            XCTAssertTrue(index.isLegacyScanComplete)
            XCTAssertFalse(state.isActive)
            XCTAssertTrue(try index.pendingRecords().isEmpty)
            XCTAssertTrue(try await raw.listTombstonedProjectCompactionCandidates().isEmpty)
            for id in ids {
                XCTAssertNil(try await raw.loadProject(projectID: id))
            }
        }
    }

    func testCrashBeforeRecoveryDoesNotAdvancePastSameSlice() async throws {
        try await withEnvironment { storeURL, artifactRoot in
            let raw = try CoreDataProjectLibraryStore(configuration: .init(storeURL: storeURL))
            for index in 0..<20 {
                let source = LocalAudioAsset(
                    id: AssetID(),
                    relativePath: "Imports/\(index)/source.m4a",
                    mediaKind: .audio,
                    durationSeconds: 20
                )
                let id = try await raw.createProject(source: source)
                try await raw.deleteProject(projectID: id)
            }

            let first = try await Lane2LegacyTombstoneBoundedMigrator.prepareNextSliceIfNeeded(
                metadataStoreURL: storeURL,
                artifactRootURL: artifactRoot,
                projectsPerLaunch: 8
            )
            XCTAssertEqual(first.selectedLegacyProjects, 8)
            XCTAssertTrue(first.hasMoreLegacyProjects)
            let index = Lane2DeletionOwnershipIndex(rootURL: artifactRoot)
            XCTAssertEqual(try index.pendingRecords().count, 8)

            let second = try await Lane2LegacyTombstoneBoundedMigrator.prepareNextSliceIfNeeded(
                metadataStoreURL: storeURL,
                artifactRootURL: artifactRoot,
                projectsPerLaunch: 8
            )
            XCTAssertEqual(second.selectedLegacyProjects, 8)
            XCTAssertEqual(try index.pendingRecords().count, 8)
        }
    }

    private func withEnvironment(_ body: (URL, URL) async throws -> Void) async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("AW24-BoundedMigratorTests-" + UUID().uuidString, isDirectory: true)
        let storeURL = root.appendingPathComponent("Metadata/Library.sqlite")
        let artifactRoot = root.appendingPathComponent("Artifacts", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: artifactRoot, withIntermediateDirectories: true)
        try await body(storeURL, artifactRoot)
    }
}
#endif

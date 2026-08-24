import Foundation
import XCTest

#if canImport(CoreData)
#if canImport(MoisesAudioCore)
import MoisesAudioCore
#endif

final class Lane2IndexedRecoveryCrashSafeTests: XCTestCase {
    func testFullyIndexedHistoricalBacklogDrainsInBoundedPasses() async throws {
        try await withEnvironment { storeURL, artifactRoot in
            let raw = try CoreDataProjectLibraryStore(configuration: .init(storeURL: storeURL))
            let index = Lane2DeletionOwnershipIndex(rootURL: artifactRoot)
            try index.markLegacyScanComplete()

            for value in 0..<20 {
                let source = LocalAudioAsset(
                    id: AssetID(),
                    relativePath: "Imports/history-\(value)/source.m4a",
                    mediaKind: .audio,
                    durationSeconds: 20
                )
                let projectID = try await raw.createProject(source: source)
                try await raw.deleteProject(projectID: projectID)
                try index.persist(
                    Lane2DeletionOwnershipRecord(
                        projectUUID: projectID.rawValue,
                        sourceAssetUUID: source.id.rawValue,
                        artifactRelativePaths: [source.relativePath]
                    )
                )
            }

            let store = try CrashSafeProjectLibraryStore(
                metadata: raw,
                artifactRootURL: artifactRoot,
                ownershipOnlyRecoveryLimit: 8
            )

            let first = try await store.recoverInterruptedOperations()
            XCTAssertEqual(first.indexedRecoveryDiagnostics.prioritizedDeletionJournals, 0)
            XCTAssertEqual(first.indexedRecoveryDiagnostics.ownershipOnlyRecordsSelected, 8)
            XCTAssertTrue(first.indexedRecoveryDiagnostics.ownershipOnlyRecordsDeferred)
            XCTAssertEqual(try index.pendingRecords().count, 12)

            let second = try await store.recoverInterruptedOperations()
            XCTAssertEqual(second.indexedRecoveryDiagnostics.ownershipOnlyRecordsSelected, 8)
            XCTAssertTrue(second.indexedRecoveryDiagnostics.ownershipOnlyRecordsDeferred)
            XCTAssertEqual(try index.pendingRecords().count, 4)

            let third = try await store.recoverInterruptedOperations()
            XCTAssertEqual(third.indexedRecoveryDiagnostics.ownershipOnlyRecordsSelected, 4)
            XCTAssertFalse(third.indexedRecoveryDiagnostics.ownershipOnlyRecordsDeferred)
            XCTAssertTrue(try index.pendingRecords().isEmpty)
            XCTAssertTrue(try await raw.listTombstonedProjectCompactionCandidates().isEmpty)
        }
    }

    func testJournalBackedDeleteIsPrioritizedAheadOfOwnershipOnlyBudget() async throws {
        try await withEnvironment { storeURL, artifactRoot in
            let raw = try CoreDataProjectLibraryStore(configuration: .init(storeURL: storeURL))
            let index = Lane2DeletionOwnershipIndex(rootURL: artifactRoot)
            let lifecycle = LibraryArtifactLifecycle(rootURL: artifactRoot)
            try index.markLegacyScanComplete()

            for value in 0..<9 {
                let source = LocalAudioAsset(
                    id: AssetID(),
                    relativePath: "Imports/backlog-\(value)/source.m4a",
                    mediaKind: .audio,
                    durationSeconds: 20
                )
                let projectID = try await raw.createProject(source: source)
                try await raw.deleteProject(projectID: projectID)
                try index.persist(
                    Lane2DeletionOwnershipRecord(
                        projectUUID: projectID.rawValue,
                        sourceAssetUUID: source.id.rawValue,
                        artifactRelativePaths: [source.relativePath]
                    )
                )
            }

            let currentSource = LocalAudioAsset(
                id: AssetID(),
                relativePath: "Imports/current/source.m4a",
                mediaKind: .audio,
                durationSeconds: 30
            )
            let currentProjectID = try await raw.createProject(source: currentSource)
            try await raw.deleteProject(projectID: currentProjectID)
            try index.persist(
                Lane2DeletionOwnershipRecord(
                    projectUUID: currentProjectID.rawValue,
                    sourceAssetUUID: currentSource.id.rawValue,
                    artifactRelativePaths: [currentSource.relativePath]
                )
            )
            try lifecycle.persistCommittedDeletion(
                projectUUID: currentProjectID.rawValue,
                relativePaths: [currentSource.relativePath]
            )

            let store = try CrashSafeProjectLibraryStore(
                metadata: raw,
                artifactRootURL: artifactRoot,
                ownershipOnlyRecoveryLimit: 8
            )
            let report = try await store.recoverInterruptedOperations()

            XCTAssertEqual(report.indexedRecoveryDiagnostics.prioritizedDeletionJournals, 1)
            XCTAssertEqual(report.indexedRecoveryDiagnostics.ownershipOnlyRecordsSelected, 8)
            XCTAssertTrue(report.indexedRecoveryDiagnostics.ownershipOnlyRecordsDeferred)
            XCTAssertNil(try index.record(projectUUID: currentProjectID.rawValue))
            XCTAssertTrue(try lifecycle.pendingDeletionJournals().isEmpty)
            XCTAssertEqual(try index.pendingRecords().count, 1)
        }
    }

    private func withEnvironment(_ body: (URL, URL) async throws -> Void) async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("AW25-CrashSafeTests-" + UUID().uuidString, isDirectory: true)
        let storeURL = root.appendingPathComponent("Metadata/Library.sqlite")
        let artifactRoot = root.appendingPathComponent("Artifacts", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: artifactRoot, withIntermediateDirectories: true)
        try await body(storeURL, artifactRoot)
    }
}
#endif

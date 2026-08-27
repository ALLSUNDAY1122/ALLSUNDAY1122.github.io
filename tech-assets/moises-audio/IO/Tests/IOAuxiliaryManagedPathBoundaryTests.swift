import Foundation
import XCTest
#if canImport(MoisesAudioIO)
@testable import MoisesAudioIO
#endif

final class IOAuxiliaryManagedPathBoundaryTests: XCTestCase {
    func testDanglingManagedLeafIsNotTreatedAsMissingFuturePath() throws {
        try withSandbox { store, fm, base in
            let missingTarget = base.appendingPathComponent("outside-missing.m4a")
            let link = store.importsURL.appendingPathComponent("ghost.m4a")
            try fm.createSymbolicLink(at: link, withDestinationURL: missingTarget)

            XCTAssertThrowsError(try store.resolve(relativePath: "Imports/ghost.m4a", fileManager: fm)) { error in
                XCTAssertEqual(error as? IOFileStore.StoreError, .invalidRelativePath)
            }
            XCTAssertFalse(fm.fileExists(atPath: missingTarget.path))
        }
    }

    func testStagingOwnershipRecoveryDirectorySymlinkFailsClosed() throws {
        try withSandbox { store, fm, base in
            let external = base.appendingPathComponent("external-ledger", isDirectory: true)
            try fm.createDirectory(at: external, withIntermediateDirectories: true)
            let recovery = store.rootURL.appendingPathComponent(".IORecovery", isDirectory: true)
            try fm.createSymbolicLink(at: recovery, withDestinationURL: external)

            let registry = IOStagingOwnershipRegistry(
                fileStore: store,
                storageReserveBytes: 0,
                fileManager: fm
            )
            let token = UUID().uuidString.lowercased()
            XCTAssertThrowsError(
                try registry.acquire(
                    token: token,
                    stagingFilename: token + ".provider-partial",
                    reservedBytes: 1
                )
            ) { error in
                XCTAssertEqual(error as? IOStagingOwnershipError, .ledgerUnavailable)
            }
            XCTAssertTrue(try fm.contentsOfDirectory(atPath: external.path).isEmpty)
        }
    }

    func testDanglingLeaseRecordIsCorruptAuthorityNotMissingLease() throws {
        try withSandbox { store, fm, base in
            let registry = IOStagingOwnershipRegistry(
                fileStore: store,
                storageReserveBytes: 0,
                fileManager: fm
            )
            try fm.createDirectory(at: registry.ledgerURL, withIntermediateDirectories: true)
            let token = UUID().uuidString.lowercased()
            let name = token + ".provider-partial"
            let recordURL = registry.ledgerURL.appendingPathComponent(token).appendingPathExtension("json")
            try fm.createSymbolicLink(
                at: recordURL,
                withDestinationURL: base.appendingPathComponent("missing-lease-target.json")
            )

            XCTAssertThrowsError(
                try registry.isProtected(
                    stagingFilename: name,
                    now: Date(),
                    corruptRecordGrace: 60
                )
            ) { error in
                XCTAssertEqual(error as? IOStagingOwnershipError, .leaseCorrupt)
            }
        }
    }

    func testPublicationShardDirectorySymlinkFailsClosedWithoutExternalWrite() throws {
        try withSandbox { store, fm, base in
            let external = base.appendingPathComponent("external-publications", isDirectory: true)
            try fm.createDirectory(at: external, withIntermediateDirectories: true)
            let publications = store.rootURL
                .appendingPathComponent(".LibraryRecovery", isDirectory: true)
                .appendingPathComponent("ArtifactInventory", isDirectory: true)
                .appendingPathComponent("v1", isDirectory: true)
                .appendingPathComponent("Publications", isDirectory: true)
            try fm.createDirectory(at: publications, withIntermediateDirectories: true)
            try fm.createSymbolicLink(
                at: publications.appendingPathComponent("Shards", isDirectory: true),
                withDestinationURL: external
            )

            let journal = Lane2ManagedArtifactPublicationJournal(rootURL: store.rootURL, fileManager: fm)
            XCTAssertThrowsError(try journal.begin(relativePath: "Imports/song.m4a")) { error in
                guard case .corruptShard = error as? Lane2ManagedArtifactPublicationJournalFailure else {
                    return XCTFail("expected corruptShard, got \(error)")
                }
            }
            XCTAssertTrue(try fm.contentsOfDirectory(atPath: external.path).isEmpty)
        }
    }

    func testDanglingPublicationCursorFailsClosed() throws {
        try withSandbox { store, fm, base in
            let journal = Lane2ManagedArtifactPublicationJournal(rootURL: store.rootURL, fileManager: fm)
            XCTAssertFalse(try journal.contains(relativePath: "Imports/absent.m4a"))
            let cursor = store.rootURL
                .appendingPathComponent(".LibraryRecovery", isDirectory: true)
                .appendingPathComponent("ArtifactInventory", isDirectory: true)
                .appendingPathComponent("v1", isDirectory: true)
                .appendingPathComponent("Publications", isDirectory: true)
                .appendingPathComponent("cursor.json")
            try fm.createSymbolicLink(
                at: cursor,
                withDestinationURL: base.appendingPathComponent("missing-cursor.json")
            )

            XCTAssertThrowsError(try journal.preparePreviousSessionRecoverySlice()) { error in
                XCTAssertEqual(error as? Lane2ManagedArtifactPublicationJournalFailure, .corruptCursor)
            }
        }
    }

    func testExportBatchStagingRootSymlinkFailsClosed() throws {
        try withSandbox { store, fm, base in
            let transaction = IOExportBatchTransaction(fileStore: store)
            let external = base.appendingPathComponent("external-export-staging", isDirectory: true)
            try fm.createDirectory(at: external, withIntermediateDirectories: true)
            try fm.createSymbolicLink(at: transaction.stagingBatchesURL, withDestinationURL: external)

            XCTAssertThrowsError(
                try transaction.prepare(
                    suggestedFilenameStems: ["Vocals"],
                    fileExtension: "m4a",
                    fileManager: fm
                )
            ) { error in
                XCTAssertEqual(
                    error as? IOExportBatchTransaction.BatchError,
                    .fileOperationFailed(code: "EXPORT_BATCH_DIRECTORY_CREATE_FAILED")
                )
            }
            XCTAssertTrue(try fm.contentsOfDirectory(atPath: external.path).isEmpty)
        }
    }

    func testExportBatchFinalRootSymlinkFailsClosed() throws {
        try withSandbox { store, fm, base in
            let transaction = IOExportBatchTransaction(fileStore: store)
            let external = base.appendingPathComponent("external-export-final", isDirectory: true)
            try fm.createDirectory(at: external, withIntermediateDirectories: true)
            try fm.createSymbolicLink(at: transaction.finalizedBatchesURL, withDestinationURL: external)

            XCTAssertThrowsError(
                try transaction.prepare(
                    suggestedFilenameStems: ["Vocals"],
                    fileExtension: "m4a",
                    fileManager: fm
                )
            ) { error in
                XCTAssertEqual(
                    error as? IOExportBatchTransaction.BatchError,
                    .fileOperationFailed(code: "EXPORT_BATCH_DIRECTORY_CREATE_FAILED")
                )
            }
            XCTAssertTrue(try fm.contentsOfDirectory(atPath: external.path).isEmpty)
        }
    }

    func testAbandonedBatchRecoveryNeverTraversesSymlinkChild() throws {
        try withSandbox { store, fm, base in
            let transaction = IOExportBatchTransaction(fileStore: store)
            let plan = try transaction.prepare(
                suggestedFilenameStems: ["Vocals"],
                fileExtension: "m4a",
                fileManager: fm
            )
            transaction.abort(plan, fileManager: fm)

            let external = base.appendingPathComponent("external-abandoned", isDirectory: true)
            let victim = external.appendingPathComponent("keep.txt")
            try fm.createDirectory(at: external, withIntermediateDirectories: true)
            try Data("keep".utf8).write(to: victim)
            try fm.createSymbolicLink(
                at: transaction.stagingBatchesURL.appendingPathComponent("forged-batch", isDirectory: true),
                withDestinationURL: external
            )

            XCTAssertThrowsError(try transaction.recoverAbandonedBatches(fileManager: fm)) { error in
                XCTAssertEqual(
                    error as? IOExportBatchTransaction.BatchError,
                    .fileOperationFailed(code: "EXPORT_BATCH_RECOVERY_UNSAFE_ENTRY")
                )
            }
            XCTAssertEqual(try String(contentsOf: victim, encoding: .utf8), "keep")
        }
    }

    func testNormalExportBatchStillCommitsAndVerifies() throws {
        try withSandbox { store, fm, _ in
            let transaction = IOExportBatchTransaction(fileStore: store)
            let plan = try transaction.prepare(
                suggestedFilenameStems: ["Vocals", "Drums"],
                fileExtension: "m4a",
                fileManager: fm
            )
            for (index, item) in plan.items.enumerated() {
                try Data(repeating: UInt8(index + 1), count: 32).write(to: item.stagingURL)
            }
            let finalized = try transaction.commit(plan, fileManager: fm)
            XCTAssertEqual(finalized.count, 2)
            XCTAssertEqual(try transaction.verifyPublishedBatch(batchID: plan.id, fileManager: fm), finalized)
        }
    }

    private func withSandbox(
        _ body: (IOFileStore, FileManager, URL) throws -> Void
    ) throws {
        let fm = FileManager.default
        let base = fm.temporaryDirectory.appendingPathComponent("L2-AW48-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: base, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: base) }
        let store = IOFileStore(rootURL: base.appendingPathComponent("sandbox", isDirectory: true))
        try store.prepareDirectories(fileManager: fm)
        try body(store, fm, base)
    }
}

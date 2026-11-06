import Foundation
import XCTest
#if canImport(MoisesAudioIO)
@testable import MoisesAudioIO
#endif

final class IOExportBatchTransactionTests: XCTestCase {
    func testCommitPublishesWholeBatchWithCleanNames() throws {
        try withSandbox { store, transaction, fm in
            let plan = try transaction.prepare(
                suggestedFilenameStems: ["Vocals", "vocals", "Drums / FX"],
                fileExtension: ".M4A",
                fileManager: fm
            )
            XCTAssertEqual(plan.items.map(\.filename), ["Vocals.m4a", "vocals (2).m4a", "Drums _ FX.m4a"])
            for item in plan.items { try Data([1, 2, 3]).write(to: item.stagingURL) }

            let finalized = try transaction.commit(plan, fileManager: fm)
            XCTAssertEqual(finalized.count, 3)
            XCTAssertTrue(finalized.allSatisfy { $0.relativePath.hasPrefix("Exports/Batches/") })
            XCTAssertEqual(finalized.map { $0.url.lastPathComponent }, plan.items.map(\.filename))
            XCTAssertTrue(finalized.allSatisfy { !$0.url.lastPathComponent.contains(plan.id) })
            XCTAssertFalse(fm.fileExists(atPath: plan.stagingDirectoryURL.path))
        }
    }

    func testMissingOutputFailsBeforePublication() throws {
        try withSandbox { _, transaction, fm in
            let plan = try transaction.prepare(
                suggestedFilenameStems: ["Bass", "Other"],
                fileExtension: "m4a",
                fileManager: fm
            )
            try Data([1]).write(to: plan.items[0].stagingURL)
            XCTAssertThrowsError(try transaction.commit(plan, fileManager: fm)) { error in
                XCTAssertEqual(error as? IOExportBatchTransaction.BatchError, .outputMissing(filename: "Other.m4a"))
            }
            let finalDirectory = transaction.finalizedBatchesURL.appendingPathComponent(plan.id, isDirectory: true)
            XCTAssertFalse(fm.fileExists(atPath: finalDirectory.path))
        }
    }

    func testZeroByteOutputFailsClosed() throws {
        try withSandbox { _, transaction, fm in
            let plan = try transaction.prepare(
                suggestedFilenameStems: ["Empty"],
                fileExtension: "m4a",
                fileManager: fm
            )
            _ = fm.createFile(atPath: plan.items[0].stagingURL.path, contents: Data())
            XCTAssertThrowsError(try transaction.commit(plan, fileManager: fm)) { error in
                XCTAssertEqual(error as? IOExportBatchTransaction.BatchError, .outputEmpty(filename: "Empty.m4a"))
            }
        }
    }

    func testRecoveryRemovesOnlyUnpublishedBatches() throws {
        try withSandbox { _, transaction, fm in
            let committedPlan = try transaction.prepare(
                suggestedFilenameStems: ["Vocals"],
                fileExtension: "m4a",
                fileManager: fm
            )
            try Data([1]).write(to: committedPlan.items[0].stagingURL)
            let committed = try transaction.commit(committedPlan, fileManager: fm)

            _ = try transaction.prepare(suggestedFilenameStems: ["A"], fileExtension: "m4a", fileManager: fm)
            _ = try transaction.prepare(suggestedFilenameStems: ["B"], fileExtension: "m4a", fileManager: fm)
            XCTAssertEqual(try transaction.recoverAbandonedBatches(fileManager: fm), 2)
            XCTAssertTrue(fm.fileExists(atPath: committed[0].url.path))
        }
    }

    private func withSandbox(
        _ body: (IOFileStore, IOExportBatchTransaction, FileManager) throws -> Void
    ) throws {
        let fm = FileManager.default
        let base = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("io-export-batch-tests-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: base, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: base) }
        let store = IOFileStore(rootURL: base.appendingPathComponent("sandbox", isDirectory: true))
        try store.prepareDirectories(fileManager: fm)
        try body(store, IOExportBatchTransaction(fileStore: store), fm)
    }
}

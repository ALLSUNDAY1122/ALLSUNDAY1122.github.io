import Foundation
import XCTest

final class IOExportBatchIntegrityTests: XCTestCase {
    func testCommitWritesManifestAndPublishedBatchVerifies() throws {
        try withRoot { root in
            let store = IOFileStore(rootURL: root)
            let transaction = IOExportBatchTransaction(fileStore: store)
            let plan = try transaction.prepare(
                suggestedFilenameStems: ["vocals", "drums"],
                fileExtension: "m4a"
            )
            try Data(repeating: 0x11, count: 4096).write(to: plan.items[0].stagingURL)
            try Data(repeating: 0x22, count: 8192).write(to: plan.items[1].stagingURL)

            let published = try transaction.commit(plan)
            XCTAssertEqual(published.count, 2)
            let batchDirectory = transaction.finalizedBatchesURL.appendingPathComponent(plan.id, isDirectory: true)
            XCTAssertTrue(
                FileManager.default.fileExists(
                    atPath: batchDirectory.appendingPathComponent(IOExportBatchTransaction.integrityManifestFilename).path
                )
            )
            XCTAssertEqual(try transaction.verifyPublishedBatch(batchID: plan.id).count, 2)
        }
    }

    func testPublishedByteMutationIsRejected() throws {
        try withRoot { root in
            let store = IOFileStore(rootURL: root)
            let transaction = IOExportBatchTransaction(fileStore: store)
            let plan = try transaction.prepare(suggestedFilenameStems: ["mix"], fileExtension: "m4a")
            try Data(repeating: 0x31, count: 2048).write(to: plan.items[0].stagingURL)
            let published = try transaction.commit(plan)

            let handle = try FileHandle(forWritingTo: published[0].url)
            try handle.seekToEnd()
            try handle.write(contentsOf: Data([0xff]))
            try handle.close()

            XCTAssertThrowsError(try transaction.verifyPublishedBatch(batchID: plan.id)) { error in
                XCTAssertEqual(error as? IOExportBatchTransaction.BatchError, .integrityMismatch(filename: plan.items[0].filename))
            }
        }
    }

    func testUnexpectedPublishedFileIsRejected() throws {
        try withRoot { root in
            let store = IOFileStore(rootURL: root)
            let transaction = IOExportBatchTransaction(fileStore: store)
            let plan = try transaction.prepare(suggestedFilenameStems: ["bass"], fileExtension: "m4a")
            try Data(repeating: 0x41, count: 1024).write(to: plan.items[0].stagingURL)
            _ = try transaction.commit(plan)
            let batchDirectory = transaction.finalizedBatchesURL.appendingPathComponent(plan.id, isDirectory: true)
            try Data([0x01]).write(to: batchDirectory.appendingPathComponent("unexpected.bin"))

            XCTAssertThrowsError(try transaction.verifyPublishedBatch(batchID: plan.id))
        }
    }

    func testSymlinkReplacementIsRejected() throws {
        try withRoot { root in
            let store = IOFileStore(rootURL: root)
            let transaction = IOExportBatchTransaction(fileStore: store)
            let plan = try transaction.prepare(suggestedFilenameStems: ["other"], fileExtension: "m4a")
            try Data(repeating: 0x51, count: 1024).write(to: plan.items[0].stagingURL)
            let published = try transaction.commit(plan)
            let outside = root.appendingPathComponent("outside.bin")
            try Data(repeating: 0x51, count: 1024).write(to: outside)
            try FileManager.default.removeItem(at: published[0].url)
            try FileManager.default.createSymbolicLink(at: published[0].url, withDestinationURL: outside)

            XCTAssertThrowsError(try transaction.verifyPublishedBatch(batchID: plan.id))
        }
    }

    private func withRoot(_ body: (URL) throws -> Void) throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(
            "AW35Export-" + UUID().uuidString,
            isDirectory: true
        )
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try body(root)
    }
}

import Foundation
import XCTest
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif
@testable import MoisesAudioCore

final class AnalysisPhysicalRealAudioBridgeConsumptionNamespaceHardeningTests: XCTestCase {
    private func root() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("w54-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func prepare(_ root: URL) throws -> (ledger: URL, records: URL) {
        try AnalysisPhysicalRealAudioBridgeConsumptionSecureFilesystem.ensureDirectories(
            ledgerID: "ledger",
            rootURL: root,
            fileManager: .default
        )
        let ledger = AnalysisPhysicalRealAudioBridgeConsumptionSecureFilesystem.ledgerURL(
            ledgerID: "ledger",
            rootURL: root
        )
        return (ledger, ledger.appendingPathComponent("records", isDirectory: true))
    }

    private func tempName(_ suffix: String) -> String {
        AnalysisPhysicalRealAudioBridgeConsumptionDurablePublication.temporaryPrefix
            + suffix
            + AnalysisPhysicalRealAudioBridgeConsumptionDurablePublication.temporarySuffix
    }

    func testWriterLeaseGarbageCollectsLedgerAndRecordTempsAndSyncsBothDirectories() throws {
        let root = try root()
        defer { try? FileManager.default.removeItem(at: root) }
        let paths = try prepare(root)
        let ledgerTemp = paths.ledger.appendingPathComponent(tempName("ledger"))
        let recordTemp = paths.records.appendingPathComponent(tempName("record"))
        try Data("ledger-temp".utf8).write(to: ledgerTemp)
        try Data("record-temp".utf8).write(to: recordTemp)

        let receipt = try AnalysisPhysicalRealAudioBridgeConsumptionWriterLock.withExclusiveLock(
            ledgerID: "ledger",
            rootURL: root
        ) { lease in
            try AnalysisPhysicalRealAudioBridgeConsumptionNamespaceHardening.garbageCollectInterruptedPublicationTemps(
                ledgerID: "ledger",
                rootURL: root,
                lease: lease,
                fileManager: .default
            )
        }

        XCTAssertEqual(receipt.removedLedgerTemporaryCount, 1)
        XCTAssertEqual(receipt.removedRecordTemporaryCount, 1)
        XCTAssertEqual(receipt.synchronizedDirectories, ["ledger", "records"])
        XCTAssertFalse(FileManager.default.fileExists(atPath: ledgerTemp.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: recordTemp.path))
    }

    func testExcessInterruptedTempsFailBeforeAnyDeletion() throws {
        let root = try root()
        defer { try? FileManager.default.removeItem(at: root) }
        let paths = try prepare(root)
        let count = AnalysisPhysicalRealAudioBridgeConsumptionDurablePublication.maximumInterruptedTemporaryFilesPerDirectory + 1
        for index in 0..<count {
            try Data("x".utf8).write(to: paths.ledger.appendingPathComponent(tempName("excess-\(index)")))
        }

        XCTAssertThrowsError(try AnalysisPhysicalRealAudioBridgeConsumptionWriterLock.withExclusiveLock(
            ledgerID: "ledger",
            rootURL: root
        ) { lease in
            try AnalysisPhysicalRealAudioBridgeConsumptionNamespaceHardening.garbageCollectInterruptedPublicationTemps(
                ledgerID: "ledger",
                rootURL: root,
                lease: lease,
                fileManager: .default
            )
        }) { error in
            XCTAssertEqual(
                error as? AnalysisPhysicalRealAudioBridgeConsumptionNamespaceError,
                .excessiveInterruptedTemporaries
            )
        }

        let names = try FileManager.default.contentsOfDirectory(atPath: paths.ledger.path)
        XCTAssertEqual(names.filter { AnalysisPhysicalRealAudioBridgeConsumptionDurablePublication.isInterruptedTemporaryFileName($0) }.count, count)
    }

    func testDanglingSymlinkTempIsObservedNoFollowAndRejected() throws {
        let root = try root()
        defer { try? FileManager.default.removeItem(at: root) }
        let paths = try prepare(root)
        let link = paths.ledger.appendingPathComponent(tempName("dangling"))
        let missing = root.appendingPathComponent("missing-target")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: missing)

        XCTAssertThrowsError(try AnalysisPhysicalRealAudioBridgeConsumptionWriterLock.withExclusiveLock(
            ledgerID: "ledger",
            rootURL: root
        ) { lease in
            try AnalysisPhysicalRealAudioBridgeConsumptionNamespaceHardening.garbageCollectInterruptedPublicationTemps(
                ledgerID: "ledger",
                rootURL: root,
                lease: lease,
                fileManager: .default
            )
        }) { error in
            XCTAssertEqual(
                error as? AnalysisPhysicalRealAudioBridgeConsumptionNamespaceError,
                .symbolicLinkRejected
            )
        }
        let values = try link.resourceValues(forKeys: [.isSymbolicLinkKey])
        XCTAssertEqual(values.isSymbolicLink, true)
    }

    func testEntrySubstitutionBetweenInspectionAndUnlinkFailsClosedAndPreservesReplacement() throws {
        let root = try root()
        defer { try? FileManager.default.removeItem(at: root) }
        let paths = try prepare(root)
        let name = tempName("swap")
        let original = paths.records.appendingPathComponent(name)
        try Data("original".utf8).write(to: original)

        try AnalysisPhysicalRealAudioBridgeConsumptionNamespaceHardening.withPinnedDirectory(
            paths.records,
            within: root
        ) { directory in
            let expected = try XCTUnwrap(
                AnalysisPhysicalRealAudioBridgeConsumptionNamespaceHardening.entryIdentity(name: name, in: directory)
            )
            let retained = paths.records.appendingPathComponent("retained-original")
            try FileManager.default.moveItem(at: original, to: retained)
            try Data("replacement".utf8).write(to: original)

            XCTAssertThrowsError(try AnalysisPhysicalRealAudioBridgeConsumptionNamespaceHardening.unlinkExpectedEntry(
                name: name,
                expectedIdentity: expected,
                in: directory
            )) { error in
                XCTAssertEqual(
                    error as? AnalysisPhysicalRealAudioBridgeConsumptionNamespaceError,
                    .entryIdentityChanged
                )
            }
            XCTAssertEqual(try Data(contentsOf: original), Data("replacement".utf8))
        }
    }

    func testPinnedDirectoryDetectsPathReplacement() throws {
        let root = try root()
        defer { try? FileManager.default.removeItem(at: root) }
        let paths = try prepare(root)
        let handle = try AnalysisPhysicalRealAudioBridgeConsumptionNamespaceHardening.openPinnedDirectory(
            paths.records,
            within: root
        )
        defer { _ = close(handle.fileDescriptor) }

        let moved = paths.ledger.appendingPathComponent("records-retained", isDirectory: true)
        try FileManager.default.moveItem(at: paths.records, to: moved)
        try FileManager.default.createDirectory(at: paths.records, withIntermediateDirectories: false)

        XCTAssertThrowsError(try AnalysisPhysicalRealAudioBridgeConsumptionNamespaceHardening.validateDirectoryPathStillMatches(
            handle,
            within: root
        )) { error in
            XCTAssertEqual(
                error as? AnalysisPhysicalRealAudioBridgeConsumptionNamespaceError,
                .directoryIdentityChanged
            )
        }
    }

    func testConcurrentStoreBootstrapsBrandNewLedgerBeforeGC() throws {
        let root = try root()
        defer { try? FileManager.default.removeItem(at: root) }
        let cas = try AnalysisPhysicalRealAudioBridgeConsumptionConcurrentStore.observeAppendCAS(
            ledgerID: "brand-new-ledger",
            rootURL: root
        )
        XCTAssertEqual(cas.expectedLatestSequence, 0)
        XCTAssertNil(cas.expectedLedgerRootSHA256)
        XCTAssertNil(cas.expectedLatestRecordRootSHA256)

        let ledger = AnalysisPhysicalRealAudioBridgeConsumptionSecureFilesystem.ledgerURL(
            ledgerID: "brand-new-ledger",
            rootURL: root
        )
        XCTAssertTrue(FileManager.default.fileExists(atPath: ledger.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: ledger.appendingPathComponent("records").path))
    }
}

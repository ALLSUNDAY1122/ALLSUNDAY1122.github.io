import Foundation
import XCTest
@testable import MoisesAudioCore

final class AnalysisPhysicalEvidenceAnchorLedgerTests: XCTestCase {
    private let ledgerID = "ledger-w43"
    private let anchorID = "anchor-w43"

    private func sha(_ character: Character) -> String {
        String(repeating: String(character), count: 64)
    }

    private var runs: [AnalysisPhysicalEvidenceBatchRunSummary] {
        [
            .init(runID: "run-a", workloadExecutionID: "exec-a", w39BundleRootSHA256: sha("a")),
            .init(runID: "run-b", workloadExecutionID: "exec-b", w39BundleRootSHA256: sha("b"))
        ]
    }

    private func tempRoot() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("w43-ledger-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func receipt(
        sequence: UInt64,
        predecessor: String?,
        rootSeed: Character
    ) throws -> AnalysisPhysicalEvidenceAnchorReceipt {
        let anchor = AnalysisPhysicalEvidenceExternalRootAnchor(
            anchorID: anchorID,
            anchorSequence: sequence,
            authority: "HQ_LATE_INTEGRATION",
            approvalReference: "HQ-W43-\(sequence)",
            publicationID: "batch-\(sequence)",
            transferID: "transfer-\(sequence)",
            w27RootSHA256: sha(rootSeed),
            w38RootSHA256: sha(sequence.isMultiple(of: 2) ? "d" : "c"),
            w40RootSHA256: sha("e"),
            w41RootSHA256: sha("f"),
            runs: runs,
            predecessorAnchorReceiptRootSHA256: predecessor
        )
        return try AnalysisPhysicalEvidenceAnchorReceiptIssuer.issue(anchor: anchor)
    }

    private func certificate(
        for receipt: AnalysisPhysicalEvidenceAnchorReceipt
    ) throws -> AnalysisPhysicalEvidenceDestinationVerificationCertificate {
        let anchor = receipt.anchor
        let provisional = AnalysisPhysicalEvidenceDestinationVerificationCertificate(
            status: .verifiedAgainstExternalAnchorNonParity,
            anchorID: anchor.anchorID,
            anchorSequence: anchor.anchorSequence,
            anchorReceiptRootSHA256: receipt.declaredAnchorReceiptRootSHA256,
            publicationID: anchor.publicationID,
            transferID: anchor.transferID,
            expectedW27RootSHA256: anchor.w27RootSHA256,
            expectedW38RootSHA256: anchor.w38RootSHA256,
            expectedW40RootSHA256: anchor.w40RootSHA256,
            expectedW41RootSHA256: anchor.w41RootSHA256,
            destinationW27RootSHA256: anchor.w27RootSHA256,
            destinationW38RootSHA256: anchor.w38RootSHA256,
            destinationW40RootSHA256: anchor.w40RootSHA256,
            destinationW41RootSHA256: anchor.w41RootSHA256,
            runs: anchor.runs,
            limitations: AnalysisPhysicalEvidenceDestinationAnchorVerifier.limitations,
            declaredCertificateRootSHA256: String(repeating: "0", count: 64)
        )
        let root = try AnalysisPhysicalEvidenceDestinationCertificateRoot.compute(provisional)
        return .init(
            status: provisional.status,
            anchorID: provisional.anchorID,
            anchorSequence: provisional.anchorSequence,
            anchorReceiptRootSHA256: provisional.anchorReceiptRootSHA256,
            publicationID: provisional.publicationID,
            transferID: provisional.transferID,
            expectedW27RootSHA256: provisional.expectedW27RootSHA256,
            expectedW38RootSHA256: provisional.expectedW38RootSHA256,
            expectedW40RootSHA256: provisional.expectedW40RootSHA256,
            expectedW41RootSHA256: provisional.expectedW41RootSHA256,
            destinationW27RootSHA256: provisional.destinationW27RootSHA256,
            destinationW38RootSHA256: provisional.destinationW38RootSHA256,
            destinationW40RootSHA256: provisional.destinationW40RootSHA256,
            destinationW41RootSHA256: provisional.destinationW41RootSHA256,
            runs: provisional.runs,
            limitations: provisional.limitations,
            declaredCertificateRootSHA256: root
        )
    }

    private func append(
        sequence: UInt64,
        predecessor: String?,
        rootSeed: Character,
        root: URL
    ) throws -> (AnalysisPhysicalEvidenceAnchorReceipt, AnalysisPhysicalEvidenceDestinationVerificationCertificate, AnalysisPhysicalEvidenceAnchorLedgerAppendReceipt) {
        let receipt = try receipt(sequence: sequence, predecessor: predecessor, rootSeed: rootSeed)
        let certificate = try certificate(for: receipt)
        let result = try AnalysisPhysicalEvidenceAnchorLedgerStore.append(
            ledgerID: ledgerID,
            anchorReceipt: receipt,
            destinationCertificate: certificate,
            rootURL: root
        )
        return (receipt, certificate, result)
    }

    func testAppendRelaunchAndSnapshotAreDeterministic() throws {
        let root = try tempRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let first = try append(sequence: 1, predecessor: nil, rootSeed: "1", root: root)
        let second = try append(sequence: 2, predecessor: first.0.declaredAnchorReceiptRootSHA256, rootSeed: "2", root: root)
        XCTAssertEqual(first.2.status, .appended)
        XCTAssertEqual(second.2.status, .appended)
        let snapshotA = try AnalysisPhysicalEvidenceAnchorLedgerStore.exportSnapshot(ledgerID: ledgerID, rootURL: root)
        let snapshotB = try AnalysisPhysicalEvidenceAnchorLedgerStore.exportSnapshot(ledgerID: ledgerID, rootURL: root)
        XCTAssertEqual(snapshotA, snapshotB)
        XCTAssertEqual(snapshotA.records.count, 2)
        XCTAssertEqual(snapshotA.records.last?.sequence, 2)
        XCTAssertEqual(snapshotA.declaredLedgerRootSHA256, second.2.ledgerRootSHA256)
        XCTAssertEqual(
            AnalysisDeviceWorkloadSHA256.hexDigest(try AnalysisPhysicalEvidenceAnchorLedgerCodec.encodeSnapshot(snapshotA)),
            AnalysisDeviceWorkloadSHA256.hexDigest(try AnalysisPhysicalEvidenceAnchorLedgerCodec.encodeSnapshot(snapshotB))
        )
    }

    func testExactLatestDuplicateIsIdempotentlyAccepted() throws {
        let root = try tempRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let value = try append(sequence: 1, predecessor: nil, rootSeed: "1", root: root)
        let duplicate = try AnalysisPhysicalEvidenceAnchorLedgerStore.append(
            ledgerID: ledgerID,
            anchorReceipt: value.0,
            destinationCertificate: value.1,
            rootURL: root
        )
        XCTAssertEqual(duplicate.status, .exactDuplicateAccepted)
        XCTAssertEqual(duplicate.ledgerRootSHA256, value.2.ledgerRootSHA256)
    }

    func testOlderImportIsRejectedAsRollback() throws {
        let root = try tempRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let first = try append(sequence: 1, predecessor: nil, rootSeed: "1", root: root)
        _ = try append(sequence: 2, predecessor: first.0.declaredAnchorReceiptRootSHA256, rootSeed: "2", root: root)
        XCTAssertThrowsError(
            try AnalysisPhysicalEvidenceAnchorLedgerStore.append(
                ledgerID: ledgerID,
                anchorReceipt: first.0,
                destinationCertificate: first.1,
                rootURL: root
            )
        ) { error in
            XCTAssertEqual(error as? AnalysisPhysicalEvidenceAnchorLedgerError, .rollbackImport)
        }
    }

    func testSequenceReuseWithDifferentRootsIsRejected() throws {
        let root = try tempRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        _ = try append(sequence: 1, predecessor: nil, rootSeed: "1", root: root)
        let conflicting = try receipt(sequence: 1, predecessor: nil, rootSeed: "9")
        let conflictingCertificate = try certificate(for: conflicting)
        XCTAssertThrowsError(
            try AnalysisPhysicalEvidenceAnchorLedgerStore.append(
                ledgerID: ledgerID,
                anchorReceipt: conflicting,
                destinationCertificate: conflictingCertificate,
                rootURL: root
            )
        ) { error in
            XCTAssertEqual(error as? AnalysisPhysicalEvidenceAnchorLedgerError, .sequenceReuseDifferentRoots)
        }
    }

    func testForkedPredecessorReceiptIsRejected() throws {
        let root = try tempRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        _ = try append(sequence: 1, predecessor: nil, rootSeed: "1", root: root)
        let fork = try receipt(sequence: 2, predecessor: sha("9"), rootSeed: "2")
        let forkCertificate = try certificate(for: fork)
        XCTAssertThrowsError(
            try AnalysisPhysicalEvidenceAnchorLedgerStore.append(
                ledgerID: ledgerID,
                anchorReceipt: fork,
                destinationCertificate: forkCertificate,
                rootURL: root
            )
        ) { error in
            XCTAssertEqual(error as? AnalysisPhysicalEvidenceAnchorLedgerError, .predecessorReceiptMismatch)
        }
    }

    func testStaleOrForgedCertificateFailsBeforeJournalWrite() throws {
        let root = try tempRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let receipt = try receipt(sequence: 1, predecessor: nil, rootSeed: "1")
        let valid = try certificate(for: receipt)
        let forged = AnalysisPhysicalEvidenceDestinationVerificationCertificate(
            status: valid.status,
            anchorID: valid.anchorID,
            anchorSequence: valid.anchorSequence,
            anchorReceiptRootSHA256: valid.anchorReceiptRootSHA256,
            publicationID: valid.publicationID,
            transferID: valid.transferID,
            expectedW27RootSHA256: valid.expectedW27RootSHA256,
            expectedW38RootSHA256: valid.expectedW38RootSHA256,
            expectedW40RootSHA256: valid.expectedW40RootSHA256,
            expectedW41RootSHA256: valid.expectedW41RootSHA256,
            destinationW27RootSHA256: sha("9"),
            destinationW38RootSHA256: valid.destinationW38RootSHA256,
            destinationW40RootSHA256: valid.destinationW40RootSHA256,
            destinationW41RootSHA256: valid.destinationW41RootSHA256,
            runs: valid.runs,
            limitations: valid.limitations,
            declaredCertificateRootSHA256: valid.declaredCertificateRootSHA256
        )
        XCTAssertThrowsError(
            try AnalysisPhysicalEvidenceAnchorLedgerStore.append(
                ledgerID: ledgerID,
                anchorReceipt: receipt,
                destinationCertificate: forged,
                rootURL: root
            )
        ) { error in
            XCTAssertEqual(error as? AnalysisPhysicalEvidenceAnchorLedgerError, .invalidReceiptOrCertificate)
        }
    }

    func testPendingMarkerOnlyRecoversAfterRelaunch() throws {
        let root = try tempRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let receipt = try receipt(sequence: 1, predecessor: nil, rootSeed: "1")
        let certificate = try certificate(for: receipt)
        try AnalysisPhysicalEvidenceAnchorLedgerStore.createInterruptedAppendCheckpoint(
            ledgerID: ledgerID,
            anchorReceipt: receipt,
            destinationCertificate: certificate,
            checkpoint: .pendingMarkerOnly,
            rootURL: root
        )
        XCTAssertTrue(try AnalysisPhysicalEvidenceAnchorLedgerStore.recoverIfNeeded(ledgerID: ledgerID, rootURL: root))
        let snapshot = try AnalysisPhysicalEvidenceAnchorLedgerStore.exportSnapshot(ledgerID: ledgerID, rootURL: root)
        XCTAssertEqual(snapshot.records.map(\.sequence), [1])
    }

    func testRecordWrittenBeforeHeadRecoversAfterRelaunch() throws {
        let root = try tempRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let receipt = try receipt(sequence: 1, predecessor: nil, rootSeed: "1")
        let certificate = try certificate(for: receipt)
        try AnalysisPhysicalEvidenceAnchorLedgerStore.createInterruptedAppendCheckpoint(
            ledgerID: ledgerID,
            anchorReceipt: receipt,
            destinationCertificate: certificate,
            checkpoint: .recordWrittenBeforeHead,
            rootURL: root
        )
        XCTAssertTrue(try AnalysisPhysicalEvidenceAnchorLedgerStore.recoverIfNeeded(ledgerID: ledgerID, rootURL: root))
        let duplicate = try AnalysisPhysicalEvidenceAnchorLedgerStore.append(
            ledgerID: ledgerID,
            anchorReceipt: receipt,
            destinationCertificate: certificate,
            rootURL: root
        )
        XCTAssertEqual(duplicate.status, .exactDuplicateAccepted)
    }

    func testCorruptPendingMarkerIsPreservedAndFailsClosed() throws {
        let root = try tempRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let receipt = try receipt(sequence: 1, predecessor: nil, rootSeed: "1")
        let certificate = try certificate(for: receipt)
        try AnalysisPhysicalEvidenceAnchorLedgerStore.createInterruptedAppendCheckpoint(
            ledgerID: ledgerID,
            anchorReceipt: receipt,
            destinationCertificate: certificate,
            checkpoint: .pendingMarkerOnly,
            rootURL: root
        )
        let pending = root.appendingPathComponent("anchor-ledgers/\(ledgerID)/\(AnalysisPhysicalEvidenceAnchorLedgerStore.pendingFileName)")
        try Data("corrupt".utf8).write(to: pending)
        XCTAssertThrowsError(try AnalysisPhysicalEvidenceAnchorLedgerStore.recoverIfNeeded(ledgerID: ledgerID, rootURL: root)) { error in
            XCTAssertEqual(error as? AnalysisPhysicalEvidenceAnchorLedgerError, .ambiguousRecoveryState)
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: pending.path))
    }

    func testUnexpectedOrphanRecordFailsClosedOnRelaunch() throws {
        let root = try tempRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let receipt = try receipt(sequence: 1, predecessor: nil, rootSeed: "1")
        let certificate = try certificate(for: receipt)
        try AnalysisPhysicalEvidenceAnchorLedgerStore.createInterruptedAppendCheckpoint(
            ledgerID: ledgerID,
            anchorReceipt: receipt,
            destinationCertificate: certificate,
            checkpoint: .recordWrittenBeforeHead,
            rootURL: root
        )
        let pending = root.appendingPathComponent("anchor-ledgers/\(ledgerID)/\(AnalysisPhysicalEvidenceAnchorLedgerStore.pendingFileName)")
        try FileManager.default.removeItem(at: pending)
        XCTAssertThrowsError(try AnalysisPhysicalEvidenceAnchorLedgerStore.exportSnapshot(ledgerID: ledgerID, rootURL: root)) { error in
            XCTAssertEqual(error as? AnalysisPhysicalEvidenceAnchorLedgerError, .corruptedLedger)
        }
    }

    func testHeadTamperAndExtraFileFailClosed() throws {
        let root = try tempRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        _ = try append(sequence: 1, predecessor: nil, rootSeed: "1", root: root)
        let ledger = root.appendingPathComponent("anchor-ledgers/\(ledgerID)", isDirectory: true)
        try Data("extra".utf8).write(to: ledger.appendingPathComponent("unexpected.json"))
        XCTAssertThrowsError(try AnalysisPhysicalEvidenceAnchorLedgerStore.exportSnapshot(ledgerID: ledgerID, rootURL: root))
    }
}

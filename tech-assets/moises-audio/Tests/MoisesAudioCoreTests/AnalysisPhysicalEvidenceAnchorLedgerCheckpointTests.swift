import Foundation
import XCTest
@testable import MoisesAudioCore

final class AnalysisPhysicalEvidenceAnchorLedgerCheckpointTests: XCTestCase {
    private let ledgerID = "ledger-w44"
    private let anchorID = "anchor-w44"

    private func sha(_ character: Character) -> String {
        String(repeating: String(character), count: 64)
    }

    private var runs: [AnalysisPhysicalEvidenceBatchRunSummary] {
        [
            .init(runID: "run-a", workloadExecutionID: "exec-a", w39BundleRootSHA256: sha("a")),
            .init(runID: "run-b", workloadExecutionID: "exec-b", w39BundleRootSHA256: sha("b"))
        ]
    }

    private func tempRoot(_ prefix: String = "w44-checkpoint") throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(prefix)-\(UUID().uuidString)", isDirectory: true)
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
            approvalReference: "HQ-W44-ANCHOR-\(sequence)",
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

    private func destinationCertificate(
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

    @discardableResult
    private func append(
        sequence: UInt64,
        predecessor: String?,
        rootSeed: Character,
        root: URL
    ) throws -> (AnalysisPhysicalEvidenceAnchorReceipt, AnalysisPhysicalEvidenceAnchorLedgerAppendReceipt) {
        let receipt = try receipt(sequence: sequence, predecessor: predecessor, rootSeed: rootSeed)
        let certificate = try destinationCertificate(for: receipt)
        let appendReceipt = try AnalysisPhysicalEvidenceAnchorLedgerStore.append(
            ledgerID: ledgerID,
            anchorReceipt: receipt,
            destinationCertificate: certificate,
            rootURL: root
        )
        return (receipt, appendReceipt)
    }

    private func expectation(
        snapshot: AnalysisPhysicalEvidenceAnchorLedgerSnapshot,
        checkpointSequence: UInt64,
        predecessorCheckpoint: String? = nil,
        ledgerID: String? = nil,
        anchorID: String? = nil,
        minimumSequence: UInt64 = 1,
        latestSequence: UInt64? = nil,
        receiptRoot: String? = nil,
        ledgerRoot: String? = nil
    ) -> AnalysisPhysicalEvidenceLedgerCheckpointExpectation {
        let latest = snapshot.records.last!
        return .init(
            checkpointID: "hq-ledger-checkpoint",
            checkpointSequence: checkpointSequence,
            authority: "HQ_LATE_INTEGRATION",
            approvalReference: "HQ-W44-CHECKPOINT-\(checkpointSequence)",
            expectedLedgerID: ledgerID ?? snapshot.ledgerID,
            expectedAnchorID: anchorID ?? snapshot.anchorID,
            minimumLedgerSequence: minimumSequence,
            expectedLatestLedgerSequence: latestSequence ?? latest.sequence,
            expectedLatestAnchorReceiptRootSHA256: receiptRoot ?? latest.anchorReceiptRootSHA256,
            expectedLedgerRootSHA256: ledgerRoot ?? snapshot.declaredLedgerRootSHA256,
            expectedPredecessorCheckpointCertificateRootSHA256: predecessorCheckpoint
        )
    }

    func testCurrentLedgerVerificationAndCertificateAreDeterministic() throws {
        let root = try tempRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let first = try append(sequence: 1, predecessor: nil, rootSeed: "1", root: root)
        _ = try append(sequence: 2, predecessor: first.0.declaredAnchorReceiptRootSHA256, rootSeed: "2", root: root)
        let snapshot = try AnalysisPhysicalEvidenceAnchorLedgerStore.exportSnapshot(ledgerID: ledgerID, rootURL: root)
        let expected = expectation(snapshot: snapshot, checkpointSequence: 1)
        let certificateA = try AnalysisPhysicalEvidenceLedgerCheckpointVerifier.verifyLedger(
            rootURL: root,
            expectation: expected
        )
        let certificateB = try AnalysisPhysicalEvidenceLedgerCheckpointVerifier.verifyLedger(
            rootURL: root,
            expectation: expected
        )
        XCTAssertEqual(certificateA, certificateB)
        XCTAssertEqual(certificateA.recordCount, 2)
        XCTAssertEqual(certificateA.observedLatestLedgerSequence, 2)
        XCTAssertEqual(certificateA.observedLedgerRootSHA256, snapshot.declaredLedgerRootSHA256)
        XCTAssertEqual(
            try AnalysisPhysicalEvidenceLedgerCheckpointCertificateRoot.compute(certificateA),
            certificateA.declaredCertificateRootSHA256
        )
        try AnalysisPhysicalEvidenceLedgerCheckpointVerifier.validateCertificate(certificateA, expectation: expected)
        try AnalysisPhysicalEvidenceLedgerCheckpointVerifier.verifyCertificateAgainstCurrentLedger(
            certificateA,
            rootURL: root,
            expectation: expected
        )
        XCTAssertEqual(
            try AnalysisPhysicalEvidenceLedgerCheckpointCodec.decodeCertificate(
                AnalysisPhysicalEvidenceLedgerCheckpointCodec.encodeCertificate(certificateA)
            ),
            certificateA
        )
    }

    func testWholeLedgerRollbackToOlderInternallyValidCopyIsRejectedByExternalExpectation() throws {
        let root = try tempRoot("w44-live")
        let backupRoot = try tempRoot("w44-backup")
        defer {
            try? FileManager.default.removeItem(at: root)
            try? FileManager.default.removeItem(at: backupRoot)
        }
        let first = try append(sequence: 1, predecessor: nil, rootSeed: "1", root: root)
        let oldLedgerURL = root.appendingPathComponent("anchor-ledgers/\(ledgerID)", isDirectory: true)
        let backupParent = backupRoot.appendingPathComponent("anchor-ledgers", isDirectory: true)
        try FileManager.default.createDirectory(at: backupParent, withIntermediateDirectories: true)
        try FileManager.default.copyItem(
            at: oldLedgerURL,
            to: backupParent.appendingPathComponent(ledgerID, isDirectory: true)
        )
        _ = try append(sequence: 2, predecessor: first.0.declaredAnchorReceiptRootSHA256, rootSeed: "2", root: root)
        let currentSnapshot = try AnalysisPhysicalEvidenceAnchorLedgerStore.exportSnapshot(ledgerID: ledgerID, rootURL: root)
        let currentExpectation = expectation(snapshot: currentSnapshot, checkpointSequence: 1)

        try FileManager.default.removeItem(at: oldLedgerURL)
        try FileManager.default.copyItem(
            at: backupParent.appendingPathComponent(ledgerID, isDirectory: true),
            to: oldLedgerURL
        )
        XCTAssertThrowsError(
            try AnalysisPhysicalEvidenceLedgerCheckpointVerifier.verifyLedger(
                rootURL: root,
                expectation: currentExpectation
            )
        ) { error in
            XCTAssertEqual(error as? AnalysisPhysicalEvidenceLedgerCheckpointError, .ledgerSequenceMismatch)
        }
    }

    func testStaleCachedSnapshotCannotSatisfyCurrentExpectation() throws {
        let root = try tempRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let first = try append(sequence: 1, predecessor: nil, rootSeed: "1", root: root)
        let staleSnapshot = try AnalysisPhysicalEvidenceAnchorLedgerStore.exportSnapshot(ledgerID: ledgerID, rootURL: root)
        _ = try append(sequence: 2, predecessor: first.0.declaredAnchorReceiptRootSHA256, rootSeed: "2", root: root)
        let currentSnapshot = try AnalysisPhysicalEvidenceAnchorLedgerStore.exportSnapshot(ledgerID: ledgerID, rootURL: root)
        let currentExpectation = expectation(snapshot: currentSnapshot, checkpointSequence: 1)
        XCTAssertThrowsError(
            try AnalysisPhysicalEvidenceLedgerCheckpointVerifier.verifyAlreadyValidatedSnapshot(
                staleSnapshot,
                expectation: currentExpectation
            )
        ) { error in
            XCTAssertEqual(error as? AnalysisPhysicalEvidenceLedgerCheckpointError, .ledgerSequenceMismatch)
        }
    }

    func testMixedSequenceAndOldLedgerRootAreRejected() throws {
        let root = try tempRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let first = try append(sequence: 1, predecessor: nil, rootSeed: "1", root: root)
        let oldSnapshot = try AnalysisPhysicalEvidenceAnchorLedgerStore.exportSnapshot(ledgerID: ledgerID, rootURL: root)
        _ = try append(sequence: 2, predecessor: first.0.declaredAnchorReceiptRootSHA256, rootSeed: "2", root: root)
        let current = try AnalysisPhysicalEvidenceAnchorLedgerStore.exportSnapshot(ledgerID: ledgerID, rootURL: root)
        let mixed = expectation(
            snapshot: current,
            checkpointSequence: 1,
            ledgerRoot: oldSnapshot.declaredLedgerRootSHA256
        )
        XCTAssertThrowsError(
            try AnalysisPhysicalEvidenceLedgerCheckpointVerifier.verifyLedger(rootURL: root, expectation: mixed)
        ) { error in
            XCTAssertEqual(error as? AnalysisPhysicalEvidenceLedgerCheckpointError, .ledgerRootMismatch)
        }
    }

    func testMixedLatestReceiptRootIsRejected() throws {
        let root = try tempRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let first = try append(sequence: 1, predecessor: nil, rootSeed: "1", root: root)
        let oldSnapshot = try AnalysisPhysicalEvidenceAnchorLedgerStore.exportSnapshot(ledgerID: ledgerID, rootURL: root)
        _ = try append(sequence: 2, predecessor: first.0.declaredAnchorReceiptRootSHA256, rootSeed: "2", root: root)
        let current = try AnalysisPhysicalEvidenceAnchorLedgerStore.exportSnapshot(ledgerID: ledgerID, rootURL: root)
        let mixed = expectation(
            snapshot: current,
            checkpointSequence: 1,
            receiptRoot: oldSnapshot.records.last!.anchorReceiptRootSHA256
        )
        XCTAssertThrowsError(
            try AnalysisPhysicalEvidenceLedgerCheckpointVerifier.verifyLedger(rootURL: root, expectation: mixed)
        ) { error in
            XCTAssertEqual(error as? AnalysisPhysicalEvidenceLedgerCheckpointError, .latestAnchorReceiptRootMismatch)
        }
    }

    func testLedgerAndAnchorIdentitySubstitutionAreRejected() throws {
        let root = try tempRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        _ = try append(sequence: 1, predecessor: nil, rootSeed: "1", root: root)
        let snapshot = try AnalysisPhysicalEvidenceAnchorLedgerStore.exportSnapshot(ledgerID: ledgerID, rootURL: root)
        let wrongLedger = expectation(snapshot: snapshot, checkpointSequence: 1, ledgerID: "other-ledger")
        XCTAssertThrowsError(
            try AnalysisPhysicalEvidenceLedgerCheckpointVerifier.verifyAlreadyValidatedSnapshot(snapshot, expectation: wrongLedger)
        ) { error in
            XCTAssertEqual(error as? AnalysisPhysicalEvidenceLedgerCheckpointError, .ledgerIdentityMismatch)
        }
        let wrongAnchor = expectation(snapshot: snapshot, checkpointSequence: 1, anchorID: "other-anchor")
        XCTAssertThrowsError(
            try AnalysisPhysicalEvidenceLedgerCheckpointVerifier.verifyAlreadyValidatedSnapshot(snapshot, expectation: wrongAnchor)
        ) { error in
            XCTAssertEqual(error as? AnalysisPhysicalEvidenceLedgerCheckpointError, .anchorIdentityMismatch)
        }
    }

    func testCheckpointReplayAndPredecessorChainAreRejected() throws {
        let root = try tempRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let first = try append(sequence: 1, predecessor: nil, rootSeed: "1", root: root)
        let snapshot1 = try AnalysisPhysicalEvidenceAnchorLedgerStore.exportSnapshot(ledgerID: ledgerID, rootURL: root)
        let expectation1 = expectation(snapshot: snapshot1, checkpointSequence: 1)
        let certificate1 = try AnalysisPhysicalEvidenceLedgerCheckpointVerifier.verifyLedger(rootURL: root, expectation: expectation1)

        _ = try append(sequence: 2, predecessor: first.0.declaredAnchorReceiptRootSHA256, rootSeed: "2", root: root)
        let snapshot2 = try AnalysisPhysicalEvidenceAnchorLedgerStore.exportSnapshot(ledgerID: ledgerID, rootURL: root)
        let expectation2 = expectation(
            snapshot: snapshot2,
            checkpointSequence: 2,
            predecessorCheckpoint: certificate1.declaredCertificateRootSHA256
        )
        let certificate2 = try AnalysisPhysicalEvidenceLedgerCheckpointVerifier.verifyLedger(rootURL: root, expectation: expectation2)
        XCTAssertNotEqual(certificate1.declaredCertificateRootSHA256, certificate2.declaredCertificateRootSHA256)

        XCTAssertThrowsError(
            try AnalysisPhysicalEvidenceLedgerCheckpointVerifier.validateCertificate(certificate1, expectation: expectation2)
        ) { error in
            XCTAssertEqual(error as? AnalysisPhysicalEvidenceLedgerCheckpointError, .expectationRootMismatch)
        }
        let wrongPredecessor = expectation(
            snapshot: snapshot2,
            checkpointSequence: 2,
            predecessorCheckpoint: sha("9")
        )
        XCTAssertThrowsError(
            try AnalysisPhysicalEvidenceLedgerCheckpointVerifier.validateCertificate(certificate2, expectation: wrongPredecessor)
        ) { error in
            XCTAssertEqual(error as? AnalysisPhysicalEvidenceLedgerCheckpointError, .expectationRootMismatch)
        }
    }

    func testForgedCertificateRootIsRejected() throws {
        let root = try tempRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        _ = try append(sequence: 1, predecessor: nil, rootSeed: "1", root: root)
        let snapshot = try AnalysisPhysicalEvidenceAnchorLedgerStore.exportSnapshot(ledgerID: ledgerID, rootURL: root)
        let expected = expectation(snapshot: snapshot, checkpointSequence: 1)
        let valid = try AnalysisPhysicalEvidenceLedgerCheckpointVerifier.verifyLedger(rootURL: root, expectation: expected)
        let forged = AnalysisPhysicalEvidenceLedgerCheckpointCertificate(
            status: valid.status,
            checkpointID: valid.checkpointID,
            checkpointSequence: valid.checkpointSequence,
            checkpointExpectationRootSHA256: valid.checkpointExpectationRootSHA256,
            ledgerID: valid.ledgerID,
            anchorID: valid.anchorID,
            expectedMinimumLedgerSequence: valid.expectedMinimumLedgerSequence,
            expectedLatestLedgerSequence: valid.expectedLatestLedgerSequence,
            observedLatestLedgerSequence: valid.observedLatestLedgerSequence,
            expectedLatestAnchorReceiptRootSHA256: valid.expectedLatestAnchorReceiptRootSHA256,
            observedLatestAnchorReceiptRootSHA256: valid.observedLatestAnchorReceiptRootSHA256,
            expectedLedgerRootSHA256: valid.expectedLedgerRootSHA256,
            observedLedgerRootSHA256: valid.observedLedgerRootSHA256,
            observedLatestCertificateRootSHA256: valid.observedLatestCertificateRootSHA256,
            observedLatestRecordRootSHA256: valid.observedLatestRecordRootSHA256,
            recordCount: valid.recordCount,
            predecessorCheckpointCertificateRootSHA256: valid.predecessorCheckpointCertificateRootSHA256,
            limitations: valid.limitations,
            declaredCertificateRootSHA256: sha("0")
        )
        XCTAssertThrowsError(
            try AnalysisPhysicalEvidenceLedgerCheckpointVerifier.validateCertificate(forged, expectation: expected)
        ) { error in
            XCTAssertEqual(error as? AnalysisPhysicalEvidenceLedgerCheckpointError, .certificateRootMismatch)
        }
    }

    func testInvalidExpectationFailsClosed() throws {
        let invalid = AnalysisPhysicalEvidenceLedgerCheckpointExpectation(
            checkpointID: "hq-ledger-checkpoint",
            checkpointSequence: 2,
            authority: "HQ_LATE_INTEGRATION",
            approvalReference: "HQ-W44-BAD",
            expectedLedgerID: ledgerID,
            expectedAnchorID: anchorID,
            minimumLedgerSequence: 2,
            expectedLatestLedgerSequence: 1,
            expectedLatestAnchorReceiptRootSHA256: sha("1"),
            expectedLedgerRootSHA256: sha("2"),
            expectedPredecessorCheckpointCertificateRootSHA256: nil
        )
        XCTAssertFalse(AnalysisPhysicalEvidenceLedgerCheckpointVerifier.validateExpectation(invalid))
    }
}

import Foundation
import XCTest
@testable import MoisesAudioCore

final class AnalysisPhysicalEvidenceAnchorLedgerRecoveryEdgeTests: XCTestCase {
    private let ledgerID = "ledger-w43-edge"

    private func sha(_ character: Character) -> String {
        String(repeating: String(character), count: 64)
    }

    private func tempRoot() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("w43-ledger-edge-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func pair(
        sequence: UInt64,
        anchorID: String = "anchor-w43-edge",
        predecessor: String? = nil
    ) throws -> (AnalysisPhysicalEvidenceAnchorReceipt, AnalysisPhysicalEvidenceDestinationVerificationCertificate) {
        let runs = [AnalysisPhysicalEvidenceBatchRunSummary(
            runID: "run-edge",
            workloadExecutionID: "exec-edge-\(sequence)",
            w39BundleRootSHA256: sha("a")
        )]
        let anchor = AnalysisPhysicalEvidenceExternalRootAnchor(
            anchorID: anchorID,
            anchorSequence: sequence,
            authority: "HQ_LATE_INTEGRATION",
            approvalReference: "HQ-W43-EDGE-\(sequence)",
            publicationID: "batch-edge-\(sequence)",
            transferID: "transfer-edge-\(sequence)",
            w27RootSHA256: sha("b"),
            w38RootSHA256: sha("c"),
            w40RootSHA256: sha("d"),
            w41RootSHA256: sha("e"),
            runs: runs,
            predecessorAnchorReceiptRootSHA256: predecessor
        )
        let receipt = try AnalysisPhysicalEvidenceAnchorReceiptIssuer.issue(anchor: anchor)
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
        let certificateRoot = try AnalysisPhysicalEvidenceDestinationCertificateRoot.compute(provisional)
        let certificate = AnalysisPhysicalEvidenceDestinationVerificationCertificate(
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
            declaredCertificateRootSHA256: certificateRoot
        )
        return (receipt, certificate)
    }

    func testHeadAlreadyAdvancedButPendingMarkerRemainsIsRecovered() throws {
        let root = try tempRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let value = try pair(sequence: 1)
        _ = try AnalysisPhysicalEvidenceAnchorLedgerStore.append(
            ledgerID: ledgerID,
            anchorReceipt: value.0,
            destinationCertificate: value.1,
            rootURL: root
        )

        let ledgerURL = root.appendingPathComponent("anchor-ledgers/\(ledgerID)", isDirectory: true)
        let headURL = ledgerURL.appendingPathComponent(AnalysisPhysicalEvidenceAnchorLedgerStore.headFileName)
        let head = try AnalysisPhysicalEvidenceAnchorLedgerCodec.decodeHead(Data(contentsOf: headURL))
        let summary = try XCTUnwrap(head.records.last)
        let record = try AnalysisPhysicalEvidenceAnchorLedgerCodec.decodeRecord(
            Data(contentsOf: ledgerURL.appendingPathComponent(summary.relativePath))
        )
        let pending = AnalysisPhysicalEvidenceAnchorLedgerPendingAppend(
            ledgerID: ledgerID,
            candidateRecord: record,
            candidateRelativePath: summary.relativePath,
            previousLedgerRootSHA256: nil,
            previousLatestRecordRootSHA256: nil
        )
        let pendingURL = ledgerURL.appendingPathComponent(AnalysisPhysicalEvidenceAnchorLedgerStore.pendingFileName)
        try AnalysisPhysicalEvidenceAnchorLedgerCodec.encodePending(pending).write(to: pendingURL)

        XCTAssertTrue(try AnalysisPhysicalEvidenceAnchorLedgerStore.recoverIfNeeded(ledgerID: ledgerID, rootURL: root))
        XCTAssertFalse(FileManager.default.fileExists(atPath: pendingURL.path))
        XCTAssertEqual(
            try AnalysisPhysicalEvidenceAnchorLedgerStore.exportSnapshot(ledgerID: ledgerID, rootURL: root).declaredLedgerRootSHA256,
            head.declaredLedgerRootSHA256
        )
    }

    func testTruncatedHeadFailsClosedOnRelaunch() throws {
        let root = try tempRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let value = try pair(sequence: 1)
        _ = try AnalysisPhysicalEvidenceAnchorLedgerStore.append(
            ledgerID: ledgerID,
            anchorReceipt: value.0,
            destinationCertificate: value.1,
            rootURL: root
        )
        let headURL = root.appendingPathComponent("anchor-ledgers/\(ledgerID)/\(AnalysisPhysicalEvidenceAnchorLedgerStore.headFileName)")
        try Data("{\"schemaVersion\":1}".utf8).write(to: headURL)
        XCTAssertThrowsError(try AnalysisPhysicalEvidenceAnchorLedgerStore.exportSnapshot(ledgerID: ledgerID, rootURL: root)) { error in
            XCTAssertEqual(error as? AnalysisPhysicalEvidenceAnchorLedgerError, .corruptedLedger)
        }
    }

    func testSequenceGapCannotInitializeLedger() throws {
        let root = try tempRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let value = try pair(sequence: 2)
        XCTAssertThrowsError(
            try AnalysisPhysicalEvidenceAnchorLedgerStore.append(
                ledgerID: ledgerID,
                anchorReceipt: value.0,
                destinationCertificate: value.1,
                rootURL: root
            )
        ) { error in
            XCTAssertEqual(error as? AnalysisPhysicalEvidenceAnchorLedgerError, .sequenceGap)
        }
    }

    func testAnchorIdentityCannotSwitchInsideLedger() throws {
        let root = try tempRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let first = try pair(sequence: 1)
        _ = try AnalysisPhysicalEvidenceAnchorLedgerStore.append(
            ledgerID: ledgerID,
            anchorReceipt: first.0,
            destinationCertificate: first.1,
            rootURL: root
        )
        let second = try pair(
            sequence: 2,
            anchorID: "different-anchor",
            predecessor: first.0.declaredAnchorReceiptRootSHA256
        )
        XCTAssertThrowsError(
            try AnalysisPhysicalEvidenceAnchorLedgerStore.append(
                ledgerID: ledgerID,
                anchorReceipt: second.0,
                destinationCertificate: second.1,
                rootURL: root
            )
        ) { error in
            XCTAssertEqual(error as? AnalysisPhysicalEvidenceAnchorLedgerError, .ledgerAnchorMismatch)
        }
    }
}

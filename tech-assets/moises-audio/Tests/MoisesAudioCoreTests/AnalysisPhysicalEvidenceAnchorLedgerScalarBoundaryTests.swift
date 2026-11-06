import Foundation
import XCTest
@testable import MoisesAudioCore

final class AnalysisPhysicalEvidenceAnchorLedgerScalarBoundaryTests: XCTestCase {
    func testUInt64MaxHeadSequenceFailsClosedWithoutIntegerTrap() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("w43-scalar-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let ledgerID = "ledger-w43-scalar"
        let ledgerURL = root.appendingPathComponent("anchor-ledgers/\(ledgerID)", isDirectory: true)
        try FileManager.default.createDirectory(at: ledgerURL, withIntermediateDirectories: true)

        let sha = String(repeating: "a", count: 64)
        let summary = AnalysisPhysicalEvidenceAnchorLedgerRecordSummary(
            sequence: 1,
            relativePath: "records/00000000000000000001-deadbeefdeadbeef.json",
            anchorReceiptRootSHA256: sha,
            certificateRootSHA256: sha,
            predecessorLedgerRecordRootSHA256: nil,
            recordRootSHA256: sha
        )
        let corruptHead = AnalysisPhysicalEvidenceAnchorLedgerHead(
            ledgerID: ledgerID,
            anchorID: "anchor-w43-scalar",
            records: [summary],
            latestSequence: UInt64.max,
            latestAnchorReceiptRootSHA256: sha,
            latestCertificateRootSHA256: sha,
            latestRecordRootSHA256: sha,
            declaredLedgerRootSHA256: sha
        )
        try AnalysisPhysicalEvidenceAnchorLedgerCodec.encodeHead(corruptHead).write(
            to: ledgerURL.appendingPathComponent(AnalysisPhysicalEvidenceAnchorLedgerStore.headFileName)
        )

        XCTAssertThrowsError(
            try AnalysisPhysicalEvidenceAnchorLedgerStore.exportSnapshot(
                ledgerID: ledgerID,
                rootURL: root
            )
        ) { error in
            XCTAssertEqual(error as? AnalysisPhysicalEvidenceAnchorLedgerError, .corruptedLedger)
        }
    }
}

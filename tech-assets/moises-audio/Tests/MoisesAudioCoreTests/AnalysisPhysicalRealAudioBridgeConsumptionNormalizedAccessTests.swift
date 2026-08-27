import Foundation
import XCTest
@testable import MoisesAudioCore

final class AnalysisPhysicalRealAudioBridgeConsumptionNormalizedAccessTests: XCTestCase {
    private func sha(_ character: Character) -> String {
        String(repeating: String(character), count: 64)
    }

    private func root() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("w55-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func custody() -> AnalysisPhysicalRealAudioBridgeConsumptionCustody {
        .init(authority: "HQ_LATE_INTEGRATION", approvalReference: "HQ-W55", custodyID: "custody-w55")
    }

    private func certificate(index: Int = 1) throws -> AnalysisPhysicalRealAudioParityBridgeCertificate {
        let digits = Array("0123456789abcdef")
        let a = digits[(index + 1) % digits.count]
        let b = digits[(index + 2) % digits.count]
        let provisional = AnalysisPhysicalRealAudioParityBridgeCertificate(
            bridgeID: "bridge-w55-\(index)",
            expectationRootSHA256: String(repeating: String(digits[(index + 3) % digits.count]), count: 64),
            w47PackageRootSHA256: String(repeating: String(a), count: 64),
            w47PackageBytesSHA256: sha("4"),
            manifestID: "manifest-w55-\(index)",
            manifestSHA256: sha("5"),
            runtimeBindingSHA256: sha("6"),
            physicalSessionID: "session-w55-\(index)",
            auditedProjectReportSHA256: sha("7"),
            w46BindingSHA256: sha("8"),
            w46AdjudicationStatus: .notReadyForHQJudgment,
            w46AdjudicationReportRootSHA256: String(repeating: String(b), count: 64),
            limitations: AnalysisPhysicalRealAudioParityBridge.limitations,
            declaredCertificateRootSHA256: String(repeating: "0", count: 64)
        )
        let root = try AnalysisPhysicalRealAudioParityBridgeCertificateValidator.certificateSHA256(provisional)
        return .init(
            bridgeID: provisional.bridgeID,
            expectationRootSHA256: provisional.expectationRootSHA256,
            w47PackageRootSHA256: provisional.w47PackageRootSHA256,
            w47PackageBytesSHA256: provisional.w47PackageBytesSHA256,
            manifestID: provisional.manifestID,
            manifestSHA256: provisional.manifestSHA256,
            runtimeBindingSHA256: provisional.runtimeBindingSHA256,
            physicalSessionID: provisional.physicalSessionID,
            auditedProjectReportSHA256: provisional.auditedProjectReportSHA256,
            w46BindingSHA256: provisional.w46BindingSHA256,
            w46AdjudicationStatus: provisional.w46AdjudicationStatus,
            w46AdjudicationReportRootSHA256: provisional.w46AdjudicationReportRootSHA256,
            limitations: provisional.limitations,
            declaredCertificateRootSHA256: root
        )
    }

    func testBrandNewLedgerNormalizesToSequenceZeroReceipt() throws {
        let root = try root()
        defer { try? FileManager.default.removeItem(at: root) }
        let state = try AnalysisPhysicalRealAudioBridgeConsumptionNormalizedAccess.withExclusiveNormalizedLedger(
            ledgerID: "ledger", rootURL: root, requireHead: false
        ) { _, state in state }
        XCTAssertNil(state.head)
        XCTAssertEqual(state.receipt.latestSequence, 0)
        XCTAssertNil(state.receipt.ledgerRootSHA256)
        XCTAssertNil(state.receipt.latestRecordRootSHA256)
        XCTAssertTrue(AnalysisPhysicalRealAudioBridgeConsumptionNormalizedAccess.validateReceipt(
            state.receipt, head: nil
        ))
    }

    func testTwoDirectoryTempsArePreflightedThenRemovedTogether() throws {
        let root = try root()
        defer { try? FileManager.default.removeItem(at: root) }
        try AnalysisPhysicalRealAudioBridgeConsumptionSecureFilesystem.ensureDirectories(
            ledgerID: "ledger", rootURL: root, fileManager: .default
        )
        let ledger = AnalysisPhysicalRealAudioBridgeConsumptionSecureFilesystem.ledgerURL(
            ledgerID: "ledger", rootURL: root
        )
        let records = ledger.appendingPathComponent("records", isDirectory: true)
        let ledgerTemp = ledger.appendingPathComponent(".w53-pub-ledger-w55.tmp")
        let recordTemp = records.appendingPathComponent(".w53-pub-record-w55.tmp")
        try Data("ledger-temp".utf8).write(to: ledgerTemp)
        try Data("record-temp".utf8).write(to: recordTemp)

        let receipt = try AnalysisPhysicalRealAudioBridgeConsumptionNormalizedAccess.withExclusiveNormalizedLedger(
            ledgerID: "ledger", rootURL: root, requireHead: false
        ) { _, state in state.receipt }
        XCTAssertEqual(receipt.removedLedgerTemporaryCount, 1)
        XCTAssertEqual(receipt.removedRecordTemporaryCount, 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: ledgerTemp.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: recordTemp.path))
    }

    func testInvalidRecordsTempPreflightLeavesLedgerTempUntouched() throws {
        let root = try root()
        defer { try? FileManager.default.removeItem(at: root) }
        try AnalysisPhysicalRealAudioBridgeConsumptionSecureFilesystem.ensureDirectories(
            ledgerID: "ledger", rootURL: root, fileManager: .default
        )
        let ledger = AnalysisPhysicalRealAudioBridgeConsumptionSecureFilesystem.ledgerURL(
            ledgerID: "ledger", rootURL: root
        )
        let records = ledger.appendingPathComponent("records", isDirectory: true)
        let ledgerTemp = ledger.appendingPathComponent(".w53-pub-ledger-valid.tmp")
        try Data("valid".utf8).write(to: ledgerTemp)
        let outside = root.appendingPathComponent("outside-w55")
        try Data("outside".utf8).write(to: outside)
        let bad = records.appendingPathComponent(".w53-pub-record-bad.tmp")
        try FileManager.default.createSymbolicLink(at: bad, withDestinationURL: outside)

        XCTAssertThrowsError(try AnalysisPhysicalRealAudioBridgeConsumptionNormalizedAccess.withExclusiveNormalizedLedger(
            ledgerID: "ledger", rootURL: root, requireHead: false
        ) { _, state in state }) { error in
            XCTAssertEqual(error as? AnalysisPhysicalRealAudioBridgeConsumptionNamespaceError, .symbolicLinkRejected)
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: ledgerTemp.path))
    }

    func testInterruptedRecordWriteIsRecoveredBeforeReceiptIsIssued() throws {
        let root = try root()
        defer { try? FileManager.default.removeItem(at: root) }
        XCTAssertThrowsError(try AnalysisPhysicalRealAudioBridgeConsumptionSecureStore.appendForTesting(
            ledgerID: "ledger",
            certificate: certificate(),
            custody: custody(),
            rootURL: root,
            injectedFault: .afterRecordWrite
        ))
        let state = try AnalysisPhysicalRealAudioBridgeConsumptionNormalizedAccess.withExclusiveNormalizedLedger(
            ledgerID: "ledger", rootURL: root, requireHead: true
        ) { _, state in state }
        XCTAssertEqual(state.head?.latestSequence, 1)
        XCTAssertTrue(state.receipt.recoveredInterruptedAppend)
        XCTAssertEqual(state.receipt.latestSequence, 1)
        XCTAssertEqual(state.receipt.ledgerRootSHA256, state.head?.declaredLedgerRootSHA256)
    }

    func testReceiptMutationCannotReuseOldRoot() throws {
        let root = try root()
        defer { try? FileManager.default.removeItem(at: root) }
        _ = try AnalysisPhysicalRealAudioBridgeConsumptionSecureStore.append(
            ledgerID: "ledger", certificate: certificate(), custody: custody(), rootURL: root
        )
        let state = try AnalysisPhysicalRealAudioBridgeConsumptionNormalizedAccess.withExclusiveNormalizedLedger(
            ledgerID: "ledger", rootURL: root, requireHead: true
        ) { _, state in state }
        let mutated = AnalysisPhysicalRealAudioBridgeConsumptionNormalizedAccessReceipt(
            ledgerID: state.receipt.ledgerID,
            removedLedgerTemporaryCount: state.receipt.removedLedgerTemporaryCount + 1,
            removedRecordTemporaryCount: state.receipt.removedRecordTemporaryCount,
            recoveredInterruptedAppend: state.receipt.recoveredInterruptedAppend,
            latestSequence: state.receipt.latestSequence,
            ledgerRootSHA256: state.receipt.ledgerRootSHA256,
            latestRecordRootSHA256: state.receipt.latestRecordRootSHA256,
            declaredReceiptRootSHA256: state.receipt.declaredReceiptRootSHA256
        )
        XCTAssertFalse(AnalysisPhysicalRealAudioBridgeConsumptionNormalizedAccess.validateReceipt(
            mutated, head: state.head
        ))
    }

    func testNormalizedCustodyBundlePreservesW52RootsAndAddsNormalizationReceipt() throws {
        let root = try root()
        defer { try? FileManager.default.removeItem(at: root) }
        _ = try AnalysisPhysicalRealAudioBridgeConsumptionSecureStore.append(
            ledgerID: "ledger", certificate: certificate(), custody: custody(), rootURL: root
        )
        let observed = try AnalysisPhysicalRealAudioBridgeConsumptionNormalizedCustodyManager.observeSnapshot(
            ledgerID: "ledger", rootURL: root
        )
        let bundle = try AnalysisPhysicalRealAudioBridgeConsumptionNormalizedCustodyManager.makeCustodyBundle(
            ledgerID: "ledger",
            expectedSnapshot: observed.snapshot,
            transactionID: "tx-w55",
            checkpointID: "checkpoint-w55",
            checkpointSequence: 1,
            checkpointApprovalReference: "HQ-W55-CHECKPOINT",
            handoffID: "handoff-w55",
            handoffApprovalReference: "HQ-W55-HANDOFF",
            rootURL: root
        )
        XCTAssertEqual(bundle.custodyBundle.snapshot, observed.snapshot)
        XCTAssertTrue(AnalysisPhysicalRealAudioBridgeConsumptionQuiescentCustodyManager.validateReceipt(
            bundle.custodyBundle.receipt,
            snapshot: bundle.custodyBundle.snapshot,
            checkpoint: bundle.custodyBundle.checkpoint,
            handoff: bundle.custodyBundle.handoff
        ))
        let reopened = try AnalysisPhysicalRealAudioBridgeConsumptionSecureStore.loadValidatedHead(
            ledgerID: "ledger", rootURL: root
        )
        XCTAssertTrue(AnalysisPhysicalRealAudioBridgeConsumptionNormalizedAccess.validateReceipt(
            bundle.normalizationReceipt,
            head: reopened
        ))
    }
}

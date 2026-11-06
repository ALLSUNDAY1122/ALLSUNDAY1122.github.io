import Foundation
import XCTest
@testable import MoisesAudioCore

final class AnalysisPhysicalRealAudioBridgeConsumptionNormalizedCustodyCertificateTests: XCTestCase {
    private func sha(_ character: Character) -> String { String(repeating: String(character), count: 64) }
    private func root() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("w55-cert-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
    private func custody() -> AnalysisPhysicalRealAudioBridgeConsumptionCustody {
        .init(authority: "HQ_LATE_INTEGRATION", approvalReference: "HQ-W55-CERT", custodyID: "custody-w55-cert")
    }
    private func certificate() throws -> AnalysisPhysicalRealAudioParityBridgeCertificate {
        let provisional = AnalysisPhysicalRealAudioParityBridgeCertificate(
            bridgeID: "bridge-w55-cert",
            expectationRootSHA256: sha("c"),
            w47PackageRootSHA256: sha("a"),
            w47PackageBytesSHA256: sha("4"),
            manifestID: "manifest-w55-cert",
            manifestSHA256: sha("5"),
            runtimeBindingSHA256: sha("6"),
            physicalSessionID: "session-w55-cert",
            auditedProjectReportSHA256: sha("7"),
            w46BindingSHA256: sha("8"),
            w46AdjudicationStatus: .notReadyForHQJudgment,
            w46AdjudicationReportRootSHA256: sha("b"),
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

    func testCertifiedBundleBindsNormalizationAndAllW52Roots() throws {
        let root = try root()
        defer { try? FileManager.default.removeItem(at: root) }
        _ = try AnalysisPhysicalRealAudioBridgeConsumptionSecureStore.append(
            ledgerID: "ledger", certificate: certificate(), custody: custody(), rootURL: root
        )
        let observed = try AnalysisPhysicalRealAudioBridgeConsumptionNormalizedCustodyManager.observeSnapshot(
            ledgerID: "ledger", rootURL: root
        )
        let certified = try AnalysisPhysicalRealAudioBridgeConsumptionNormalizedCustodyManager.makeCertifiedCustodyBundle(
            ledgerID: "ledger",
            expectedSnapshot: observed.snapshot,
            transactionID: "tx-w55-cert",
            checkpointID: "checkpoint-w55-cert",
            checkpointSequence: 1,
            checkpointApprovalReference: "HQ-W55-CHECKPOINT",
            handoffID: "handoff-w55-cert",
            handoffApprovalReference: "HQ-W55-HANDOFF",
            rootURL: root
        )
        XCTAssertTrue(AnalysisPhysicalRealAudioBridgeConsumptionNormalizedCustodyCertificateValidator.validate(
            certified.certificate,
            bundle: certified.bundle
        ))
        XCTAssertEqual(
            certified.certificate.normalizationReceiptRootSHA256,
            certified.bundle.normalizationReceipt.declaredReceiptRootSHA256
        )
    }

    func testNormalizationReceiptSwapCannotReuseCertificate() throws {
        let root = try root()
        defer { try? FileManager.default.removeItem(at: root) }
        _ = try AnalysisPhysicalRealAudioBridgeConsumptionSecureStore.append(
            ledgerID: "ledger", certificate: certificate(), custody: custody(), rootURL: root
        )
        let observed = try AnalysisPhysicalRealAudioBridgeConsumptionNormalizedCustodyManager.observeSnapshot(
            ledgerID: "ledger", rootURL: root
        )
        let certified = try AnalysisPhysicalRealAudioBridgeConsumptionNormalizedCustodyManager.makeCertifiedCustodyBundle(
            ledgerID: "ledger",
            expectedSnapshot: observed.snapshot,
            transactionID: "tx-w55-cert",
            checkpointID: "checkpoint-w55-cert",
            checkpointSequence: 1,
            checkpointApprovalReference: "HQ-W55-CHECKPOINT",
            handoffID: "handoff-w55-cert",
            handoffApprovalReference: "HQ-W55-HANDOFF",
            rootURL: root
        )
        let original = certified.bundle.normalizationReceipt
        let changed = AnalysisPhysicalRealAudioBridgeConsumptionNormalizedAccessReceipt(
            ledgerID: original.ledgerID,
            removedLedgerTemporaryCount: original.removedLedgerTemporaryCount + 1,
            removedRecordTemporaryCount: original.removedRecordTemporaryCount,
            recoveredInterruptedAppend: original.recoveredInterruptedAppend,
            latestSequence: original.latestSequence,
            ledgerRootSHA256: original.ledgerRootSHA256,
            latestRecordRootSHA256: original.latestRecordRootSHA256,
            declaredReceiptRootSHA256: original.declaredReceiptRootSHA256
        )
        let swapped = AnalysisPhysicalRealAudioBridgeConsumptionNormalizedCustodyBundle(
            normalizationReceipt: changed,
            custodyBundle: certified.bundle.custodyBundle
        )
        XCTAssertFalse(AnalysisPhysicalRealAudioBridgeConsumptionNormalizedCustodyCertificateValidator.validate(
            certified.certificate,
            bundle: swapped
        ))
    }
}

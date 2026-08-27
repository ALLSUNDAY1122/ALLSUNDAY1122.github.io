import Foundation
import XCTest
@testable import MoisesAudioCore

@available(*, deprecated, message: "W56 migration-only compatibility coverage")
final class AnalysisPhysicalRealAudioBridgeConsumptionLegacyBypassContainmentTests: XCTestCase {
    private func sha(_ character: Character) -> String {
        String(repeating: String(character), count: 64)
    }

    private func root() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("w56-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func custody() -> AnalysisPhysicalRealAudioBridgeConsumptionCustody {
        .init(authority: "HQ_LATE_INTEGRATION", approvalReference: "HQ-W56", custodyID: "custody-w56")
    }

    private func certificate(index: Int = 1) throws -> AnalysisPhysicalRealAudioParityBridgeCertificate {
        let digits = Array("0123456789abcdef")
        let provisional = AnalysisPhysicalRealAudioParityBridgeCertificate(
            bridgeID: "bridge-w56-\(index)",
            expectationRootSHA256: String(repeating: String(digits[(index + 1) % 16]), count: 64),
            w47PackageRootSHA256: String(repeating: String(digits[(index + 2) % 16]), count: 64),
            w47PackageBytesSHA256: sha("4"),
            manifestID: "manifest-w56-\(index)",
            manifestSHA256: sha("5"),
            runtimeBindingSHA256: sha("6"),
            physicalSessionID: "session-w56-\(index)",
            auditedProjectReportSHA256: sha("7"),
            w46BindingSHA256: sha("8"),
            w46AdjudicationStatus: .notReadyForHQJudgment,
            w46AdjudicationReportRootSHA256: String(repeating: String(digits[(index + 3) % 16]), count: 64),
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

    func testProductionPolicyRejectsEveryLegacyAPIClass() {
        XCTAssertEqual(
            AnalysisPhysicalRealAudioBridgeConsumptionLegacyBypassPolicy.decision(for: .production),
            .reject
        )
        XCTAssertEqual(
            AnalysisPhysicalRealAudioBridgeConsumptionLegacyBypassPolicy.decision(for: .compatibilityDebug),
            .allowCompatibilityRoute
        )
        XCTAssertEqual(AnalysisPhysicalRealAudioBridgeConsumptionLegacyAPI.allCasesForW56.count, 13)
    }

    #if DEBUG
    func testLegacyConcurrentDebugRouteMatchesNormalizedCASAndAppend() throws {
        let root = try root()
        defer { try? FileManager.default.removeItem(at: root) }

        let legacyCAS = try AnalysisPhysicalRealAudioBridgeConsumptionConcurrentStore.observeAppendCAS(
            ledgerID: "ledger", rootURL: root
        )
        let normalizedCAS = try AnalysisPhysicalRealAudioBridgeConsumptionNormalizedConcurrentStore.observeAppendCAS(
            ledgerID: "ledger", rootURL: root
        )
        XCTAssertEqual(legacyCAS, normalizedCAS.cas)
        XCTAssertEqual(normalizedCAS.normalizationReceipt.latestSequence, 0)

        let certificate = try certificate()
        let legacyHead = try AnalysisPhysicalRealAudioBridgeConsumptionConcurrentStore.append(
            ledgerID: "ledger",
            certificate: certificate,
            custody: custody(),
            expectedCAS: legacyCAS,
            rootURL: root
        )
        let reopened = try AnalysisPhysicalRealAudioBridgeConsumptionNormalizedConcurrentStore.observeAppendCAS(
            ledgerID: "ledger", rootURL: root
        )
        XCTAssertEqual(legacyHead.latestSequence, 1)
        XCTAssertEqual(reopened.cas.expectedLatestSequence, 1)
        XCTAssertEqual(reopened.cas.expectedLedgerRootSHA256, legacyHead.declaredLedgerRootSHA256)
    }

    func testLegacyQuiescentDebugRouteMatchesNormalizedSnapshot() throws {
        let root = try root()
        defer { try? FileManager.default.removeItem(at: root) }
        _ = try AnalysisPhysicalRealAudioBridgeConsumptionSecureStore.append(
            ledgerID: "ledger", certificate: certificate(), custody: custody(), rootURL: root
        )

        let legacy = try AnalysisPhysicalRealAudioBridgeConsumptionQuiescentCustodyManager.observeSnapshot(
            ledgerID: "ledger", rootURL: root
        )
        let normalized = try AnalysisPhysicalRealAudioBridgeConsumptionNormalizedCustodyManager.observeSnapshot(
            ledgerID: "ledger", rootURL: root
        )
        XCTAssertEqual(legacy, normalized.snapshot)
        XCTAssertEqual(normalized.normalizationReceipt.latestSequence, legacy.latestSequence)
        XCTAssertEqual(normalized.normalizationReceipt.ledgerRootSHA256, legacy.ledgerRootSHA256)
    }

    func testLegacyCustodyDebugRoutePreservesW52Roots() throws {
        let root = try root()
        defer { try? FileManager.default.removeItem(at: root) }
        _ = try AnalysisPhysicalRealAudioBridgeConsumptionSecureStore.append(
            ledgerID: "ledger", certificate: certificate(), custody: custody(), rootURL: root
        )
        let observed = try AnalysisPhysicalRealAudioBridgeConsumptionNormalizedCustodyManager.observeSnapshot(
            ledgerID: "ledger", rootURL: root
        )

        let legacy = try AnalysisPhysicalRealAudioBridgeConsumptionQuiescentCustodyManager.makeCustodyBundle(
            ledgerID: "ledger",
            expectedSnapshot: observed.snapshot,
            transactionID: "tx-w56",
            checkpointID: "checkpoint-w56",
            checkpointSequence: 1,
            checkpointApprovalReference: "HQ-W56-CHECKPOINT",
            handoffID: "handoff-w56",
            handoffApprovalReference: "HQ-W56-HANDOFF",
            rootURL: root
        )
        let normalized = try AnalysisPhysicalRealAudioBridgeConsumptionNormalizedCustodyManager.makeCertifiedCustodyBundle(
            ledgerID: "ledger",
            expectedSnapshot: observed.snapshot,
            transactionID: "tx-w56",
            checkpointID: "checkpoint-w56",
            checkpointSequence: 1,
            checkpointApprovalReference: "HQ-W56-CHECKPOINT",
            handoffID: "handoff-w56",
            handoffApprovalReference: "HQ-W56-HANDOFF",
            rootURL: root
        )

        XCTAssertEqual(legacy, normalized.bundle.custodyBundle)
        XCTAssertTrue(AnalysisPhysicalRealAudioBridgeConsumptionNormalizedCustodyCertificateValidator.validate(
            normalized.certificate,
            bundle: normalized.bundle
        ))
    }

    func testDirectSecureCheckpointDebugRouteMatchesNormalizedCheckpoint() throws {
        let root = try root()
        defer { try? FileManager.default.removeItem(at: root) }
        _ = try AnalysisPhysicalRealAudioBridgeConsumptionSecureStore.append(
            ledgerID: "ledger", certificate: certificate(), custody: custody(), rootURL: root
        )

        let direct = try AnalysisPhysicalRealAudioBridgeConsumptionSecureCheckpointManager.makeStrictCheckpoint(
            ledgerID: "ledger",
            checkpointID: "checkpoint-w56",
            checkpointSequence: 1,
            approvalReference: "HQ-W56-CHECKPOINT",
            rootURL: root
        )
        let observed = try AnalysisPhysicalRealAudioBridgeConsumptionNormalizedCustodyManager.observeSnapshot(
            ledgerID: "ledger", rootURL: root
        )
        let normalized = try AnalysisPhysicalRealAudioBridgeConsumptionNormalizedCustodyManager.makeStrictCheckpoint(
            expectedSnapshot: observed.snapshot,
            checkpointID: "checkpoint-w56",
            checkpointSequence: 1,
            approvalReference: "HQ-W56-CHECKPOINT",
            rootURL: root
        )
        XCTAssertEqual(direct, normalized.checkpoint)
    }
    #endif

    func testW52HashedLimitationsRemainExactLegacyPayload() {
        XCTAssertEqual(AnalysisPhysicalRealAudioBridgeConsumptionQuiescentCustodyManager.limitations, [
            "NON_PARITY: W52 serializes ledger snapshots, checkpoints and external-anchor handoffs with W51 writers; it does not promote any Analysis PARITY row.",
            "A quiescent snapshot is a deterministic SHA-256 commitment to one recovered W50/W51 ledger state. It is not a signature, trusted timestamp, Secure Enclave proof or Apple attestation.",
            "The W52 custody receipt binds one snapshot, checkpoint and handoff generated while the authoritative W51 writer lease is held. It does not itself persist the handoff outside the mutable ledger root.",
            "Whole-ledger rollback remains externally authoritative only when HQ stores the latest checkpoint/handoff/receipt root independently from the mutable ledger directory."
        ])
    }
}

private extension AnalysisPhysicalRealAudioBridgeConsumptionLegacyAPI {
    static var allCasesForW56: [Self] {
        [
            .concurrentObserveAppendCAS,
            .concurrentAppend,
            .concurrentConsumedInventory,
            .concurrentExpectation,
            .secureCheckpointCreate,
            .secureCheckpointVerify,
            .quiescentObserveSnapshot,
            .quiescentCheckpointCreate,
            .quiescentCheckpointVerify,
            .quiescentCustodyBundle,
            .iosDurabilityMakeTicket,
            .iosDurabilityPrepare,
            .iosDurabilityReopen
        ]
    }
}

import Foundation
import XCTest
@testable import MoisesAudioCore

final class AnalysisPhysicalRealAudioBridgeConsumptionCheckpointStrictTests: XCTestCase {
    private func sha(_ c: Character) -> String { String(repeating: String(c), count: 64) }

    private func rootURL() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("w49-strict-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func certificate(_ bridgeID: String, package: Character) throws -> AnalysisPhysicalRealAudioParityBridgeCertificate {
        let provisional = AnalysisPhysicalRealAudioParityBridgeCertificate(
            bridgeID: bridgeID,
            expectationRootSHA256: sha("a"),
            w47PackageRootSHA256: sha(package),
            w47PackageBytesSHA256: sha("b"),
            manifestID: "manifest",
            manifestSHA256: sha("c"),
            runtimeBindingSHA256: sha("d"),
            physicalSessionID: "session-\(bridgeID)",
            auditedProjectReportSHA256: sha("e"),
            w46BindingSHA256: sha("f"),
            w46AdjudicationStatus: .notReadyForHQJudgment,
            w46AdjudicationReportRootSHA256: sha("1"),
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

    private func custody(_ id: String) -> AnalysisPhysicalRealAudioBridgeConsumptionCustody {
        .init(authority: "HQ_LATE_INTEGRATION", approvalReference: "HQ", custodyID: id)
    }

    private func forgedValidEnvelope(
        from checkpoint: AnalysisPhysicalRealAudioBridgeConsumptionCheckpoint
    ) throws -> AnalysisPhysicalRealAudioBridgeConsumptionCheckpoint {
        let provisional = AnalysisPhysicalRealAudioBridgeConsumptionCheckpoint(
            checkpointID: checkpoint.checkpointID,
            checkpointSequence: checkpoint.checkpointSequence,
            authority: checkpoint.authority,
            approvalReference: checkpoint.approvalReference,
            ledgerID: checkpoint.ledgerID,
            latestLedgerSequence: checkpoint.latestLedgerSequence,
            latestRecordRootSHA256: sha("8"),
            ledgerRootSHA256: sha("9"),
            consumedW47PackageRootSHA256s: checkpoint.consumedW47PackageRootSHA256s,
            predecessorCheckpointRootSHA256: checkpoint.predecessorCheckpointRootSHA256,
            limitations: checkpoint.limitations,
            declaredCheckpointRootSHA256: String(repeating: "0", count: 64)
        )
        let root = try AnalysisPhysicalRealAudioBridgeConsumptionCheckpointRoot.compute(provisional)
        return .init(
            checkpointID: provisional.checkpointID,
            checkpointSequence: provisional.checkpointSequence,
            authority: provisional.authority,
            approvalReference: provisional.approvalReference,
            ledgerID: provisional.ledgerID,
            latestLedgerSequence: provisional.latestLedgerSequence,
            latestRecordRootSHA256: provisional.latestRecordRootSHA256,
            ledgerRootSHA256: provisional.ledgerRootSHA256,
            consumedW47PackageRootSHA256s: provisional.consumedW47PackageRootSHA256s,
            predecessorCheckpointRootSHA256: provisional.predecessorCheckpointRootSHA256,
            limitations: provisional.limitations,
            declaredCheckpointRootSHA256: root
        )
    }

    func testStrictCheckpointRequiresPreviousCheckpointToBeExactLedgerPrefix() throws {
        let root = try rootURL()
        defer { try? FileManager.default.removeItem(at: root) }
        _ = try AnalysisPhysicalRealAudioBridgeConsumptionLedgerStore.append(
            ledgerID: "ledger", certificate: certificate("bridge-1", package: "2"), custody: custody("c1"), rootURL: root
        )
        let checkpoint1 = try AnalysisPhysicalRealAudioBridgeConsumptionCheckpointManager.makeStrictCheckpoint(
            ledgerID: "ledger", checkpointID: "checkpoint-1", checkpointSequence: 1,
            approvalReference: "HQ-CP1", rootURL: root
        )
        _ = try AnalysisPhysicalRealAudioBridgeConsumptionLedgerStore.append(
            ledgerID: "ledger", certificate: certificate("bridge-2", package: "3"), custody: custody("c2"), rootURL: root
        )
        let checkpoint2 = try AnalysisPhysicalRealAudioBridgeConsumptionCheckpointManager.makeStrictCheckpoint(
            ledgerID: "ledger", checkpointID: "checkpoint-2", checkpointSequence: 2,
            approvalReference: "HQ-CP2", previousCheckpoint: checkpoint1, rootURL: root
        )
        try AnalysisPhysicalRealAudioBridgeConsumptionCheckpointManager.verifyCurrentLedgerStrict(
            checkpoint: checkpoint2, previousCheckpoint: checkpoint1, rootURL: root
        )

        let forged = try forgedValidEnvelope(from: checkpoint1)
        XCTAssertTrue(AnalysisPhysicalRealAudioBridgeConsumptionCheckpointManager.validateCheckpointEnvelope(forged))
        XCTAssertThrowsError(try AnalysisPhysicalRealAudioBridgeConsumptionCheckpointManager.makeStrictCheckpoint(
            ledgerID: "ledger", checkpointID: "checkpoint-2b", checkpointSequence: 2,
            approvalReference: "HQ-CP2B", previousCheckpoint: forged, rootURL: root
        )) { error in
            XCTAssertEqual(error as? AnalysisPhysicalRealAudioBridgeConsumptionCheckpointError, .predecessorCheckpointMismatch)
        }
    }

    func testStrictHandoffMustReferenceTheCheckpointChainPredecessor() throws {
        let root = try rootURL()
        defer { try? FileManager.default.removeItem(at: root) }
        _ = try AnalysisPhysicalRealAudioBridgeConsumptionLedgerStore.append(
            ledgerID: "ledger", certificate: certificate("bridge-1", package: "2"), custody: custody("c1"), rootURL: root
        )
        let checkpoint1 = try AnalysisPhysicalRealAudioBridgeConsumptionCheckpointManager.makeStrictCheckpoint(
            ledgerID: "ledger", checkpointID: "checkpoint-1", checkpointSequence: 1,
            approvalReference: "HQ-CP1", rootURL: root
        )
        let handoff1 = try AnalysisPhysicalRealAudioBridgeConsumptionCheckpointManager.makeStrictExternalAnchorHandoff(
            handoffID: "handoff-1", approvalReference: "HQ-H1", checkpoint: checkpoint1
        )
        _ = try AnalysisPhysicalRealAudioBridgeConsumptionLedgerStore.append(
            ledgerID: "ledger", certificate: certificate("bridge-2", package: "3"), custody: custody("c2"), rootURL: root
        )
        let checkpoint2 = try AnalysisPhysicalRealAudioBridgeConsumptionCheckpointManager.makeStrictCheckpoint(
            ledgerID: "ledger", checkpointID: "checkpoint-2", checkpointSequence: 2,
            approvalReference: "HQ-CP2", previousCheckpoint: checkpoint1, rootURL: root
        )
        let handoff2 = try AnalysisPhysicalRealAudioBridgeConsumptionCheckpointManager.makeStrictExternalAnchorHandoff(
            handoffID: "handoff-2", approvalReference: "HQ-H2", checkpoint: checkpoint2, previousHandoff: handoff1
        )
        XCTAssertEqual(handoff2.predecessorHandoffRootSHA256, handoff1.declaredHandoffRootSHA256)
        XCTAssertTrue(AnalysisPhysicalRealAudioBridgeConsumptionCheckpointManager.validateHandoff(handoff2, checkpoint: checkpoint2))

        let unrelated = AnalysisPhysicalRealAudioBridgeExternalAnchorHandoff(
            handoffID: "unrelated",
            authority: handoff1.authority,
            approvalReference: handoff1.approvalReference,
            ledgerID: handoff1.ledgerID,
            checkpointID: handoff1.checkpointID,
            checkpointSequence: handoff1.checkpointSequence,
            checkpointRootSHA256: sha("7"),
            ledgerSequence: handoff1.ledgerSequence,
            ledgerRootSHA256: handoff1.ledgerRootSHA256,
            latestRecordRootSHA256: handoff1.latestRecordRootSHA256,
            consumedW47InventoryRootSHA256: handoff1.consumedW47InventoryRootSHA256,
            predecessorHandoffRootSHA256: nil,
            limitations: handoff1.limitations,
            declaredHandoffRootSHA256: String(repeating: "0", count: 64)
        )
        let unrelatedRoot = try AnalysisPhysicalRealAudioBridgeExternalAnchorHandoffRoot.compute(unrelated)
        let unrelatedValid = AnalysisPhysicalRealAudioBridgeExternalAnchorHandoff(
            handoffID: unrelated.handoffID,
            authority: unrelated.authority,
            approvalReference: unrelated.approvalReference,
            ledgerID: unrelated.ledgerID,
            checkpointID: unrelated.checkpointID,
            checkpointSequence: unrelated.checkpointSequence,
            checkpointRootSHA256: unrelated.checkpointRootSHA256,
            ledgerSequence: unrelated.ledgerSequence,
            ledgerRootSHA256: unrelated.ledgerRootSHA256,
            latestRecordRootSHA256: unrelated.latestRecordRootSHA256,
            consumedW47InventoryRootSHA256: unrelated.consumedW47InventoryRootSHA256,
            predecessorHandoffRootSHA256: unrelated.predecessorHandoffRootSHA256,
            limitations: unrelated.limitations,
            declaredHandoffRootSHA256: unrelatedRoot
        )
        XCTAssertTrue(AnalysisPhysicalRealAudioBridgeConsumptionCheckpointManager.validateHandoff(unrelatedValid))
        XCTAssertThrowsError(try AnalysisPhysicalRealAudioBridgeConsumptionCheckpointManager.makeStrictExternalAnchorHandoff(
            handoffID: "handoff-bad", approvalReference: "HQ-HBAD", checkpoint: checkpoint2, previousHandoff: unrelatedValid
        )) { error in
            XCTAssertEqual(error as? AnalysisPhysicalRealAudioBridgeConsumptionCheckpointError, .predecessorHandoffMismatch)
        }
    }
}

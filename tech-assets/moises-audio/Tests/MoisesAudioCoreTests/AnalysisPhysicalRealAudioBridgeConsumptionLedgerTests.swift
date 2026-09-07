import Foundation
import XCTest
@testable import MoisesAudioCore

final class AnalysisPhysicalRealAudioBridgeConsumptionLedgerTests: XCTestCase {
    private func sha(_ character: Character) -> String {
        String(repeating: String(character), count: 64)
    }

    private func indexedSHA(_ value: UInt64) -> String {
        String(repeating: "0", count: 48) + String(format: "%016llx", value)
    }

    private func temporaryRoot() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("w49-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func custody(_ id: String = "custody-1") -> AnalysisPhysicalRealAudioBridgeConsumptionCustody {
        .init(authority: "HQ_LATE_INTEGRATION", approvalReference: "HQ-W49-CUSTODY", custodyID: id)
    }

    private func certificate(
        bridgeID: String,
        packageRoot: String,
        reportRoot: String,
        expectationRoot: String
    ) throws -> AnalysisPhysicalRealAudioParityBridgeCertificate {
        let provisional = AnalysisPhysicalRealAudioParityBridgeCertificate(
            bridgeID: bridgeID,
            expectationRootSHA256: expectationRoot,
            w47PackageRootSHA256: packageRoot,
            w47PackageBytesSHA256: sha("4"),
            manifestID: "manifest-w49",
            manifestSHA256: sha("5"),
            runtimeBindingSHA256: sha("6"),
            physicalSessionID: "session-\(bridgeID)",
            auditedProjectReportSHA256: sha("7"),
            w46BindingSHA256: sha("8"),
            w46AdjudicationStatus: .notReadyForHQJudgment,
            w46AdjudicationReportRootSHA256: reportRoot,
            limitations: AnalysisPhysicalRealAudioParityBridge.limitations,
            declaredCertificateRootSHA256: String(repeating: "0", count: 64)
        )
        let root = try AnalysisPhysicalRealAudioParityBridgeCertificateValidator.certificateSHA256(provisional)
        return AnalysisPhysicalRealAudioParityBridgeCertificate(
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

    private func baseExpectation(packageRoot: String) -> AnalysisPhysicalRealAudioParityBridgeExpectation {
        .init(
            authority: "HQ_LATE_INTEGRATION",
            approvalReference: "HQ-W49-EXPECTATION",
            bridgeID: "future-bridge",
            expectedW47PackageRootSHA256: packageRoot,
            expectedW47PackageBytesSHA256: sha("4"),
            expectedManifestID: "manifest-w49",
            expectedManifestSHA256: sha("5"),
            expectedRuntimeBindingSHA256: sha("6"),
            expectedPhysicalSessionID: "future-session",
            expectedAuditedProjectReportSHA256: sha("7"),
            expectedW46BindingSHA256: sha("8")
        )
    }

    func testAppendIsMonotonicAndInventoryFeedsFutureW48Expectation() throws {
        let root = try temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let first = try certificate(bridgeID: "bridge-1", packageRoot: sha("a"), reportRoot: sha("b"), expectationRoot: sha("c"))
        let second = try certificate(bridgeID: "bridge-2", packageRoot: sha("d"), reportRoot: sha("e"), expectationRoot: sha("f"))

        let head1 = try AnalysisPhysicalRealAudioBridgeConsumptionLedgerStore.append(
            ledgerID: "analysis-w48-consumption", certificate: first, custody: custody("custody-1"), rootURL: root
        )
        XCTAssertEqual(head1.latestSequence, 1)
        XCTAssertNil(head1.records[0].predecessorRecordRootSHA256)

        let head2 = try AnalysisPhysicalRealAudioBridgeConsumptionLedgerStore.append(
            ledgerID: "analysis-w48-consumption", certificate: second, custody: custody("custody-2"), rootURL: root
        )
        XCTAssertEqual(head2.latestSequence, 2)
        XCTAssertEqual(head2.records[1].predecessorRecordRootSHA256, head2.records[0].recordRootSHA256)

        let inventory = try AnalysisPhysicalRealAudioBridgeConsumptionLedgerStore.consumedW47PackageRootSHA256s(
            ledgerID: "analysis-w48-consumption", rootURL: root
        )
        XCTAssertEqual(inventory, [sha("a"), sha("d")])
        let future = try AnalysisPhysicalRealAudioBridgeConsumptionLedgerStore.expectationUsingDurableConsumedInventory(
            base: baseExpectation(packageRoot: sha("9")), ledgerID: "analysis-w48-consumption", rootURL: root
        )
        XCTAssertEqual(future.previouslyConsumedW47PackageRootSHA256s, inventory)
    }

    func testDuplicateBridgeAndPackageRootsFailClosed() throws {
        let root = try temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let original = try certificate(bridgeID: "bridge-1", packageRoot: sha("a"), reportRoot: sha("b"), expectationRoot: sha("c"))
        _ = try AnalysisPhysicalRealAudioBridgeConsumptionLedgerStore.append(
            ledgerID: "ledger", certificate: original, custody: custody(), rootURL: root
        )
        let sameBridge = try certificate(bridgeID: "bridge-1", packageRoot: sha("d"), reportRoot: sha("e"), expectationRoot: sha("f"))
        XCTAssertThrowsError(try AnalysisPhysicalRealAudioBridgeConsumptionLedgerStore.append(
            ledgerID: "ledger", certificate: sameBridge, custody: custody("custody-2"), rootURL: root
        )) { error in
            XCTAssertEqual(error as? AnalysisPhysicalRealAudioBridgeConsumptionLedgerError, .duplicateBridgeID)
        }
        let samePackage = try certificate(bridgeID: "bridge-2", packageRoot: sha("a"), reportRoot: sha("d"), expectationRoot: sha("e"))
        XCTAssertThrowsError(try AnalysisPhysicalRealAudioBridgeConsumptionLedgerStore.append(
            ledgerID: "ledger", certificate: samePackage, custody: custody("custody-3"), rootURL: root
        )) { error in
            XCTAssertEqual(error as? AnalysisPhysicalRealAudioBridgeConsumptionLedgerError, .duplicateW47PackageRoot)
        }
    }

    func testRecordMutationAndUnreferencedForkRecordFailClosed() throws {
        let root = try temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let cert = try certificate(bridgeID: "bridge-1", packageRoot: sha("a"), reportRoot: sha("b"), expectationRoot: sha("c"))
        let head = try AnalysisPhysicalRealAudioBridgeConsumptionLedgerStore.append(
            ledgerID: "ledger", certificate: cert, custody: custody(), rootURL: root
        )
        let ledgerURL = root.appendingPathComponent("w49-bridge-consumption/ledger", isDirectory: true)
        let recordURL = ledgerURL.appendingPathComponent(head.records[0].relativePath)
        let record = try AnalysisPhysicalRealAudioBridgeConsumptionLedgerCodec.decodeRecord(Data(contentsOf: recordURL))
        let tampered = AnalysisPhysicalRealAudioBridgeConsumptionRecord(
            ledgerID: record.ledgerID,
            sequence: record.sequence,
            bridgeID: record.bridgeID,
            bridgeCertificateRootSHA256: record.bridgeCertificateRootSHA256,
            w47PackageRootSHA256: sha("d"),
            w46AdjudicationReportRootSHA256: record.w46AdjudicationReportRootSHA256,
            expectationRootSHA256: record.expectationRootSHA256,
            custody: record.custody,
            predecessorRecordRootSHA256: record.predecessorRecordRootSHA256,
            declaredRecordRootSHA256: record.declaredRecordRootSHA256
        )
        try AnalysisPhysicalRealAudioBridgeConsumptionLedgerCodec.encodeRecord(tampered).write(to: recordURL, options: .atomic)
        XCTAssertThrowsError(try AnalysisPhysicalRealAudioBridgeConsumptionLedgerStore.loadValidatedHead(
            ledgerID: "ledger", rootURL: root
        )) { error in
            XCTAssertEqual(error as? AnalysisPhysicalRealAudioBridgeConsumptionLedgerError, .corruptedLedger)
        }

        try AnalysisPhysicalRealAudioBridgeConsumptionLedgerCodec.encodeRecord(record).write(to: recordURL, options: .atomic)
        let forkURL = ledgerURL.appendingPathComponent("records/999999999999-\(sha("f")).json")
        try Data("{}".utf8).write(to: forkURL, options: .atomic)
        XCTAssertThrowsError(try AnalysisPhysicalRealAudioBridgeConsumptionLedgerStore.loadValidatedHead(
            ledgerID: "ledger", rootURL: root
        )) { error in
            XCTAssertEqual(error as? AnalysisPhysicalRealAudioBridgeConsumptionLedgerError, .forkedHistory)
        }
    }

    func testStaleCheckpointReplayFailsAfterLedgerAdvances() throws {
        let root = try temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let first = try certificate(bridgeID: "bridge-1", packageRoot: sha("a"), reportRoot: sha("b"), expectationRoot: sha("c"))
        _ = try AnalysisPhysicalRealAudioBridgeConsumptionLedgerStore.append(
            ledgerID: "ledger", certificate: first, custody: custody(), rootURL: root
        )
        let checkpoint1 = try AnalysisPhysicalRealAudioBridgeConsumptionCheckpointManager.makeCheckpoint(
            ledgerID: "ledger", checkpointID: "checkpoint-1", checkpointSequence: 1,
            approvalReference: "HQ-W49-CHECKPOINT-1", rootURL: root
        )
        try AnalysisPhysicalRealAudioBridgeConsumptionCheckpointManager.verifyCurrentLedger(checkpoint: checkpoint1, rootURL: root)

        let second = try certificate(bridgeID: "bridge-2", packageRoot: sha("d"), reportRoot: sha("e"), expectationRoot: sha("f"))
        _ = try AnalysisPhysicalRealAudioBridgeConsumptionLedgerStore.append(
            ledgerID: "ledger", certificate: second, custody: custody("custody-2"), rootURL: root
        )
        XCTAssertThrowsError(try AnalysisPhysicalRealAudioBridgeConsumptionCheckpointManager.verifyCurrentLedger(
            checkpoint: checkpoint1, rootURL: root
        )) { error in
            XCTAssertEqual(error as? AnalysisPhysicalRealAudioBridgeConsumptionCheckpointError, .staleCheckpointReplay)
        }

        let checkpoint2 = try AnalysisPhysicalRealAudioBridgeConsumptionCheckpointManager.makeCheckpoint(
            ledgerID: "ledger", checkpointID: "checkpoint-2", checkpointSequence: 2,
            approvalReference: "HQ-W49-CHECKPOINT-2", previousCheckpoint: checkpoint1, rootURL: root
        )
        XCTAssertEqual(checkpoint2.predecessorCheckpointRootSHA256, checkpoint1.declaredCheckpointRootSHA256)
        try AnalysisPhysicalRealAudioBridgeConsumptionCheckpointManager.verifyCurrentLedger(
            checkpoint: checkpoint2, previousCheckpoint: checkpoint1, rootURL: root
        )
    }

    func testExternalHandoffChainBindsExactCheckpoint() throws {
        let root = try temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let first = try certificate(bridgeID: "bridge-1", packageRoot: sha("a"), reportRoot: sha("b"), expectationRoot: sha("c"))
        _ = try AnalysisPhysicalRealAudioBridgeConsumptionLedgerStore.append(
            ledgerID: "ledger", certificate: first, custody: custody(), rootURL: root
        )
        let checkpoint1 = try AnalysisPhysicalRealAudioBridgeConsumptionCheckpointManager.makeCheckpoint(
            ledgerID: "ledger", checkpointID: "checkpoint-1", checkpointSequence: 1,
            approvalReference: "HQ-W49-CHECKPOINT-1", rootURL: root
        )
        let handoff1 = try AnalysisPhysicalRealAudioBridgeConsumptionCheckpointManager.makeExternalAnchorHandoff(
            handoffID: "handoff-1", approvalReference: "HQ-W49-HANDOFF-1", checkpoint: checkpoint1
        )
        XCTAssertTrue(AnalysisPhysicalRealAudioBridgeConsumptionCheckpointManager.validateHandoff(handoff1, checkpoint: checkpoint1))

        let second = try certificate(bridgeID: "bridge-2", packageRoot: sha("d"), reportRoot: sha("e"), expectationRoot: sha("f"))
        _ = try AnalysisPhysicalRealAudioBridgeConsumptionLedgerStore.append(
            ledgerID: "ledger", certificate: second, custody: custody("custody-2"), rootURL: root
        )
        let checkpoint2 = try AnalysisPhysicalRealAudioBridgeConsumptionCheckpointManager.makeCheckpoint(
            ledgerID: "ledger", checkpointID: "checkpoint-2", checkpointSequence: 2,
            approvalReference: "HQ-W49-CHECKPOINT-2", previousCheckpoint: checkpoint1, rootURL: root
        )
        let handoff2 = try AnalysisPhysicalRealAudioBridgeConsumptionCheckpointManager.makeExternalAnchorHandoff(
            handoffID: "handoff-2", approvalReference: "HQ-W49-HANDOFF-2",
            checkpoint: checkpoint2, previousHandoff: handoff1
        )
        XCTAssertEqual(handoff2.predecessorHandoffRootSHA256, handoff1.declaredHandoffRootSHA256)
        XCTAssertTrue(AnalysisPhysicalRealAudioBridgeConsumptionCheckpointManager.validateHandoff(handoff2, checkpoint: checkpoint2))
        XCTAssertFalse(AnalysisPhysicalRealAudioBridgeConsumptionCheckpointManager.validateHandoff(handoff2, checkpoint: checkpoint1))
    }

    func testCheckpointMutationCannotReuseDeclaredRoot() throws {
        let root = try temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let cert = try certificate(bridgeID: "bridge-1", packageRoot: sha("a"), reportRoot: sha("b"), expectationRoot: sha("c"))
        _ = try AnalysisPhysicalRealAudioBridgeConsumptionLedgerStore.append(
            ledgerID: "ledger", certificate: cert, custody: custody(), rootURL: root
        )
        let checkpoint = try AnalysisPhysicalRealAudioBridgeConsumptionCheckpointManager.makeCheckpoint(
            ledgerID: "ledger", checkpointID: "checkpoint-1", checkpointSequence: 1,
            approvalReference: "HQ-W49-CHECKPOINT", rootURL: root
        )
        let mutated = AnalysisPhysicalRealAudioBridgeConsumptionCheckpoint(
            checkpointID: checkpoint.checkpointID,
            checkpointSequence: checkpoint.checkpointSequence,
            authority: checkpoint.authority,
            approvalReference: checkpoint.approvalReference,
            ledgerID: checkpoint.ledgerID,
            latestLedgerSequence: checkpoint.latestLedgerSequence,
            latestRecordRootSHA256: sha("f"),
            ledgerRootSHA256: checkpoint.ledgerRootSHA256,
            consumedW47PackageRootSHA256s: checkpoint.consumedW47PackageRootSHA256s,
            predecessorCheckpointRootSHA256: checkpoint.predecessorCheckpointRootSHA256,
            limitations: checkpoint.limitations,
            declaredCheckpointRootSHA256: checkpoint.declaredCheckpointRootSHA256
        )
        XCTAssertFalse(AnalysisPhysicalRealAudioBridgeConsumptionCheckpointManager.validateCheckpointEnvelope(mutated))
    }

    func testTwentyFourAppendsMaintainUniqueMonotonicChain() throws {
        let root = try temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        var previousRoot: String?
        for index in 0..<24 {
            let cert = try certificate(
                bridgeID: "bridge-\(index + 1)",
                packageRoot: indexedSHA(UInt64(index + 1)),
                reportRoot: indexedSHA(UInt64(index + 101)),
                expectationRoot: indexedSHA(UInt64(index + 201))
            )
            let head = try AnalysisPhysicalRealAudioBridgeConsumptionLedgerStore.append(
                ledgerID: "series-ledger",
                certificate: cert,
                custody: custody("custody-\(index + 1)"),
                rootURL: root
            )
            XCTAssertEqual(head.latestSequence, UInt64(index + 1))
            XCTAssertEqual(head.records.last?.predecessorRecordRootSHA256, previousRoot)
            previousRoot = head.latestRecordRootSHA256
        }
        let head = try XCTUnwrap(AnalysisPhysicalRealAudioBridgeConsumptionLedgerStore.loadValidatedHead(
            ledgerID: "series-ledger", rootURL: root
        ))
        XCTAssertEqual(Set(head.records.map(\.bridgeID)).count, 24)
        XCTAssertEqual(Set(head.records.map(\.w47PackageRootSHA256)).count, 24)
        XCTAssertEqual(Set(head.records.map(\.recordRootSHA256)).count, 24)
    }
}

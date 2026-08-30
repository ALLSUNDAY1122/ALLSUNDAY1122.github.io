import Foundation
import XCTest
@testable import MoisesAudioCore

final class AnalysisPhysicalRealAudioBridgeConsumptionSecureStoreTests: XCTestCase {
    private func sha(_ character: Character) -> String {
        String(repeating: String(character), count: 64)
    }

    private func root() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("w50-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func custody(_ id: String = "custody-1") -> AnalysisPhysicalRealAudioBridgeConsumptionCustody {
        .init(
            authority: "HQ_LATE_INTEGRATION",
            approvalReference: "HQ-W50-CUSTODY",
            custodyID: id
        )
    }

    private func certificate(
        bridgeID: String = "bridge-1",
        package: Character = "a",
        report: Character = "b",
        expectation: Character = "c"
    ) throws -> AnalysisPhysicalRealAudioParityBridgeCertificate {
        let provisional = AnalysisPhysicalRealAudioParityBridgeCertificate(
            bridgeID: bridgeID,
            expectationRootSHA256: sha(expectation),
            w47PackageRootSHA256: sha(package),
            w47PackageBytesSHA256: sha("4"),
            manifestID: "manifest-w50",
            manifestSHA256: sha("5"),
            runtimeBindingSHA256: sha("6"),
            physicalSessionID: "session-\(bridgeID)",
            auditedProjectReportSHA256: sha("7"),
            w46BindingSHA256: sha("8"),
            w46AdjudicationStatus: .notReadyForHQJudgment,
            w46AdjudicationReportRootSHA256: sha(report),
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

    private func ledgerURL(_ root: URL, ledgerID: String = "ledger") -> URL {
        root.appendingPathComponent("w49-bridge-consumption", isDirectory: true)
            .appendingPathComponent(ledgerID, isDirectory: true)
    }

    func testSecureAppendAndInventoryRemainW49Compatible() throws {
        let root = try root()
        defer { try? FileManager.default.removeItem(at: root) }
        let first = try certificate()
        let head = try AnalysisPhysicalRealAudioBridgeConsumptionSecureStore.append(
            ledgerID: "ledger", certificate: first, custody: custody(), rootURL: root
        )
        XCTAssertEqual(head.latestSequence, 1)
        XCTAssertEqual(
            try AnalysisPhysicalRealAudioBridgeConsumptionSecureStore.consumedW47PackageRootSHA256s(
                ledgerID: "ledger", rootURL: root
            ),
            [sha("a")]
        )
        XCTAssertEqual(
            try AnalysisPhysicalRealAudioBridgeConsumptionLedgerStore.loadValidatedHead(
                ledgerID: "ledger", rootURL: root
            ),
            head
        )
    }

    func testSymlinkedHeadIsRejected() throws {
        let root = try root()
        defer { try? FileManager.default.removeItem(at: root) }
        _ = try AnalysisPhysicalRealAudioBridgeConsumptionSecureStore.append(
            ledgerID: "ledger", certificate: certificate(), custody: custody(), rootURL: root
        )
        let ledger = ledgerURL(root)
        let head = ledger.appendingPathComponent(AnalysisPhysicalRealAudioBridgeConsumptionLedgerStore.headFileName)
        let outside = root.appendingPathComponent("outside-head.json")
        try FileManager.default.moveItem(at: head, to: outside)
        try FileManager.default.createSymbolicLink(at: head, withDestinationURL: outside)

        XCTAssertThrowsError(try AnalysisPhysicalRealAudioBridgeConsumptionSecureStore.loadValidatedHead(
            ledgerID: "ledger", rootURL: root
        )) { error in
            XCTAssertEqual(error as? AnalysisPhysicalRealAudioBridgeConsumptionSecureStoreError, .symbolicLinkRejected)
        }
    }

    func testSymlinkedRecordIsRejectedEvenWhenTargetBytesAreValid() throws {
        let root = try root()
        defer { try? FileManager.default.removeItem(at: root) }
        let head = try AnalysisPhysicalRealAudioBridgeConsumptionSecureStore.append(
            ledgerID: "ledger", certificate: certificate(), custody: custody(), rootURL: root
        )
        let ledger = ledgerURL(root)
        let record = ledger.appendingPathComponent(head.records[0].relativePath)
        let outside = root.appendingPathComponent("outside-record.json")
        try FileManager.default.moveItem(at: record, to: outside)
        try FileManager.default.createSymbolicLink(at: record, withDestinationURL: outside)

        XCTAssertThrowsError(try AnalysisPhysicalRealAudioBridgeConsumptionSecureStore.loadValidatedHead(
            ledgerID: "ledger", rootURL: root
        )) { error in
            XCTAssertEqual(error as? AnalysisPhysicalRealAudioBridgeConsumptionSecureStoreError, .symbolicLinkRejected)
        }
    }

    func testSymlinkedRecordsDirectoryAndUnexpectedTopologyAreRejected() throws {
        let rootA = try root()
        defer { try? FileManager.default.removeItem(at: rootA) }
        _ = try AnalysisPhysicalRealAudioBridgeConsumptionSecureStore.append(
            ledgerID: "ledger", certificate: certificate(), custody: custody(), rootURL: rootA
        )
        let ledgerA = ledgerURL(rootA)
        let records = ledgerA.appendingPathComponent("records", isDirectory: true)
        let moved = rootA.appendingPathComponent("moved-records", isDirectory: true)
        try FileManager.default.moveItem(at: records, to: moved)
        try FileManager.default.createSymbolicLink(at: records, withDestinationURL: moved)
        XCTAssertThrowsError(try AnalysisPhysicalRealAudioBridgeConsumptionSecureStore.loadValidatedHead(
            ledgerID: "ledger", rootURL: rootA
        )) { error in
            XCTAssertEqual(error as? AnalysisPhysicalRealAudioBridgeConsumptionSecureStoreError, .symbolicLinkRejected)
        }

        let rootB = try root()
        defer { try? FileManager.default.removeItem(at: rootB) }
        _ = try AnalysisPhysicalRealAudioBridgeConsumptionSecureStore.append(
            ledgerID: "ledger", certificate: certificate(), custody: custody(), rootURL: rootB
        )
        try Data("unexpected".utf8).write(to: ledgerURL(rootB).appendingPathComponent("unexpected.bin"))
        XCTAssertThrowsError(try AnalysisPhysicalRealAudioBridgeConsumptionSecureStore.loadValidatedHead(
            ledgerID: "ledger", rootURL: rootB
        )) { error in
            XCTAssertEqual(error as? AnalysisPhysicalRealAudioBridgeConsumptionSecureStoreError, .unsafeFilesystemTopology)
        }
    }

    func testNonRegularAndOversizedHeadAreRejectedBeforeDecode() throws {
        let rootA = try root()
        defer { try? FileManager.default.removeItem(at: rootA) }
        _ = try AnalysisPhysicalRealAudioBridgeConsumptionSecureStore.append(
            ledgerID: "ledger", certificate: certificate(), custody: custody(), rootURL: rootA
        )
        let headA = ledgerURL(rootA).appendingPathComponent(AnalysisPhysicalRealAudioBridgeConsumptionLedgerStore.headFileName)
        try FileManager.default.removeItem(at: headA)
        try FileManager.default.createDirectory(at: headA, withIntermediateDirectories: false)
        XCTAssertThrowsError(try AnalysisPhysicalRealAudioBridgeConsumptionSecureStore.loadValidatedHead(
            ledgerID: "ledger", rootURL: rootA
        )) { error in
            XCTAssertEqual(error as? AnalysisPhysicalRealAudioBridgeConsumptionSecureStoreError, .nonRegularFileRejected)
        }

        let rootB = try root()
        defer { try? FileManager.default.removeItem(at: rootB) }
        _ = try AnalysisPhysicalRealAudioBridgeConsumptionSecureStore.append(
            ledgerID: "ledger", certificate: certificate(), custody: custody(), rootURL: rootB
        )
        let headB = ledgerURL(rootB).appendingPathComponent(AnalysisPhysicalRealAudioBridgeConsumptionLedgerStore.headFileName)
        try Data(repeating: 0x20, count: AnalysisPhysicalRealAudioBridgeConsumptionSecureFilesystem.maxHeadBytes + 1)
            .write(to: headB, options: .atomic)
        XCTAssertThrowsError(try AnalysisPhysicalRealAudioBridgeConsumptionSecureStore.loadValidatedHead(
            ledgerID: "ledger", rootURL: rootB
        )) { error in
            XCTAssertEqual(error as? AnalysisPhysicalRealAudioBridgeConsumptionSecureStoreError, .oversizedFile)
        }
    }

    func testPendingOnlyFaultRollsBackUncommittedCandidate() throws {
        let root = try root()
        defer { try? FileManager.default.removeItem(at: root) }
        XCTAssertThrowsError(try AnalysisPhysicalRealAudioBridgeConsumptionSecureStore.appendForTesting(
            ledgerID: "ledger", certificate: certificate(), custody: custody(), rootURL: root,
            injectedFault: .afterPendingMarker
        ))
        XCTAssertTrue(try AnalysisPhysicalRealAudioBridgeConsumptionSecureStore.recoverIfNeeded(
            ledgerID: "ledger", rootURL: root
        ))
        XCTAssertNil(try AnalysisPhysicalRealAudioBridgeConsumptionSecureStore.loadValidatedHead(
            ledgerID: "ledger", rootURL: root
        ))
        XCTAssertEqual(try AnalysisPhysicalRealAudioBridgeConsumptionSecureStore.append(
            ledgerID: "ledger", certificate: certificate(), custody: custody(), rootURL: root
        ).latestSequence, 1)
    }

    func testRecordWrittenFaultRollsForwardExactlyOnce() throws {
        let root = try root()
        defer { try? FileManager.default.removeItem(at: root) }
        XCTAssertThrowsError(try AnalysisPhysicalRealAudioBridgeConsumptionSecureStore.appendForTesting(
            ledgerID: "ledger", certificate: certificate(), custody: custody(), rootURL: root,
            injectedFault: .afterRecordWrite
        ))
        XCTAssertTrue(try AnalysisPhysicalRealAudioBridgeConsumptionSecureStore.recoverIfNeeded(
            ledgerID: "ledger", rootURL: root
        ))
        let head = try XCTUnwrap(AnalysisPhysicalRealAudioBridgeConsumptionSecureStore.loadValidatedHead(
            ledgerID: "ledger", rootURL: root
        ))
        XCTAssertEqual(head.latestSequence, 1)
        XCTAssertThrowsError(try AnalysisPhysicalRealAudioBridgeConsumptionSecureStore.append(
            ledgerID: "ledger", certificate: certificate(), custody: custody(), rootURL: root
        )) { error in
            XCTAssertEqual(error as? AnalysisPhysicalRealAudioBridgeConsumptionSecureStoreError, .duplicateBridgeID)
        }
    }

    func testHeadWrittenFaultOnlyRemovesPendingMarkerOnRecovery() throws {
        let root = try root()
        defer { try? FileManager.default.removeItem(at: root) }
        XCTAssertThrowsError(try AnalysisPhysicalRealAudioBridgeConsumptionSecureStore.appendForTesting(
            ledgerID: "ledger", certificate: certificate(), custody: custody(), rootURL: root,
            injectedFault: .afterHeadWriteBeforePendingRemoval
        ))
        let before = try XCTUnwrap(AnalysisPhysicalRealAudioBridgeConsumptionSecureStore.loadValidatedHead(
            ledgerID: "ledger", rootURL: root
        ))
        XCTAssertEqual(before.latestSequence, 1)
        XCTAssertTrue(try AnalysisPhysicalRealAudioBridgeConsumptionSecureStore.recoverIfNeeded(
            ledgerID: "ledger", rootURL: root
        ))
        XCTAssertEqual(try AnalysisPhysicalRealAudioBridgeConsumptionSecureStore.loadValidatedHead(
            ledgerID: "ledger", rootURL: root
        ), before)
    }

    func testCorruptPendingAndRecordCollisionFailClosed() throws {
        let corruptRoot = try root()
        defer { try? FileManager.default.removeItem(at: corruptRoot) }
        XCTAssertThrowsError(try AnalysisPhysicalRealAudioBridgeConsumptionSecureStore.appendForTesting(
            ledgerID: "ledger", certificate: certificate(), custody: custody(), rootURL: corruptRoot,
            injectedFault: .corruptPendingMarker
        ))
        XCTAssertThrowsError(try AnalysisPhysicalRealAudioBridgeConsumptionSecureStore.recoverIfNeeded(
            ledgerID: "ledger", rootURL: corruptRoot
        )) { error in
            XCTAssertEqual(error as? AnalysisPhysicalRealAudioBridgeConsumptionSecureStoreError, .ambiguousRecoveryState)
        }

        let collisionRoot = try root()
        defer { try? FileManager.default.removeItem(at: collisionRoot) }
        XCTAssertThrowsError(try AnalysisPhysicalRealAudioBridgeConsumptionSecureStore.appendForTesting(
            ledgerID: "ledger", certificate: certificate(), custody: custody(), rootURL: collisionRoot,
            injectedFault: .recordCollision
        ))
        XCTAssertThrowsError(try AnalysisPhysicalRealAudioBridgeConsumptionSecureStore.recoverIfNeeded(
            ledgerID: "ledger", rootURL: collisionRoot
        ))
    }

    func testInjectedReadBackFailureLeavesReopenableCommittedState() throws {
        let root = try root()
        defer { try? FileManager.default.removeItem(at: root) }
        XCTAssertThrowsError(try AnalysisPhysicalRealAudioBridgeConsumptionSecureStore.appendForTesting(
            ledgerID: "ledger", certificate: certificate(), custody: custody(), rootURL: root,
            injectedFault: .readBackFailure
        )) { error in
            XCTAssertEqual(
                error as? AnalysisPhysicalRealAudioBridgeConsumptionSecureStoreError,
                .injectedFault(.readBackFailure)
            )
        }
        XCTAssertFalse(try AnalysisPhysicalRealAudioBridgeConsumptionSecureStore.recoverIfNeeded(
            ledgerID: "ledger", rootURL: root
        ))
        XCTAssertEqual(try AnalysisPhysicalRealAudioBridgeConsumptionSecureStore.loadValidatedHead(
            ledgerID: "ledger", rootURL: root
        )?.latestSequence, 1)
    }

    func testSecureCheckpointRefusesSymlinkedLedgerEvidence() throws {
        let root = try root()
        defer { try? FileManager.default.removeItem(at: root) }
        _ = try AnalysisPhysicalRealAudioBridgeConsumptionSecureStore.append(
            ledgerID: "ledger", certificate: certificate(), custody: custody(), rootURL: root
        )
        let checkpoint = try AnalysisPhysicalRealAudioBridgeConsumptionSecureCheckpointManager.makeStrictCheckpoint(
            ledgerID: "ledger", checkpointID: "checkpoint-1", checkpointSequence: 1,
            approvalReference: "HQ-W50-CHECKPOINT", rootURL: root
        )
        try AnalysisPhysicalRealAudioBridgeConsumptionSecureCheckpointManager.verifyCurrentLedgerStrict(
            checkpoint: checkpoint, rootURL: root
        )

        let ledger = ledgerURL(root)
        let head = ledger.appendingPathComponent(AnalysisPhysicalRealAudioBridgeConsumptionLedgerStore.headFileName)
        let outside = root.appendingPathComponent("checkpoint-head.json")
        try FileManager.default.moveItem(at: head, to: outside)
        try FileManager.default.createSymbolicLink(at: head, withDestinationURL: outside)
        XCTAssertThrowsError(try AnalysisPhysicalRealAudioBridgeConsumptionSecureCheckpointManager.verifyCurrentLedgerStrict(
            checkpoint: checkpoint, rootURL: root
        )) { error in
            XCTAssertEqual(error as? AnalysisPhysicalRealAudioBridgeConsumptionSecureStoreError, .symbolicLinkRejected)
        }
    }
}

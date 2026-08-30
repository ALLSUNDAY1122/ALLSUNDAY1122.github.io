import Foundation
import XCTest
@testable import MoisesAudioCore

private final class W52RaceResultBox: @unchecked Sendable {
    private let lock = NSLock()
    private var _writerSucceeded = false
    private var _writerError: Error?
    private var _bundle: AnalysisPhysicalRealAudioBridgeConsumptionQuiescentCustodyBundle?
    private var _bundleError: Error?

    func setWriterSuccess() { lock.lock(); _writerSucceeded = true; lock.unlock() }
    func setWriterError(_ error: Error) { lock.lock(); _writerError = error; lock.unlock() }
    func setBundle(_ value: AnalysisPhysicalRealAudioBridgeConsumptionQuiescentCustodyBundle) { lock.lock(); _bundle = value; lock.unlock() }
    func setBundleError(_ error: Error) { lock.lock(); _bundleError = error; lock.unlock() }

    var writerSucceeded: Bool { lock.lock(); defer { lock.unlock() }; return _writerSucceeded }
    var writerError: Error? { lock.lock(); defer { lock.unlock() }; return _writerError }
    var bundle: AnalysisPhysicalRealAudioBridgeConsumptionQuiescentCustodyBundle? { lock.lock(); defer { lock.unlock() }; return _bundle }
    var bundleError: Error? { lock.lock(); defer { lock.unlock() }; return _bundleError }
}

final class AnalysisPhysicalRealAudioBridgeConsumptionQuiescentCustodyTests: XCTestCase {
    private func sha(_ character: Character) -> String {
        String(repeating: String(character), count: 64)
    }

    private func root() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("w52-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func custody(_ id: String) -> AnalysisPhysicalRealAudioBridgeConsumptionCustody {
        .init(authority: "HQ_LATE_INTEGRATION", approvalReference: "HQ-W52-CUSTODY", custodyID: id)
    }

    private func certificate(
        bridgeID: String,
        package: Character,
        report: Character,
        expectation: Character
    ) throws -> AnalysisPhysicalRealAudioParityBridgeCertificate {
        let provisional = AnalysisPhysicalRealAudioParityBridgeCertificate(
            bridgeID: bridgeID,
            expectationRootSHA256: sha(expectation),
            w47PackageRootSHA256: sha(package),
            w47PackageBytesSHA256: sha("4"),
            manifestID: "manifest-\(bridgeID)",
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

    private func seed(_ root: URL) throws -> AnalysisPhysicalRealAudioBridgeConsumptionLedgerHead {
        let cas = try AnalysisPhysicalRealAudioBridgeConsumptionConcurrentStore.observeAppendCAS(ledgerID: "ledger", rootURL: root)
        return try AnalysisPhysicalRealAudioBridgeConsumptionConcurrentStore.append(
            ledgerID: "ledger",
            certificate: certificate(bridgeID: "bridge-1", package: "a", report: "b", expectation: "c"),
            custody: custody("custody-1"),
            expectedCAS: cas,
            rootURL: root
        )
    }

    func testSnapshotIsDeterministicAndPinsOneSecureHead() throws {
        let root = try root(); defer { try? FileManager.default.removeItem(at: root) }
        let head = try seed(root)
        let first = try AnalysisPhysicalRealAudioBridgeConsumptionQuiescentCustodyManager.observeSnapshot(ledgerID: "ledger", rootURL: root)
        let second = try AnalysisPhysicalRealAudioBridgeConsumptionQuiescentCustodyManager.observeSnapshot(ledgerID: "ledger", rootURL: root)
        XCTAssertEqual(first, second)
        XCTAssertEqual(first.latestSequence, head.latestSequence)
        XCTAssertEqual(first.ledgerRootSHA256, head.declaredLedgerRootSHA256)
        XCTAssertEqual(first.latestRecordRootSHA256, head.latestRecordRootSHA256)
        XCTAssertEqual(first.consumedW47PackageRootSHA256s, [sha("a")])
        XCTAssertTrue(AnalysisPhysicalRealAudioBridgeConsumptionQuiescentCustodyManager.validateSnapshot(first))
        let cas = try AnalysisPhysicalRealAudioBridgeConsumptionQuiescentCustodyManager.appendCAS(for: first)
        XCTAssertEqual(cas.expectedLatestSequence, first.latestSequence)
        XCTAssertEqual(cas.expectedLedgerRootSHA256, first.ledgerRootSHA256)
        XCTAssertEqual(cas.expectedLatestRecordRootSHA256, first.latestRecordRootSHA256)
    }

    func testStaleSnapshotCannotCreateCheckpointAfterAppend() throws {
        let root = try root(); defer { try? FileManager.default.removeItem(at: root) }
        _ = try seed(root)
        let stale = try AnalysisPhysicalRealAudioBridgeConsumptionQuiescentCustodyManager.observeSnapshot(ledgerID: "ledger", rootURL: root)
        let cas = try AnalysisPhysicalRealAudioBridgeConsumptionConcurrentStore.observeAppendCAS(ledgerID: "ledger", rootURL: root)
        _ = try AnalysisPhysicalRealAudioBridgeConsumptionConcurrentStore.append(
            ledgerID: "ledger",
            certificate: certificate(bridgeID: "bridge-2", package: "d", report: "e", expectation: "f"),
            custody: custody("custody-2"),
            expectedCAS: cas,
            rootURL: root
        )
        XCTAssertThrowsError(try AnalysisPhysicalRealAudioBridgeConsumptionQuiescentCustodyManager.makeStrictCheckpoint(
            expectedSnapshot: stale,
            checkpointID: "cp-1",
            checkpointSequence: 1,
            approvalReference: "HQ-W52-CP-1",
            rootURL: root
        )) { error in
            XCTAssertEqual(error as? AnalysisPhysicalRealAudioBridgeConsumptionQuiescentCustodyError, .staleSnapshotCAS)
        }
    }

    func testCustodyBundleBindsSnapshotCheckpointHandoffAndReceipt() throws {
        let root = try root(); defer { try? FileManager.default.removeItem(at: root) }
        _ = try seed(root)
        let snapshot = try AnalysisPhysicalRealAudioBridgeConsumptionQuiescentCustodyManager.observeSnapshot(ledgerID: "ledger", rootURL: root)
        let bundle = try AnalysisPhysicalRealAudioBridgeConsumptionQuiescentCustodyManager.makeCustodyBundle(
            ledgerID: "ledger",
            expectedSnapshot: snapshot,
            transactionID: "tx-1",
            checkpointID: "cp-1",
            checkpointSequence: 1,
            checkpointApprovalReference: "HQ-W52-CP-1",
            handoffID: "handoff-1",
            handoffApprovalReference: "HQ-W52-HO-1",
            rootURL: root
        )
        XCTAssertEqual(bundle.snapshot, snapshot)
        XCTAssertEqual(bundle.checkpoint.latestLedgerSequence, snapshot.latestSequence)
        XCTAssertEqual(bundle.checkpoint.ledgerRootSHA256, snapshot.ledgerRootSHA256)
        XCTAssertEqual(bundle.handoff.checkpointRootSHA256, bundle.checkpoint.declaredCheckpointRootSHA256)
        XCTAssertEqual(bundle.handoff.ledgerRootSHA256, snapshot.ledgerRootSHA256)
        XCTAssertEqual(bundle.receipt.snapshotRootSHA256, snapshot.declaredSnapshotRootSHA256)
        XCTAssertEqual(bundle.receipt.checkpointRootSHA256, bundle.checkpoint.declaredCheckpointRootSHA256)
        XCTAssertEqual(bundle.receipt.handoffRootSHA256, bundle.handoff.declaredHandoffRootSHA256)
        XCTAssertTrue(AnalysisPhysicalRealAudioBridgeConsumptionQuiescentCustodyManager.validateReceipt(
            bundle.receipt, snapshot: bundle.snapshot, checkpoint: bundle.checkpoint, handoff: bundle.handoff
        ))
    }

    func testRecordWrittenInterruptionRecoversBeforeSnapshotCASAndPendingOnlyRollsBack() throws {
        let rootA = try root(); defer { try? FileManager.default.removeItem(at: rootA) }
        _ = try seed(rootA)
        let preA = try AnalysisPhysicalRealAudioBridgeConsumptionQuiescentCustodyManager.observeSnapshot(ledgerID: "ledger", rootURL: rootA)
        let casA = try AnalysisPhysicalRealAudioBridgeConsumptionConcurrentStore.observeAppendCAS(ledgerID: "ledger", rootURL: rootA)
        XCTAssertThrowsError(try AnalysisPhysicalRealAudioBridgeConsumptionConcurrentStore.appendForTesting(
            ledgerID: "ledger",
            certificate: certificate(bridgeID: "bridge-2", package: "d", report: "e", expectation: "f"),
            custody: custody("custody-2"),
            expectedCAS: casA,
            rootURL: rootA,
            injectedFault: .afterRecordWrite
        ))
        XCTAssertThrowsError(try AnalysisPhysicalRealAudioBridgeConsumptionQuiescentCustodyManager.makeStrictCheckpoint(
            expectedSnapshot: preA,
            checkpointID: "cp-1",
            checkpointSequence: 1,
            approvalReference: "HQ-W52-CP-1",
            rootURL: rootA
        )) { error in
            XCTAssertEqual(error as? AnalysisPhysicalRealAudioBridgeConsumptionQuiescentCustodyError, .staleSnapshotCAS)
        }
        let postA = try AnalysisPhysicalRealAudioBridgeConsumptionQuiescentCustodyManager.observeSnapshot(ledgerID: "ledger", rootURL: rootA)
        XCTAssertEqual(postA.latestSequence, preA.latestSequence + 1)

        let rootB = try root(); defer { try? FileManager.default.removeItem(at: rootB) }
        _ = try seed(rootB)
        let preB = try AnalysisPhysicalRealAudioBridgeConsumptionQuiescentCustodyManager.observeSnapshot(ledgerID: "ledger", rootURL: rootB)
        let casB = try AnalysisPhysicalRealAudioBridgeConsumptionConcurrentStore.observeAppendCAS(ledgerID: "ledger", rootURL: rootB)
        XCTAssertThrowsError(try AnalysisPhysicalRealAudioBridgeConsumptionConcurrentStore.appendForTesting(
            ledgerID: "ledger",
            certificate: certificate(bridgeID: "bridge-2", package: "d", report: "e", expectation: "f"),
            custody: custody("custody-2"),
            expectedCAS: casB,
            rootURL: rootB,
            injectedFault: .afterPendingMarker
        ))
        let bundleB = try AnalysisPhysicalRealAudioBridgeConsumptionQuiescentCustodyManager.makeCustodyBundle(
            ledgerID: "ledger",
            expectedSnapshot: preB,
            transactionID: "tx-rollback",
            checkpointID: "cp-1",
            checkpointSequence: 1,
            checkpointApprovalReference: "HQ-W52-CP-ROLLBACK",
            handoffID: "handoff-rollback",
            handoffApprovalReference: "HQ-W52-HO-ROLLBACK",
            rootURL: rootB
        )
        XCTAssertEqual(bundleB.snapshot, preB)
    }

    func testWriterVsCustodyRaceReturnsOnlyExactPreOrPostState() throws {
        for wave in 0..<24 {
            let root = try root()
            defer { try? FileManager.default.removeItem(at: root) }
            _ = try seed(root)
            let pre = try AnalysisPhysicalRealAudioBridgeConsumptionQuiescentCustodyManager.observeSnapshot(ledgerID: "ledger", rootURL: root)
            let writerCAS = try AnalysisPhysicalRealAudioBridgeConsumptionConcurrentStore.observeAppendCAS(ledgerID: "ledger", rootURL: root)
            let secondCertificate = try certificate(bridgeID: "bridge-2", package: "d", report: "e", expectation: "f")
            let secondCustody = custody("custody-2")
            let result = W52RaceResultBox()
            let queue = DispatchQueue(label: "w52-race-\(wave)", attributes: .concurrent)
            let group = DispatchGroup()

            group.enter()
            queue.async {
                defer { group.leave() }
                do {
                    _ = try AnalysisPhysicalRealAudioBridgeConsumptionConcurrentStore.append(
                        ledgerID: "ledger",
                        certificate: secondCertificate,
                        custody: secondCustody,
                        expectedCAS: writerCAS,
                        rootURL: root
                    )
                    result.setWriterSuccess()
                } catch {
                    result.setWriterError(error)
                }
            }

            group.enter()
            queue.async {
                defer { group.leave() }
                do {
                    result.setBundle(try AnalysisPhysicalRealAudioBridgeConsumptionQuiescentCustodyManager.makeCustodyBundle(
                        ledgerID: "ledger",
                        expectedSnapshot: pre,
                        transactionID: "tx-race-\(wave)",
                        checkpointID: "cp-race-\(wave)",
                        checkpointSequence: 1,
                        checkpointApprovalReference: "HQ-W52-CP-RACE",
                        handoffID: "handoff-race-\(wave)",
                        handoffApprovalReference: "HQ-W52-HO-RACE",
                        rootURL: root
                    ))
                } catch {
                    result.setBundleError(error)
                }
            }
            group.wait()
            XCTAssertTrue(result.writerSucceeded)
            XCTAssertNil(result.writerError)

            if let bundle = result.bundle {
                XCTAssertEqual(bundle.snapshot, pre)
                XCTAssertTrue(AnalysisPhysicalRealAudioBridgeConsumptionQuiescentCustodyManager.validateReceipt(
                    bundle.receipt, snapshot: bundle.snapshot, checkpoint: bundle.checkpoint, handoff: bundle.handoff
                ))
            } else {
                XCTAssertEqual(result.bundleError as? AnalysisPhysicalRealAudioBridgeConsumptionQuiescentCustodyError, .staleSnapshotCAS)
                let post = try AnalysisPhysicalRealAudioBridgeConsumptionQuiescentCustodyManager.observeSnapshot(ledgerID: "ledger", rootURL: root)
                XCTAssertEqual(post.latestSequence, pre.latestSequence + 1)
                let postBundle = try AnalysisPhysicalRealAudioBridgeConsumptionQuiescentCustodyManager.makeCustodyBundle(
                    ledgerID: "ledger",
                    expectedSnapshot: post,
                    transactionID: "tx-post-\(wave)",
                    checkpointID: "cp-post-\(wave)",
                    checkpointSequence: 1,
                    checkpointApprovalReference: "HQ-W52-CP-POST",
                    handoffID: "handoff-post-\(wave)",
                    handoffApprovalReference: "HQ-W52-HO-POST",
                    rootURL: root
                )
                XCTAssertEqual(postBundle.snapshot, post)
            }
        }
    }

    func testReceiptMutationIsRejected() throws {
        let root = try root(); defer { try? FileManager.default.removeItem(at: root) }
        _ = try seed(root)
        let snapshot = try AnalysisPhysicalRealAudioBridgeConsumptionQuiescentCustodyManager.observeSnapshot(ledgerID: "ledger", rootURL: root)
        let bundle = try AnalysisPhysicalRealAudioBridgeConsumptionQuiescentCustodyManager.makeCustodyBundle(
            ledgerID: "ledger",
            expectedSnapshot: snapshot,
            transactionID: "tx-1",
            checkpointID: "cp-1",
            checkpointSequence: 1,
            checkpointApprovalReference: "HQ-W52-CP-1",
            handoffID: "handoff-1",
            handoffApprovalReference: "HQ-W52-HO-1",
            rootURL: root
        )
        let bad = AnalysisPhysicalRealAudioBridgeConsumptionQuiescentCustodyReceipt(
            transactionID: bundle.receipt.transactionID,
            authority: bundle.receipt.authority,
            approvalReference: bundle.receipt.approvalReference,
            ledgerID: bundle.receipt.ledgerID,
            snapshotRootSHA256: sha("f"),
            checkpointRootSHA256: bundle.receipt.checkpointRootSHA256,
            handoffRootSHA256: bundle.receipt.handoffRootSHA256,
            ledgerSequence: bundle.receipt.ledgerSequence,
            ledgerRootSHA256: bundle.receipt.ledgerRootSHA256,
            latestRecordRootSHA256: bundle.receipt.latestRecordRootSHA256,
            consumedW47InventoryRootSHA256: bundle.receipt.consumedW47InventoryRootSHA256,
            predecessorCheckpointRootSHA256: bundle.receipt.predecessorCheckpointRootSHA256,
            predecessorHandoffRootSHA256: bundle.receipt.predecessorHandoffRootSHA256,
            limitations: bundle.receipt.limitations,
            declaredReceiptRootSHA256: bundle.receipt.declaredReceiptRootSHA256
        )
        XCTAssertFalse(AnalysisPhysicalRealAudioBridgeConsumptionQuiescentCustodyManager.validateReceipt(
            bad, snapshot: bundle.snapshot, checkpoint: bundle.checkpoint, handoff: bundle.handoff
        ))
    }
}

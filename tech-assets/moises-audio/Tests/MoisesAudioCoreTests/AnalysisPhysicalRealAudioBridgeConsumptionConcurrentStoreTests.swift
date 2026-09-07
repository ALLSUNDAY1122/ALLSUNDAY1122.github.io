import Foundation
import XCTest
@testable import MoisesAudioCore

final class AnalysisPhysicalRealAudioBridgeConsumptionConcurrentStoreTests: XCTestCase {
    private final class OutcomeBox: @unchecked Sendable {
        private let lock = NSLock()
        private(set) var successes = 0
        private(set) var staleCAS = 0
        private(set) var otherErrors: [String] = []

        func recordSuccess() {
            lock.lock(); successes += 1; lock.unlock()
        }

        func record(error: Error) {
            lock.lock()
            if error as? AnalysisPhysicalRealAudioBridgeConsumptionConcurrentWriterError == .staleWriterCAS {
                staleCAS += 1
            } else {
                otherErrors.append(String(describing: error))
            }
            lock.unlock()
        }
    }

    private func sha(_ character: Character) -> String {
        String(repeating: String(character), count: 64)
    }

    private func root() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("w51-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func custody(_ id: String = "custody-1") -> AnalysisPhysicalRealAudioBridgeConsumptionCustody {
        .init(authority: "HQ_LATE_INTEGRATION", approvalReference: "HQ-W51-CUSTODY", custodyID: id)
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
            manifestID: "manifest-w51",
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

    func testConcurrentDifferentWritersUsingSameCASProduceExactlyOneCommit() throws {
        let root = try root()
        defer { try? FileManager.default.removeItem(at: root) }
        let cas = try AnalysisPhysicalRealAudioBridgeConsumptionConcurrentStore.observeAppendCAS(
            ledgerID: "ledger", rootURL: root
        )
        let certA = try certificate(bridgeID: "bridge-a", package: "a", report: "b", expectation: "c")
        let certB = try certificate(bridgeID: "bridge-b", package: "d", report: "e", expectation: "f")
        let outcomes = OutcomeBox()
        let group = DispatchGroup()
        let queue = DispatchQueue(label: "w51.concurrent", attributes: .concurrent)
        let attempts = [(certA, custody("custody-a")), (certB, custody("custody-b"))]

        for (cert, attemptCustody) in attempts {
            group.enter()
            queue.async {
                defer { group.leave() }
                do {
                    _ = try AnalysisPhysicalRealAudioBridgeConsumptionConcurrentStore.append(
                        ledgerID: "ledger",
                        certificate: cert,
                        custody: attemptCustody,
                        expectedCAS: cas,
                        rootURL: root
                    )
                    outcomes.recordSuccess()
                } catch {
                    outcomes.record(error: error)
                }
            }
        }
        XCTAssertEqual(group.wait(timeout: .now() + 10), .success)
        XCTAssertEqual(outcomes.successes, 1)
        XCTAssertEqual(outcomes.staleCAS, 1)
        XCTAssertTrue(outcomes.otherErrors.isEmpty, "unexpected errors: \(outcomes.otherErrors)")
        let head = try XCTUnwrap(AnalysisPhysicalRealAudioBridgeConsumptionSecureStore.loadValidatedHead(
            ledgerID: "ledger", rootURL: root
        ))
        XCTAssertEqual(head.latestSequence, 1)
        XCTAssertEqual(head.records.count, 1)
    }

    func testFreshCASPreservesDuplicateCertificateRejection() throws {
        let root = try root()
        defer { try? FileManager.default.removeItem(at: root) }
        let cert = try certificate(bridgeID: "bridge-a", package: "a", report: "b", expectation: "c")
        let cas0 = try AnalysisPhysicalRealAudioBridgeConsumptionConcurrentStore.observeAppendCAS(ledgerID: "ledger", rootURL: root)
        _ = try AnalysisPhysicalRealAudioBridgeConsumptionConcurrentStore.append(
            ledgerID: "ledger", certificate: cert, custody: custody(), expectedCAS: cas0, rootURL: root
        )
        let cas1 = try AnalysisPhysicalRealAudioBridgeConsumptionConcurrentStore.observeAppendCAS(ledgerID: "ledger", rootURL: root)
        XCTAssertThrowsError(try AnalysisPhysicalRealAudioBridgeConsumptionConcurrentStore.append(
            ledgerID: "ledger", certificate: cert, custody: custody("custody-2"), expectedCAS: cas1, rootURL: root
        )) { error in
            XCTAssertEqual(error as? AnalysisPhysicalRealAudioBridgeConsumptionSecureStoreError, .duplicateBridgeID)
        }
    }

    func testInterruptedRecordWriterRollsForwardThenRejectsStaleSecondWriter() throws {
        let root = try root()
        defer { try? FileManager.default.removeItem(at: root) }
        let first = try certificate(bridgeID: "bridge-a", package: "a", report: "b", expectation: "c")
        let second = try certificate(bridgeID: "bridge-b", package: "d", report: "e", expectation: "f")
        let cas0 = try AnalysisPhysicalRealAudioBridgeConsumptionConcurrentStore.observeAppendCAS(ledgerID: "ledger", rootURL: root)

        XCTAssertThrowsError(try AnalysisPhysicalRealAudioBridgeConsumptionConcurrentStore.appendForTesting(
            ledgerID: "ledger",
            certificate: first,
            custody: custody(),
            expectedCAS: cas0,
            rootURL: root,
            injectedFault: .afterRecordWrite
        ))

        XCTAssertThrowsError(try AnalysisPhysicalRealAudioBridgeConsumptionConcurrentStore.append(
            ledgerID: "ledger",
            certificate: second,
            custody: custody("custody-2"),
            expectedCAS: cas0,
            rootURL: root
        )) { error in
            XCTAssertEqual(error as? AnalysisPhysicalRealAudioBridgeConsumptionConcurrentWriterError, .staleWriterCAS)
        }
        let cas1 = try AnalysisPhysicalRealAudioBridgeConsumptionConcurrentStore.observeAppendCAS(ledgerID: "ledger", rootURL: root)
        XCTAssertEqual(cas1.expectedLatestSequence, 1)
        let head = try AnalysisPhysicalRealAudioBridgeConsumptionConcurrentStore.append(
            ledgerID: "ledger", certificate: second, custody: custody("custody-2"), expectedCAS: cas1, rootURL: root
        )
        XCTAssertEqual(head.latestSequence, 2)
    }

    func testPendingOnlyInterruptedWriterAllowsSameCASSecondWriterAfterRollback() throws {
        let root = try root()
        defer { try? FileManager.default.removeItem(at: root) }
        let first = try certificate(bridgeID: "bridge-a", package: "a", report: "b", expectation: "c")
        let second = try certificate(bridgeID: "bridge-b", package: "d", report: "e", expectation: "f")
        let cas0 = try AnalysisPhysicalRealAudioBridgeConsumptionConcurrentStore.observeAppendCAS(ledgerID: "ledger", rootURL: root)
        XCTAssertThrowsError(try AnalysisPhysicalRealAudioBridgeConsumptionConcurrentStore.appendForTesting(
            ledgerID: "ledger", certificate: first, custody: custody(), expectedCAS: cas0, rootURL: root,
            injectedFault: .afterPendingMarker
        ))
        let head = try AnalysisPhysicalRealAudioBridgeConsumptionConcurrentStore.append(
            ledgerID: "ledger", certificate: second, custody: custody("custody-2"), expectedCAS: cas0, rootURL: root
        )
        XCTAssertEqual(head.latestSequence, 1)
        XCTAssertEqual(head.records.last?.bridgeID, "bridge-b")
    }

    func testAbandonedUnlockedLockFileIsReusedRatherThanBlockingRecovery() throws {
        let root = try root()
        defer { try? FileManager.default.removeItem(at: root) }
        let lockURL = AnalysisPhysicalRealAudioBridgeConsumptionWriterLock.lockURL(ledgerID: "ledger", rootURL: root)
        try FileManager.default.createDirectory(at: lockURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("abandoned-token\n".utf8).write(to: lockURL)
        let cas = try AnalysisPhysicalRealAudioBridgeConsumptionConcurrentStore.observeAppendCAS(ledgerID: "ledger", rootURL: root)
        XCTAssertEqual(cas.expectedLatestSequence, 0)
        let cert = try certificate(bridgeID: "bridge-a", package: "a", report: "b", expectation: "c")
        let head = try AnalysisPhysicalRealAudioBridgeConsumptionConcurrentStore.append(
            ledgerID: "ledger", certificate: cert, custody: custody(), expectedCAS: cas, rootURL: root
        )
        XCTAssertEqual(head.latestSequence, 1)
    }

    func testLockPathSubstitutionDuringLeaseFailsClosed() throws {
        let root = try root()
        defer { try? FileManager.default.removeItem(at: root) }
        XCTAssertThrowsError(try AnalysisPhysicalRealAudioBridgeConsumptionWriterLock.withExclusiveLock(
            ledgerID: "ledger", rootURL: root
        ) { lease in
            try FileManager.default.removeItem(at: lease.lockURL)
            try Data("replacement-token\n".utf8).write(to: lease.lockURL)
            return ()
        }) { error in
            XCTAssertEqual(error as? AnalysisPhysicalRealAudioBridgeConsumptionWriterLockError, .lockTokenMismatch)
        }
    }

    func testW51SerializedAppendPreservesW50OnDiskRoots() throws {
        let rootA = try root()
        let rootB = try root()
        defer {
            try? FileManager.default.removeItem(at: rootA)
            try? FileManager.default.removeItem(at: rootB)
        }
        let cert = try certificate(bridgeID: "bridge-a", package: "a", report: "b", expectation: "c")
        let direct = try AnalysisPhysicalRealAudioBridgeConsumptionSecureStore.append(
            ledgerID: "ledger", certificate: cert, custody: custody(), rootURL: rootA
        )
        let cas = try AnalysisPhysicalRealAudioBridgeConsumptionConcurrentStore.observeAppendCAS(ledgerID: "ledger", rootURL: rootB)
        let serialized = try AnalysisPhysicalRealAudioBridgeConsumptionConcurrentStore.append(
            ledgerID: "ledger", certificate: cert, custody: custody(), expectedCAS: cas, rootURL: rootB
        )
        XCTAssertEqual(serialized, direct)
    }

    func testMalformedCASFailsBeforeFilesystemPublication() throws {
        let root = try root()
        defer { try? FileManager.default.removeItem(at: root) }
        let cert = try certificate(bridgeID: "bridge-a", package: "a", report: "b", expectation: "c")
        let invalid = AnalysisPhysicalRealAudioBridgeConsumptionAppendCAS(
            ledgerID: "ledger",
            expectedLatestSequence: 1,
            expectedLedgerRootSHA256: nil,
            expectedLatestRecordRootSHA256: nil
        )
        XCTAssertThrowsError(try AnalysisPhysicalRealAudioBridgeConsumptionConcurrentStore.append(
            ledgerID: "ledger", certificate: cert, custody: custody(), expectedCAS: invalid, rootURL: root
        )) { error in
            XCTAssertEqual(error as? AnalysisPhysicalRealAudioBridgeConsumptionConcurrentWriterError, .invalidCAS)
        }
        XCTAssertNil(try AnalysisPhysicalRealAudioBridgeConsumptionSecureStore.loadValidatedHead(
            ledgerID: "ledger", rootURL: root
        ))
    }
}

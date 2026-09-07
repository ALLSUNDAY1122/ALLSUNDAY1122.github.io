import Foundation
import XCTest
@testable import MoisesAudioCore

final class AnalysisPhysicalRealAudioBridgeConsumptionNormalizedConcurrentStoreTests: XCTestCase {
    private func sha(_ character: Character) -> String { String(repeating: String(character), count: 64) }

    private func root() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("w55-concurrent-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func custody(_ index: Int) -> AnalysisPhysicalRealAudioBridgeConsumptionCustody {
        .init(authority: "HQ_LATE_INTEGRATION", approvalReference: "HQ-W55-\(index)", custodyID: "custody-w55-\(index)")
    }

    private func certificate(_ index: Int) throws -> AnalysisPhysicalRealAudioParityBridgeCertificate {
        let digits = Array("0123456789abcdef")
        let provisional = AnalysisPhysicalRealAudioParityBridgeCertificate(
            bridgeID: "bridge-w55-c-\(index)",
            expectationRootSHA256: String(repeating: String(digits[(index + 1) % 16]), count: 64),
            w47PackageRootSHA256: String(repeating: String(digits[(index + 2) % 16]), count: 64),
            w47PackageBytesSHA256: sha("4"),
            manifestID: "manifest-w55-c-\(index)",
            manifestSHA256: sha("5"),
            runtimeBindingSHA256: sha("6"),
            physicalSessionID: "session-w55-c-\(index)",
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

    func testNewLedgerCASAndAppendShareNormalizedPredecessor() throws {
        let root = try root()
        defer { try? FileManager.default.removeItem(at: root) }
        let observed = try AnalysisPhysicalRealAudioBridgeConsumptionNormalizedConcurrentStore.observeAppendCAS(
            ledgerID: "ledger", rootURL: root
        )
        XCTAssertEqual(observed.cas.expectedLatestSequence, 0)
        XCTAssertEqual(observed.normalizationReceipt.latestSequence, 0)

        let result = try AnalysisPhysicalRealAudioBridgeConsumptionNormalizedConcurrentStore.append(
            ledgerID: "ledger",
            certificate: certificate(1),
            custody: custody(1),
            expectedCAS: observed.cas,
            rootURL: root
        )
        XCTAssertEqual(result.head.latestSequence, 1)
        XCTAssertEqual(result.predecessorNormalizationReceipt, observed.normalizationReceipt)

        let after = try AnalysisPhysicalRealAudioBridgeConsumptionNormalizedConcurrentStore.observeAppendCAS(
            ledgerID: "ledger", rootURL: root
        )
        XCTAssertEqual(after.cas.expectedLatestSequence, 1)
        XCTAssertEqual(after.normalizationReceipt.latestSequence, 1)
        XCTAssertEqual(after.normalizationReceipt.ledgerRootSHA256, result.head.declaredLedgerRootSHA256)
    }

    func testSecondWriterWithSameCASFailsStaleAfterFirstCommit() throws {
        let root = try root()
        defer { try? FileManager.default.removeItem(at: root) }
        let firstView = try AnalysisPhysicalRealAudioBridgeConsumptionNormalizedConcurrentStore.observeAppendCAS(
            ledgerID: "ledger", rootURL: root
        )
        _ = try AnalysisPhysicalRealAudioBridgeConsumptionNormalizedConcurrentStore.append(
            ledgerID: "ledger",
            certificate: certificate(1),
            custody: custody(1),
            expectedCAS: firstView.cas,
            rootURL: root
        )
        XCTAssertThrowsError(try AnalysisPhysicalRealAudioBridgeConsumptionNormalizedConcurrentStore.append(
            ledgerID: "ledger",
            certificate: certificate(2),
            custody: custody(2),
            expectedCAS: firstView.cas,
            rootURL: root
        )) { error in
            XCTAssertEqual(error as? AnalysisPhysicalRealAudioBridgeConsumptionConcurrentWriterError, .staleWriterCAS)
        }
    }

    func testObserveCASGarbageCollectsBothTempDirectoriesBeforeIssuingView() throws {
        let root = try root()
        defer { try? FileManager.default.removeItem(at: root) }
        try AnalysisPhysicalRealAudioBridgeConsumptionSecureFilesystem.ensureDirectories(
            ledgerID: "ledger", rootURL: root, fileManager: .default
        )
        let ledger = AnalysisPhysicalRealAudioBridgeConsumptionSecureFilesystem.ledgerURL(
            ledgerID: "ledger", rootURL: root
        )
        let records = ledger.appendingPathComponent("records", isDirectory: true)
        try Data("a".utf8).write(to: ledger.appendingPathComponent(".w53-pub-a.tmp"))
        try Data("b".utf8).write(to: records.appendingPathComponent(".w53-pub-b.tmp"))

        let observed = try AnalysisPhysicalRealAudioBridgeConsumptionNormalizedConcurrentStore.observeAppendCAS(
            ledgerID: "ledger", rootURL: root
        )
        XCTAssertEqual(observed.cas.expectedLatestSequence, 0)
        XCTAssertEqual(observed.normalizationReceipt.removedLedgerTemporaryCount, 1)
        XCTAssertEqual(observed.normalizationReceipt.removedRecordTemporaryCount, 1)
    }
}

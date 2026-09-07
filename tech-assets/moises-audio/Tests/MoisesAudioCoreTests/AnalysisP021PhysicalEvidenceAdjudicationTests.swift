import Foundation
import XCTest
@testable import MoisesAudioCore

final class AnalysisP021PhysicalEvidenceAdjudicationTests: XCTestCase {
    private func sha(_ character: Character) -> String {
        String(repeating: String(character), count: 64)
    }

    private var runSummary: AnalysisPhysicalEvidenceBatchRunSummary {
        .init(runID: "run-a", workloadExecutionID: "exec-a", w39BundleRootSHA256: sha("a"))
    }

    private var expectation: AnalysisPhysicalEvidenceLedgerCheckpointExpectation {
        .init(
            checkpointID: "w44-checkpoint-1",
            checkpointSequence: 1,
            authority: "HQ_LATE_INTEGRATION",
            approvalReference: "HQ-W44-1",
            expectedLedgerID: "ledger-w43",
            expectedAnchorID: "anchor-w42",
            minimumLedgerSequence: 1,
            expectedLatestLedgerSequence: 1,
            expectedLatestAnchorReceiptRootSHA256: sha("b"),
            expectedLedgerRootSHA256: sha("c")
        )
    }

    private var checkpointCertificate: AnalysisPhysicalEvidenceLedgerCheckpointCertificate {
        .init(
            status: .verifiedAgainstExternalLedgerCheckpointNonParity,
            checkpointID: expectation.checkpointID,
            checkpointSequence: expectation.checkpointSequence,
            checkpointExpectationRootSHA256: sha("d"),
            ledgerID: expectation.expectedLedgerID,
            anchorID: expectation.expectedAnchorID,
            expectedMinimumLedgerSequence: 1,
            expectedLatestLedgerSequence: 1,
            observedLatestLedgerSequence: 1,
            expectedLatestAnchorReceiptRootSHA256: sha("b"),
            observedLatestAnchorReceiptRootSHA256: sha("b"),
            expectedLedgerRootSHA256: sha("c"),
            observedLedgerRootSHA256: sha("c"),
            observedLatestCertificateRootSHA256: sha("e"),
            observedLatestRecordRootSHA256: sha("f"),
            recordCount: 1,
            predecessorCheckpointCertificateRootSHA256: nil,
            limitations: AnalysisPhysicalEvidenceLedgerCheckpointVerifier.limitations,
            declaredCertificateRootSHA256: sha("1")
        )
    }

    private var anchorReceipt: AnalysisPhysicalEvidenceAnchorReceipt {
        get throws {
            let anchor = AnalysisPhysicalEvidenceExternalRootAnchor(
                anchorID: expectation.expectedAnchorID,
                anchorSequence: 1,
                authority: "HQ_LATE_INTEGRATION",
                approvalReference: "HQ-W42-1",
                publicationID: "publication-a",
                transferID: "transfer-a",
                w27RootSHA256: sha("2"),
                w38RootSHA256: sha("3"),
                w40RootSHA256: sha("4"),
                w41RootSHA256: sha("5"),
                runs: [runSummary]
            )
            return try AnalysisPhysicalEvidenceAnchorReceiptIssuer.issue(anchor: anchor)
        }
    }

    private var transfer: AnalysisPhysicalEvidenceTransferManifest {
        .init(
            transferID: "transfer-a",
            publicationID: "publication-a",
            w40RootSHA256: sha("4"),
            w27RootSHA256: sha("2"),
            w38RootSHA256: sha("3"),
            runs: [runSummary],
            items: [],
            declaredTransferRootSHA256: sha("5")
        )
    }

    private var reopened: AnalysisPhysicalEvidenceReopenedBatch {
        .init(
            publicationID: "publication-a",
            w40RootSHA256: sha("4"),
            w27RootSHA256: sha("2"),
            w38RootSHA256: sha("3"),
            runSummaries: [runSummary],
            items: []
        )
    }

    private func runtimeBinding(
        decoderOrigin: AnalysisP021DecoderOrigin = .genuineLane2BoundedDecoder,
        checkpointRoot: String? = nil,
        anchorRoot: String? = nil,
        transferRoot: String? = nil,
        runExecutions: [AnalysisP021RunExecutionBinding]? = nil
    ) throws -> AnalysisP021RuntimeBinding {
        .init(
            authority: "HQ_LATE_INTEGRATION",
            approvalReference: "HQ-W45-RUNTIME",
            runtimeBindingID: "runtime-w45",
            decoderOrigin: decoderOrigin,
            decoderImplementationID: "lane2-bounded-decoder-v1",
            decoderSourceRevision: "decoder-revision-a",
            platform: "iphoneos",
            architecture: "arm64",
            xcodeVersion: "Xcode-selected",
            swiftVersion: "Swift-selected",
            sourceRevision: "app-revision-a",
            buildIdentity: "build-a",
            appBundleIdentifier: "example.moises",
            appVersion: "1.0",
            buildVersion: "1",
            deviceModel: "iPhone-selected",
            osVersion: "iOS-selected",
            physicalCaptureSessionID: "capture-session-a",
            w44CheckpointCertificateRootSHA256: try (checkpointRoot ?? checkpointCertificate.declaredCertificateRootSHA256),
            w42AnchorReceiptRootSHA256: try (anchorRoot ?? anchorReceipt.declaredAnchorReceiptRootSHA256),
            w41TransferRootSHA256: try (transferRoot ?? transfer.declaredTransferRootSHA256),
            runExecutions: runExecutions ?? [
                .init(runID: runSummary.runID, workloadExecutionID: runSummary.workloadExecutionID)
            ]
        )
    }

    func testMissingPhysicalEvidenceIsNotReadyEvenWithGenuineRuntimeClaim() throws {
        let report = try AnalysisP021PhysicalEvidenceAdjudicator.adjudicateVerifiedInputs(
            checkpointExpectation: expectation,
            checkpointCertificate: checkpointCertificate,
            anchorReceipt: anchorReceipt,
            transfer: transfer,
            reopened: reopened,
            runtimeBinding: runtimeBinding()
        )
        XCTAssertEqual(report.status, .notReadyForHQJudgment)
        XCTAssertTrue(report.issues.contains { $0.code == .missingSingleton })
        XCTAssertEqual(
            try AnalysisP021AdjudicationReportRoot.compute(report),
            report.declaredReportRootSHA256
        )
    }

    func testCompatibilityAdapterCanNeverBecomeReady() throws {
        let report = try AnalysisP021PhysicalEvidenceAdjudicator.adjudicateVerifiedInputs(
            checkpointExpectation: expectation,
            checkpointCertificate: checkpointCertificate,
            anchorReceipt: anchorReceipt,
            transfer: transfer,
            reopened: reopened,
            runtimeBinding: runtimeBinding(decoderOrigin: .compatibilityAdapter)
        )
        XCTAssertEqual(report.status, .notReadyForHQJudgment)
        XCTAssertTrue(report.issues.contains { $0.code == .compatibilityOrSyntheticRuntime })
    }

    func testSyntheticFixtureCanNeverBecomeReady() throws {
        let report = try AnalysisP021PhysicalEvidenceAdjudicator.adjudicateVerifiedInputs(
            checkpointExpectation: expectation,
            checkpointCertificate: checkpointCertificate,
            anchorReceipt: anchorReceipt,
            transfer: transfer,
            reopened: reopened,
            runtimeBinding: runtimeBinding(decoderOrigin: .syntheticFixture)
        )
        XCTAssertEqual(report.status, .notReadyForHQJudgment)
        XCTAssertTrue(report.issues.contains { $0.code == .compatibilityOrSyntheticRuntime })
    }

    func testMixedCheckpointAnchorOrTransferRootsAreRejectedByReadinessGate() throws {
        for binding in [
            try runtimeBinding(checkpointRoot: sha("6")),
            try runtimeBinding(anchorRoot: sha("7")),
            try runtimeBinding(transferRoot: sha("8"))
        ] {
            let report = try AnalysisP021PhysicalEvidenceAdjudicator.adjudicateVerifiedInputs(
                checkpointExpectation: expectation,
                checkpointCertificate: checkpointCertificate,
                anchorReceipt: anchorReceipt,
                transfer: transfer,
                reopened: reopened,
                runtimeBinding: binding
            )
            XCTAssertEqual(report.status, .notReadyForHQJudgment)
            XCTAssertTrue(report.issues.contains { $0.code == .runtimeBindingMismatch })
        }
    }

    func testExecutionInventorySubstitutionIsRejected() throws {
        let binding = try runtimeBinding(runExecutions: [
            .init(runID: "run-a", workloadExecutionID: "exec-substituted")
        ])
        let report = try AnalysisP021PhysicalEvidenceAdjudicator.adjudicateVerifiedInputs(
            checkpointExpectation: expectation,
            checkpointCertificate: checkpointCertificate,
            anchorReceipt: anchorReceipt,
            transfer: transfer,
            reopened: reopened,
            runtimeBinding: binding
        )
        XCTAssertEqual(report.status, .notReadyForHQJudgment)
        XCTAssertTrue(report.issues.contains { $0.code == .runtimeBindingMismatch })
    }

    func testDuplicateRuntimeExecutionIDsFailClosed() throws {
        let second = AnalysisPhysicalEvidenceBatchRunSummary(
            runID: "run-b",
            workloadExecutionID: "exec-b",
            w39BundleRootSHA256: sha("9")
        )
        let twoRunTransfer = AnalysisPhysicalEvidenceTransferManifest(
            transferID: transfer.transferID,
            publicationID: transfer.publicationID,
            w40RootSHA256: transfer.w40RootSHA256,
            w27RootSHA256: transfer.w27RootSHA256,
            w38RootSHA256: transfer.w38RootSHA256,
            runs: [runSummary, second],
            items: [],
            declaredTransferRootSHA256: transfer.declaredTransferRootSHA256
        )
        let binding = try runtimeBinding(runExecutions: [
            .init(runID: "run-a", workloadExecutionID: "exec-a"),
            .init(runID: "run-b", workloadExecutionID: "exec-a")
        ])
        let report = try AnalysisP021PhysicalEvidenceAdjudicator.adjudicateVerifiedInputs(
            checkpointExpectation: expectation,
            checkpointCertificate: checkpointCertificate,
            anchorReceipt: anchorReceipt,
            transfer: twoRunTransfer,
            reopened: reopened,
            runtimeBinding: binding
        )
        XCTAssertEqual(report.status, .notReadyForHQJudgment)
        XCTAssertTrue(report.issues.contains { $0.code == .invalidRuntimeBinding })
    }

    func testReportRootAndEncodingAreDeterministic() throws {
        let a = try AnalysisP021PhysicalEvidenceAdjudicator.adjudicateVerifiedInputs(
            checkpointExpectation: expectation,
            checkpointCertificate: checkpointCertificate,
            anchorReceipt: anchorReceipt,
            transfer: transfer,
            reopened: reopened,
            runtimeBinding: runtimeBinding()
        )
        let b = try AnalysisP021PhysicalEvidenceAdjudicator.adjudicateVerifiedInputs(
            checkpointExpectation: expectation,
            checkpointCertificate: checkpointCertificate,
            anchorReceipt: anchorReceipt,
            transfer: transfer,
            reopened: reopened,
            runtimeBinding: runtimeBinding()
        )
        XCTAssertEqual(a, b)
        XCTAssertEqual(a.declaredReportRootSHA256, b.declaredReportRootSHA256)
        XCTAssertEqual(
            try AnalysisP021PhysicalEvidenceAdjudicationCodec.decodeReport(
                AnalysisP021PhysicalEvidenceAdjudicationCodec.encodeReport(a)
            ),
            a
        )
    }
}

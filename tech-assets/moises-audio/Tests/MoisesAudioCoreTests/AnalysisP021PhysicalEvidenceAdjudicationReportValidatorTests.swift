import Foundation
import XCTest
@testable import MoisesAudioCore

final class AnalysisP021PhysicalEvidenceAdjudicationReportValidatorTests: XCTestCase {
    private func sha(_ character: Character) -> String {
        String(repeating: String(character), count: 64)
    }

    private func issue() -> AnalysisP021AdjudicationIssue {
        .init(code: .missingSingleton, detail: "physical evidence intentionally absent")
    }

    private func makeNotReadyReport() throws -> AnalysisP021PhysicalEvidenceAdjudicationReport {
        let provisional = AnalysisP021PhysicalEvidenceAdjudicationReport(
            status: .notReadyForHQJudgment,
            checkpointID: "checkpoint-w45",
            checkpointSequence: 1,
            checkpointCertificateRootSHA256: sha("a"),
            anchorID: "anchor-w45",
            anchorSequence: 1,
            anchorReceiptRootSHA256: sha("b"),
            transferID: "transfer-w45",
            transferRootSHA256: sha("c"),
            publicationID: "publication-w45",
            w24ProfileID: nil,
            w24BatchID: nil,
            plannedRunCount: 0,
            observedRunCount: 0,
            runtimeBindingID: "runtime-w45",
            runAdjudications: [],
            issues: [issue()],
            limitations: AnalysisP021PhysicalEvidenceAdjudicator.limitations,
            declaredReportRootSHA256: String(repeating: "0", count: 64)
        )
        let root = try AnalysisP021AdjudicationReportRoot.compute(provisional)
        return .init(
            status: provisional.status,
            checkpointID: provisional.checkpointID,
            checkpointSequence: provisional.checkpointSequence,
            checkpointCertificateRootSHA256: provisional.checkpointCertificateRootSHA256,
            anchorID: provisional.anchorID,
            anchorSequence: provisional.anchorSequence,
            anchorReceiptRootSHA256: provisional.anchorReceiptRootSHA256,
            transferID: provisional.transferID,
            transferRootSHA256: provisional.transferRootSHA256,
            publicationID: provisional.publicationID,
            w24ProfileID: provisional.w24ProfileID,
            w24BatchID: provisional.w24BatchID,
            plannedRunCount: provisional.plannedRunCount,
            observedRunCount: provisional.observedRunCount,
            runtimeBindingID: provisional.runtimeBindingID,
            runAdjudications: provisional.runAdjudications,
            issues: provisional.issues,
            limitations: provisional.limitations,
            declaredReportRootSHA256: root
        )
    }

    func testValidNotReadyReportReopensDeterministically() throws {
        let report = try makeNotReadyReport()
        XCTAssertTrue(AnalysisP021PhysicalEvidenceAdjudicationReportValidator.validate(report))
        let encoded = try AnalysisP021PhysicalEvidenceAdjudicationCodec.encodeReport(report)
        let decoded = try AnalysisP021PhysicalEvidenceAdjudicationCodec.decodeReport(encoded)
        XCTAssertEqual(decoded, report)
        XCTAssertTrue(AnalysisP021PhysicalEvidenceAdjudicationReportValidator.validate(decoded))
    }

    func testReadyWithoutPhysicalRunsIsRejectedEvenWithRecomputedRoot() throws {
        let base = try makeNotReadyReport()
        let provisional = AnalysisP021PhysicalEvidenceAdjudicationReport(
            status: .readyForHQJudgment,
            checkpointID: base.checkpointID,
            checkpointSequence: base.checkpointSequence,
            checkpointCertificateRootSHA256: base.checkpointCertificateRootSHA256,
            anchorID: base.anchorID,
            anchorSequence: base.anchorSequence,
            anchorReceiptRootSHA256: base.anchorReceiptRootSHA256,
            transferID: base.transferID,
            transferRootSHA256: base.transferRootSHA256,
            publicationID: base.publicationID,
            w24ProfileID: "profile-w24",
            w24BatchID: "batch-w24",
            plannedRunCount: 1,
            observedRunCount: 0,
            runtimeBindingID: base.runtimeBindingID,
            runAdjudications: [],
            issues: [],
            limitations: base.limitations,
            declaredReportRootSHA256: String(repeating: "0", count: 64)
        )
        let root = try AnalysisP021AdjudicationReportRoot.compute(provisional)
        let forged = AnalysisP021PhysicalEvidenceAdjudicationReport(
            status: provisional.status,
            checkpointID: provisional.checkpointID,
            checkpointSequence: provisional.checkpointSequence,
            checkpointCertificateRootSHA256: provisional.checkpointCertificateRootSHA256,
            anchorID: provisional.anchorID,
            anchorSequence: provisional.anchorSequence,
            anchorReceiptRootSHA256: provisional.anchorReceiptRootSHA256,
            transferID: provisional.transferID,
            transferRootSHA256: provisional.transferRootSHA256,
            publicationID: provisional.publicationID,
            w24ProfileID: provisional.w24ProfileID,
            w24BatchID: provisional.w24BatchID,
            plannedRunCount: provisional.plannedRunCount,
            observedRunCount: provisional.observedRunCount,
            runtimeBindingID: provisional.runtimeBindingID,
            runAdjudications: provisional.runAdjudications,
            issues: provisional.issues,
            limitations: provisional.limitations,
            declaredReportRootSHA256: root
        )
        XCTAssertFalse(AnalysisP021PhysicalEvidenceAdjudicationReportValidator.validate(forged))
    }

    func testTamperedDeclaredRootIsRejected() throws {
        let base = try makeNotReadyReport()
        let tampered = AnalysisP021PhysicalEvidenceAdjudicationReport(
            status: base.status,
            checkpointID: base.checkpointID,
            checkpointSequence: base.checkpointSequence,
            checkpointCertificateRootSHA256: base.checkpointCertificateRootSHA256,
            anchorID: base.anchorID,
            anchorSequence: base.anchorSequence,
            anchorReceiptRootSHA256: base.anchorReceiptRootSHA256,
            transferID: base.transferID,
            transferRootSHA256: base.transferRootSHA256,
            publicationID: base.publicationID,
            w24ProfileID: base.w24ProfileID,
            w24BatchID: base.w24BatchID,
            plannedRunCount: base.plannedRunCount,
            observedRunCount: base.observedRunCount,
            runtimeBindingID: base.runtimeBindingID,
            runAdjudications: base.runAdjudications,
            issues: base.issues,
            limitations: base.limitations,
            declaredReportRootSHA256: sha("f")
        )
        XCTAssertFalse(AnalysisP021PhysicalEvidenceAdjudicationReportValidator.validate(tampered))
    }

    func testNotReadyWithoutIssuesIsRejected() throws {
        let base = try makeNotReadyReport()
        let provisional = AnalysisP021PhysicalEvidenceAdjudicationReport(
            status: .notReadyForHQJudgment,
            checkpointID: base.checkpointID,
            checkpointSequence: base.checkpointSequence,
            checkpointCertificateRootSHA256: base.checkpointCertificateRootSHA256,
            anchorID: base.anchorID,
            anchorSequence: base.anchorSequence,
            anchorReceiptRootSHA256: base.anchorReceiptRootSHA256,
            transferID: base.transferID,
            transferRootSHA256: base.transferRootSHA256,
            publicationID: base.publicationID,
            w24ProfileID: nil,
            w24BatchID: nil,
            plannedRunCount: 0,
            observedRunCount: 0,
            runtimeBindingID: base.runtimeBindingID,
            runAdjudications: [],
            issues: [],
            limitations: base.limitations,
            declaredReportRootSHA256: String(repeating: "0", count: 64)
        )
        let root = try AnalysisP021AdjudicationReportRoot.compute(provisional)
        let invalid = AnalysisP021PhysicalEvidenceAdjudicationReport(
            status: provisional.status,
            checkpointID: provisional.checkpointID,
            checkpointSequence: provisional.checkpointSequence,
            checkpointCertificateRootSHA256: provisional.checkpointCertificateRootSHA256,
            anchorID: provisional.anchorID,
            anchorSequence: provisional.anchorSequence,
            anchorReceiptRootSHA256: provisional.anchorReceiptRootSHA256,
            transferID: provisional.transferID,
            transferRootSHA256: provisional.transferRootSHA256,
            publicationID: provisional.publicationID,
            w24ProfileID: provisional.w24ProfileID,
            w24BatchID: provisional.w24BatchID,
            plannedRunCount: provisional.plannedRunCount,
            observedRunCount: provisional.observedRunCount,
            runtimeBindingID: provisional.runtimeBindingID,
            runAdjudications: provisional.runAdjudications,
            issues: provisional.issues,
            limitations: provisional.limitations,
            declaredReportRootSHA256: root
        )
        XCTAssertFalse(AnalysisP021PhysicalEvidenceAdjudicationReportValidator.validate(invalid))
    }
}

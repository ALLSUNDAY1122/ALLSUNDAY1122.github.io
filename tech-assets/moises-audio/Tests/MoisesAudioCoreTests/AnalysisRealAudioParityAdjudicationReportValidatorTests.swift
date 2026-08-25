import Foundation
import XCTest
@testable import MoisesAudioCore

final class AnalysisRealAudioParityAdjudicationReportValidatorTests: XCTestCase {
    private func sha(_ character: Character) -> String {
        String(repeating: String(character), count: 64)
    }

    private func row(
        id: String,
        domain: String,
        metric: String,
        status: AnalysisAnalysisParityRowStatus = .notReadyForHQRowJudgment,
        observedPairCount: Int = 0,
        issues: [AnalysisAnalysisParityAdjudicationIssue]? = nil
    ) -> AnalysisAnalysisParityRowAdjudication {
        let rowIssues = issues ?? [
            .init(code: .rowInventoryMismatch, parityRowID: id, domain: domain, detail: "fixture-level evidence intentionally absent")
        ]
        return .init(
            parityRowID: id,
            feature: id,
            domain: domain,
            status: status,
            expectedFixtureIDs: ["fixture-a"],
            requiredMetrics: [metric],
            expectedPairCount: 1,
            observedPairCount: observedPairCount,
            failedPairCount: 0,
            nonParityCandidatePairCount: 0,
            worstRegression: status == .readyForHQRowJudgment ? 0 : nil,
            worstFixtureID: status == .readyForHQRowJudgment ? "fixture-a" : nil,
            issues: rowIssues
        )
    }

    private func rows() -> [AnalysisAnalysisParityRowAdjudication] {
        [
            row(id: "MOI-P009", domain: "tempo", metric: "tempo_rel_error"),
            row(id: "MOI-P011", domain: "key", metric: "weighted_key_score"),
            row(id: "MOI-P013", domain: "chord", metric: "root_weighted_accuracy"),
            row(id: "MOI-P016", domain: "structure", metric: "pairwise_f")
        ]
    }

    private func makeReport(
        status: AnalysisAnalysisParityAdjudicationStatus = .notReadyForHQJudgment,
        rows: [AnalysisAnalysisParityRowAdjudication]? = nil,
        issues: [AnalysisAnalysisParityAdjudicationIssue]? = nil,
        referenceRoot: String? = nil,
        differentialRoot: String? = nil
    ) throws -> AnalysisAnalysisParityAdjudicationReport {
        let actualIssues = issues ?? [
            .init(code: .referenceNotReady, detail: "real current-iPhone reference intentionally absent")
        ]
        let provisional = AnalysisAnalysisParityAdjudicationReport(
            status: status,
            bindingID: "binding-w46",
            bindingRootSHA256: sha("a"),
            manifestID: "manifest-w46",
            manifestSHA256: sha("b"),
            coveragePolicyRootSHA256: sha("c"),
            captureSetRootSHA256: sha("d"),
            capturePolicyRootSHA256: sha("e"),
            reviewSetRootSHA256: sha("f"),
            reviewPolicyRootSHA256: sha("1"),
            toleranceProfileRootSHA256: sha("2"),
            projectReportRootSHA256: sha("3"),
            referenceReportRootSHA256: referenceRoot,
            differentialReportRootSHA256: differentialRoot,
            eligibleFixtureIDs: ["fixture-a"],
            rowAdjudications: rows ?? self.rows(),
            issues: actualIssues,
            limitations: AnalysisRealAudioParityAdjudicator.limitations,
            declaredReportRootSHA256: String(repeating: "0", count: 64)
        )
        let root = try AnalysisAnalysisParityAdjudicationRoot.reportSHA256(provisional)
        return .init(
            status: provisional.status,
            bindingID: provisional.bindingID,
            bindingRootSHA256: provisional.bindingRootSHA256,
            manifestID: provisional.manifestID,
            manifestSHA256: provisional.manifestSHA256,
            coveragePolicyRootSHA256: provisional.coveragePolicyRootSHA256,
            captureSetRootSHA256: provisional.captureSetRootSHA256,
            capturePolicyRootSHA256: provisional.capturePolicyRootSHA256,
            reviewSetRootSHA256: provisional.reviewSetRootSHA256,
            reviewPolicyRootSHA256: provisional.reviewPolicyRootSHA256,
            toleranceProfileRootSHA256: provisional.toleranceProfileRootSHA256,
            projectReportRootSHA256: provisional.projectReportRootSHA256,
            referenceReportRootSHA256: provisional.referenceReportRootSHA256,
            differentialReportRootSHA256: provisional.differentialReportRootSHA256,
            eligibleFixtureIDs: provisional.eligibleFixtureIDs,
            rowAdjudications: provisional.rowAdjudications,
            issues: provisional.issues,
            limitations: provisional.limitations,
            declaredReportRootSHA256: root
        )
    }

    func testValidNotReadyReportReopensDeterministically() throws {
        let report = try makeReport()
        XCTAssertTrue(AnalysisAnalysisParityAdjudicationReportValidator.validate(report))
        let encoded = try AnalysisAnalysisParityAdjudicationCodec.encodeReport(report)
        let decoded = try AnalysisAnalysisParityAdjudicationCodec.decodeReport(encoded)
        XCTAssertEqual(decoded, report)
        XCTAssertTrue(AnalysisAnalysisParityAdjudicationReportValidator.validate(decoded))
    }

    func testForgedReadyWithRecomputedRootButIncompleteRowsIsRejected() throws {
        let readyRows = [
            row(id: "MOI-P009", domain: "tempo", metric: "tempo_rel_error", status: .readyForHQRowJudgment, observedPairCount: 0, issues: []),
            row(id: "MOI-P011", domain: "key", metric: "weighted_key_score", status: .readyForHQRowJudgment, observedPairCount: 0, issues: []),
            row(id: "MOI-P013", domain: "chord", metric: "root_weighted_accuracy", status: .readyForHQRowJudgment, observedPairCount: 0, issues: []),
            row(id: "MOI-P016", domain: "structure", metric: "pairwise_f", status: .readyForHQRowJudgment, observedPairCount: 0, issues: [])
        ]
        let forged = try makeReport(
            status: .readyForHQJudgment,
            rows: readyRows,
            issues: [],
            referenceRoot: sha("4"),
            differentialRoot: sha("5")
        )
        XCTAssertFalse(AnalysisAnalysisParityAdjudicationReportValidator.validate(forged))
    }

    func testReadyWithoutReferenceOrDifferentialRootIsRejected() throws {
        let readyRows = [
            row(id: "MOI-P009", domain: "tempo", metric: "tempo_rel_error", status: .readyForHQRowJudgment, observedPairCount: 1, issues: []),
            row(id: "MOI-P011", domain: "key", metric: "weighted_key_score", status: .readyForHQRowJudgment, observedPairCount: 1, issues: []),
            row(id: "MOI-P013", domain: "chord", metric: "root_weighted_accuracy", status: .readyForHQRowJudgment, observedPairCount: 1, issues: []),
            row(id: "MOI-P016", domain: "structure", metric: "pairwise_f", status: .readyForHQRowJudgment, observedPairCount: 1, issues: [])
        ]
        let forged = try makeReport(status: .readyForHQJudgment, rows: readyRows, issues: [])
        XCTAssertFalse(AnalysisAnalysisParityAdjudicationReportValidator.validate(forged))
    }

    func testTamperedReportRootIsRejected() throws {
        let base = try makeReport()
        let tampered = AnalysisAnalysisParityAdjudicationReport(
            status: base.status,
            bindingID: base.bindingID,
            bindingRootSHA256: base.bindingRootSHA256,
            manifestID: base.manifestID,
            manifestSHA256: base.manifestSHA256,
            coveragePolicyRootSHA256: base.coveragePolicyRootSHA256,
            captureSetRootSHA256: base.captureSetRootSHA256,
            capturePolicyRootSHA256: base.capturePolicyRootSHA256,
            reviewSetRootSHA256: base.reviewSetRootSHA256,
            reviewPolicyRootSHA256: base.reviewPolicyRootSHA256,
            toleranceProfileRootSHA256: base.toleranceProfileRootSHA256,
            projectReportRootSHA256: base.projectReportRootSHA256,
            referenceReportRootSHA256: base.referenceReportRootSHA256,
            differentialReportRootSHA256: base.differentialReportRootSHA256,
            eligibleFixtureIDs: base.eligibleFixtureIDs,
            rowAdjudications: base.rowAdjudications,
            issues: base.issues,
            limitations: base.limitations,
            declaredReportRootSHA256: sha("9")
        )
        XCTAssertFalse(AnalysisAnalysisParityAdjudicationReportValidator.validate(tampered))
    }

    func testMissingRequiredParityRowIsRejected() throws {
        let incomplete = Array(rows().dropLast())
        let report = try makeReport(rows: incomplete)
        XCTAssertFalse(AnalysisAnalysisParityAdjudicationReportValidator.validate(report))
    }
}

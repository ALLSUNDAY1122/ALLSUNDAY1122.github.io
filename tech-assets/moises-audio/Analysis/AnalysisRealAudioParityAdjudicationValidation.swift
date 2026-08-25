import Foundation

public enum AnalysisAnalysisParityAdjudicationReportValidator {
    private static let requiredRows = Set(["MOI-P009", "MOI-P011", "MOI-P013", "MOI-P016"])

    public static func validate(_ report: AnalysisAnalysisParityAdjudicationReport) -> Bool {
        let requiredHashes = [
            report.bindingRootSHA256,
            report.manifestSHA256,
            report.coveragePolicyRootSHA256,
            report.captureSetRootSHA256,
            report.capturePolicyRootSHA256,
            report.reviewSetRootSHA256,
            report.reviewPolicyRootSHA256,
            report.toleranceProfileRootSHA256,
            report.projectReportRootSHA256,
            report.declaredReportRootSHA256
        ]
        guard report.schemaVersion == 1,
              AnalysisPhysicalEvidenceW39BatchLoader.safeComponent(report.bindingID),
              !report.manifestID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              requiredHashes.allSatisfy(AnalysisPhysicalEvidenceW39BatchLoader.isSHA256),
              report.referenceReportRootSHA256.map(AnalysisPhysicalEvidenceW39BatchLoader.isSHA256) ?? true,
              report.differentialReportRootSHA256.map(AnalysisPhysicalEvidenceW39BatchLoader.isSHA256) ?? true,
              report.limitations == AnalysisRealAudioParityAdjudicator.limitations,
              !report.eligibleFixtureIDs.isEmpty,
              report.eligibleFixtureIDs == report.eligibleFixtureIDs.sorted(),
              Set(report.eligibleFixtureIDs).count == report.eligibleFixtureIDs.count,
              report.rowAdjudications.map(\.parityRowID) == report.rowAdjudications.map(\.parityRowID).sorted(),
              Set(report.rowAdjudications.map(\.parityRowID)) == requiredRows,
              report.rowAdjudications.count == requiredRows.count else {
            return false
        }

        for row in report.rowAdjudications {
            guard !row.feature.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !row.domain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !row.expectedFixtureIDs.isEmpty,
                  row.expectedFixtureIDs == row.expectedFixtureIDs.sorted(),
                  Set(row.expectedFixtureIDs).count == row.expectedFixtureIDs.count,
                  !row.requiredMetrics.isEmpty,
                  row.requiredMetrics == row.requiredMetrics.sorted(),
                  Set(row.requiredMetrics).count == row.requiredMetrics.count,
                  row.expectedPairCount == row.expectedFixtureIDs.count * row.requiredMetrics.count,
                  row.observedPairCount >= 0,
                  row.failedPairCount >= 0,
                  row.nonParityCandidatePairCount >= 0,
                  row.failedPairCount <= row.observedPairCount,
                  row.nonParityCandidatePairCount <= row.observedPairCount,
                  row.worstRegression.map { $0.isFinite && $0 >= 0 } ?? true else {
                return false
            }
            switch row.status {
            case .readyForHQRowJudgment:
                guard row.issues.isEmpty,
                      row.observedPairCount == row.expectedPairCount,
                      row.failedPairCount == 0,
                      row.nonParityCandidatePairCount == 0,
                      row.worstRegression != nil,
                      row.worstFixtureID != nil else {
                    return false
                }
            case .notReadyForHQRowJudgment:
                guard !row.issues.isEmpty else { return false }
            }
        }

        switch report.status {
        case .readyForHQJudgment:
            guard report.issues.isEmpty,
                  report.referenceReportRootSHA256 != nil,
                  report.differentialReportRootSHA256 != nil,
                  report.rowAdjudications.allSatisfy({ $0.status == .readyForHQRowJudgment }) else {
                return false
            }
        case .notReadyForHQJudgment:
            // Global gates (rights, roots, current-reference provenance, physical
            // Project binding) can legitimately fail while every feature-level
            // metric pair remains ready. The overall issue inventory is the
            // authoritative reason this report is NOT_READY.
            guard !report.issues.isEmpty else { return false }
        }

        guard let computed = try? AnalysisAnalysisParityAdjudicationRoot.reportSHA256(report),
              computed == report.declaredReportRootSHA256.lowercased() else {
            return false
        }
        return true
    }
}

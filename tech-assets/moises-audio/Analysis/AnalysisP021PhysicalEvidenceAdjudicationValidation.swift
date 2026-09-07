import Foundation

public enum AnalysisP021PhysicalEvidenceAdjudicationReportValidator {
    public static func validate(_ report: AnalysisP021PhysicalEvidenceAdjudicationReport) -> Bool {
        guard report.schemaVersion == 1,
              AnalysisPhysicalEvidenceW39BatchLoader.safeComponent(report.checkpointID),
              report.checkpointSequence > 0,
              AnalysisPhysicalEvidenceW39BatchLoader.isSHA256(report.checkpointCertificateRootSHA256),
              AnalysisPhysicalEvidenceW39BatchLoader.safeComponent(report.anchorID),
              report.anchorSequence > 0,
              AnalysisPhysicalEvidenceW39BatchLoader.isSHA256(report.anchorReceiptRootSHA256),
              AnalysisPhysicalEvidenceW39BatchLoader.safeComponent(report.transferID),
              AnalysisPhysicalEvidenceW39BatchLoader.isSHA256(report.transferRootSHA256),
              AnalysisPhysicalEvidenceW39BatchLoader.safeComponent(report.publicationID),
              AnalysisPhysicalEvidenceW39BatchLoader.safeComponent(report.runtimeBindingID),
              report.plannedRunCount >= 0,
              report.observedRunCount >= 0,
              report.observedRunCount == report.runAdjudications.count,
              AnalysisPhysicalEvidenceW39BatchLoader.isSHA256(report.declaredReportRootSHA256),
              report.limitations == AnalysisP021PhysicalEvidenceAdjudicator.limitations else {
            return false
        }

        let runIDs = report.runAdjudications.map(\.runID)
        let executionIDs = report.runAdjudications.map(\.workloadExecutionID)
        guard Set(runIDs).count == runIDs.count,
              Set(executionIDs).count == executionIDs.count,
              report.runAdjudications.allSatisfy({ run in
                  AnalysisPhysicalEvidenceW39BatchLoader.safeComponent(run.runID)
                      && !run.fixtureID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                      && AnalysisPhysicalEvidenceW39BatchLoader.safeComponent(run.workloadExecutionID)
              }) else {
            return false
        }

        switch report.status {
        case .readyForHQJudgment:
            guard report.issues.isEmpty,
                  report.plannedRunCount > 0,
                  report.observedRunCount == report.plannedRunCount,
                  report.runAdjudications.allSatisfy({
                      $0.performanceStatus == .structurallyCompletePendingHQ
                          && $0.physicalDeviceClaim
                          && $0.boundedPullObserved
                          && $0.peakResidentBytes != nil
                          && $0.peakPhysicalFootprintBytes != nil
                          && $0.worstThermalState != nil
                          && $0.batteryDrainFraction != nil
                          && ($0.runKind == .completeAnalysis || $0.cancellationLatencySeconds != nil)
                          && ($0.runKind == .completeAnalysis
                              ? $0.workloadStatus == .fullWorkloadCompletePendingHQ
                              : $0.workloadStatus == .realWorkCancellationPendingHQ)
                  }) else {
                return false
            }
        case .notReadyForHQJudgment:
            guard !report.issues.isEmpty else { return false }
        }

        guard let computed = try? AnalysisP021AdjudicationReportRoot.compute(report),
              computed == report.declaredReportRootSHA256.lowercased() else {
            return false
        }
        return true
    }
}

import Foundation

public struct AnalysisDevicePerformanceWorkloadGateReport: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let workloadValid: Bool
    public let workloadReports: [AnalysisDeviceWorkloadValidationReport]
    public let performanceAcceptance: AnalysisDevicePerformanceAcceptanceReport?

    public init(schemaVersion: Int = 1, workloadValid: Bool, workloadReports: [AnalysisDeviceWorkloadValidationReport], performanceAcceptance: AnalysisDevicePerformanceAcceptanceReport?) {
        self.schemaVersion = schemaVersion
        self.workloadValid = workloadValid
        self.workloadReports = workloadReports
        self.performanceAcceptance = performanceAcceptance
    }
}

public enum AnalysisDevicePerformanceAcceptanceWithWorkloadEvaluator {
    public static func evaluate(
        batch: AnalysisDevicePerformanceEvidenceBatch,
        receipts: [AnalysisDeviceWorkloadReceipt],
        workloadPolicy: AnalysisDeviceWorkloadPolicy,
        performanceProfile: AnalysisDevicePerformanceAcceptanceProfile,
        evaluatedAt: Date = Date()
    ) -> AnalysisDevicePerformanceWorkloadGateReport {
        let reports = AnalysisDeviceWorkloadReceiptValidator.validateBatch(receipts: receipts, performanceRuns: batch.runs, policy: workloadPolicy)
        let receiptRunIDs = Set(receipts.map(\.runID))
        let performanceRunIDs = Set(batch.runs.map { $0.provenance.runID })
        let exactInventory = receiptRunIDs == performanceRunIDs && receipts.count == batch.runs.count
        let valid = exactInventory && reports.count == receipts.count && reports.allSatisfy { $0.status != .invalid }
        guard valid else {
            return .init(workloadValid: false, workloadReports: reports, performanceAcceptance: nil)
        }
        let acceptance = AnalysisDevicePerformanceAcceptanceEvaluator.evaluate(batch: batch, profile: performanceProfile, evaluatedAt: evaluatedAt)
        return .init(workloadValid: true, workloadReports: reports, performanceAcceptance: acceptance)
    }
}

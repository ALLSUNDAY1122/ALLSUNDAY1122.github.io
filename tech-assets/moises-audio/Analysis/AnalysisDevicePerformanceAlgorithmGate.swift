import Foundation

public struct AnalysisDevicePerformanceAlgorithmGateReport: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let algorithmEvidenceValid: Bool
    public let algorithmEvidence: AnalysisDeviceAlgorithmEvidenceBatchReport
    public let workloadAndPerformance: AnalysisDevicePerformanceWorkloadGateReport?

    public init(schemaVersion: Int = 1, algorithmEvidenceValid: Bool, algorithmEvidence: AnalysisDeviceAlgorithmEvidenceBatchReport, workloadAndPerformance: AnalysisDevicePerformanceWorkloadGateReport?) {
        self.schemaVersion = schemaVersion
        self.algorithmEvidenceValid = algorithmEvidenceValid
        self.algorithmEvidence = algorithmEvidence
        self.workloadAndPerformance = workloadAndPerformance
    }
}

public enum AnalysisDevicePerformanceAcceptanceWithAlgorithmEvaluator {
    public static func evaluate(
        batch: AnalysisDevicePerformanceEvidenceBatch,
        receipts: [AnalysisDeviceWorkloadReceipt],
        workloadPolicy: AnalysisDeviceWorkloadPolicy,
        algorithmBatch: AnalysisDeviceAlgorithmEvidenceBatch,
        performanceProfile: AnalysisDevicePerformanceAcceptanceProfile,
        evaluatedAt: Date = Date()
    ) -> AnalysisDevicePerformanceAlgorithmGateReport {
        let algorithm = AnalysisDeviceAlgorithmEvidenceValidator.validateBatch(
            algorithmBatch: algorithmBatch,
            performanceBatch: batch,
            receipts: receipts,
            workloadPolicy: workloadPolicy,
            performanceProfile: performanceProfile
        )
        guard algorithm.valid else {
            return .init(algorithmEvidenceValid: false, algorithmEvidence: algorithm, workloadAndPerformance: nil)
        }
        let downstream = AnalysisDevicePerformanceAcceptanceWithWorkloadEvaluator.evaluate(
            batch: batch,
            receipts: receipts,
            workloadPolicy: workloadPolicy,
            performanceProfile: performanceProfile,
            evaluatedAt: evaluatedAt
        )
        return .init(algorithmEvidenceValid: true, algorithmEvidence: algorithm, workloadAndPerformance: downstream)
    }
}

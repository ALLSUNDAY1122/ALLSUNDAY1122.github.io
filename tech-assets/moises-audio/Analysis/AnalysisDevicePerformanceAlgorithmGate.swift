import Foundation

public struct AnalysisDevicePerformanceAlgorithmGateReport: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let algorithmEvidenceValid: Bool
    /// W36 gate. Optional only so historical W35 reports remain decodable.
    /// New physical evidence must be true before W25/W24 is evaluated.
    public let currentRuntimeSourceContractValid: Bool?
    public let algorithmEvidence: AnalysisDeviceAlgorithmEvidenceBatchReport
    public let workloadAndPerformance: AnalysisDevicePerformanceWorkloadGateReport?

    public init(
        schemaVersion: Int = 1,
        algorithmEvidenceValid: Bool,
        currentRuntimeSourceContractValid: Bool? = nil,
        algorithmEvidence: AnalysisDeviceAlgorithmEvidenceBatchReport,
        workloadAndPerformance: AnalysisDevicePerformanceWorkloadGateReport?
    ) {
        self.schemaVersion = schemaVersion
        self.algorithmEvidenceValid = algorithmEvidenceValid
        self.currentRuntimeSourceContractValid = currentRuntimeSourceContractValid
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
        let boundedSourceContracts = algorithmBatch.runs.count == performanceProfile.plannedRuns.count
            && algorithmBatch.runs.allSatisfy { $0.sourceInputContract == .boundedPull }
        guard algorithm.valid, boundedSourceContracts else {
            return .init(
                algorithmEvidenceValid: false,
                currentRuntimeSourceContractValid: boundedSourceContracts,
                algorithmEvidence: algorithm,
                workloadAndPerformance: nil
            )
        }
        let downstream = AnalysisDevicePerformanceAcceptanceWithWorkloadEvaluator.evaluate(
            batch: batch,
            receipts: receipts,
            workloadPolicy: workloadPolicy,
            performanceProfile: performanceProfile,
            evaluatedAt: evaluatedAt
        )
        return .init(
            algorithmEvidenceValid: true,
            currentRuntimeSourceContractValid: true,
            algorithmEvidence: algorithm,
            workloadAndPerformance: downstream
        )
    }
}

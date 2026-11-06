import Foundation

public struct AnalysisDeviceCorpusAlgorithmPerformanceGateReport: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let corpusSelection: AnalysisDeviceCorpusSelectionReport
    public let algorithmAndPerformance: AnalysisDevicePerformanceAlgorithmGateReport?

    public init(
        schemaVersion: Int = 1,
        corpusSelection: AnalysisDeviceCorpusSelectionReport,
        algorithmAndPerformance: AnalysisDevicePerformanceAlgorithmGateReport?
    ) {
        self.schemaVersion = schemaVersion
        self.corpusSelection = corpusSelection
        self.algorithmAndPerformance = algorithmAndPerformance
    }
}

/// Canonical post-W35 physical Analysis acceptance entry point.
///
/// The historical `AnalysisDeviceCorpusBoundPerformanceGate` remains available
/// for decoding/replaying pre-W35 evidence, but it does not require runtime
/// algorithm identity and therefore must not be used for new P021 evidence.
public enum AnalysisDeviceCorpusAlgorithmPerformanceGate {
    public static func evaluate(
        manifest: AnalysisRealAudioBenchmarkManifest,
        manifestSHA256: String,
        coveragePolicy: AnalysisCorpusCoveragePolicy,
        selectionPolicy: AnalysisDeviceCorpusSelectionPolicy,
        batch: AnalysisDevicePerformanceEvidenceBatch,
        receipts: [AnalysisDeviceWorkloadReceipt],
        workloadPolicy: AnalysisDeviceWorkloadPolicy,
        algorithmBatch: AnalysisDeviceAlgorithmEvidenceBatch,
        performanceProfile: AnalysisDevicePerformanceAcceptanceProfile,
        evaluatedAt: Date = Date()
    ) -> AnalysisDeviceCorpusAlgorithmPerformanceGateReport {
        let selection = AnalysisDeviceCorpusSelectionEvaluator.evaluate(
            manifest: manifest,
            manifestSHA256: manifestSHA256,
            coveragePolicy: coveragePolicy,
            selectionPolicy: selectionPolicy,
            performanceProfile: performanceProfile,
            workloadPolicy: workloadPolicy,
            evaluatedAt: evaluatedAt
        )
        guard selection.status == .selectionReadyPendingHQ else {
            return .init(corpusSelection: selection, algorithmAndPerformance: nil)
        }
        let downstream = AnalysisDevicePerformanceAcceptanceWithAlgorithmEvaluator.evaluate(
            batch: batch,
            receipts: receipts,
            workloadPolicy: workloadPolicy,
            algorithmBatch: algorithmBatch,
            performanceProfile: performanceProfile,
            evaluatedAt: evaluatedAt
        )
        return .init(corpusSelection: selection, algorithmAndPerformance: downstream)
    }
}

import Foundation

public enum AnalysisDeviceCorpusBoundPerformanceGate {
    public static func evaluate(
        manifest: AnalysisRealAudioBenchmarkManifest,
        manifestSHA256: String,
        coveragePolicy: AnalysisCorpusCoveragePolicy,
        selectionPolicy: AnalysisDeviceCorpusSelectionPolicy,
        batch: AnalysisDevicePerformanceEvidenceBatch,
        receipts: [AnalysisDeviceWorkloadReceipt],
        workloadPolicy: AnalysisDeviceWorkloadPolicy,
        performanceProfile: AnalysisDevicePerformanceAcceptanceProfile,
        evaluatedAt: Date = Date()
    ) -> AnalysisDeviceCorpusBoundPerformanceGateReport {
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
            return .init(corpusSelection: selection, workloadAndPerformance: nil)
        }
        let downstream = AnalysisDevicePerformanceAcceptanceWithWorkloadEvaluator.evaluate(
            batch: batch,
            receipts: receipts,
            workloadPolicy: workloadPolicy,
            performanceProfile: performanceProfile,
            evaluatedAt: evaluatedAt
        )
        return .init(corpusSelection: selection, workloadAndPerformance: downstream)
    }
}

public enum AnalysisDeviceCorpusSelectionCodec {
    public static func encodePolicy(_ value: AnalysisDeviceCorpusSelectionPolicy) throws -> Data { try encoder().encode(value) }
    public static func decodePolicy(_ data: Data) throws -> AnalysisDeviceCorpusSelectionPolicy { try decoder().decode(AnalysisDeviceCorpusSelectionPolicy.self, from: data) }
    public static func encodeReport(_ value: AnalysisDeviceCorpusSelectionReport) throws -> Data { try encoder().encode(value) }
    public static func decodeReport(_ data: Data) throws -> AnalysisDeviceCorpusSelectionReport { try decoder().decode(AnalysisDeviceCorpusSelectionReport.self, from: data) }
    public static func encodeGateReport(_ value: AnalysisDeviceCorpusBoundPerformanceGateReport) throws -> Data { try encoder().encode(value) }
    public static func decodeGateReport(_ data: Data) throws -> AnalysisDeviceCorpusBoundPerformanceGateReport { try decoder().decode(AnalysisDeviceCorpusBoundPerformanceGateReport.self, from: data) }

    private static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

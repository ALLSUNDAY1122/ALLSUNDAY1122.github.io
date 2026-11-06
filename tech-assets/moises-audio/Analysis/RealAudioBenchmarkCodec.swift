import Foundation

public enum AnalysisRealAudioBenchmarkCodec {
    public static func decodeManifest(_ data: Data) throws -> AnalysisRealAudioBenchmarkManifest {
        let decoder = makeDecoder()
        return try decoder.decode(AnalysisRealAudioBenchmarkManifest.self, from: data)
    }

    public static func encodeManifest(_ manifest: AnalysisRealAudioBenchmarkManifest) throws -> Data {
        let encoder = makeEncoder()
        return try encoder.encode(manifest)
    }

    public static func encodeReport(_ report: AnalysisRealAudioBenchmarkReport) throws -> Data {
        let encoder = makeEncoder()
        return try encoder.encode(report)
    }

    public static func decodeReport(_ data: Data) throws -> AnalysisRealAudioBenchmarkReport {
        let decoder = makeDecoder()
        return try decoder.decode(AnalysisRealAudioBenchmarkReport.self, from: data)
    }

    public static func encodeAuditedReport(_ report: AnalysisAuditedRealAudioBenchmarkReport) throws -> Data {
        let encoder = makeEncoder()
        return try encoder.encode(report)
    }

    public static func decodeAuditedReport(_ data: Data) throws -> AnalysisAuditedRealAudioBenchmarkReport {
        let decoder = makeDecoder()
        return try decoder.decode(AnalysisAuditedRealAudioBenchmarkReport.self, from: data)
    }

    public static func encodeDifferentialToleranceProfile(_ profile: AnalysisDifferentialToleranceProfile) throws -> Data {
        let encoder = makeEncoder()
        return try encoder.encode(profile)
    }

    public static func decodeDifferentialToleranceProfile(_ data: Data) throws -> AnalysisDifferentialToleranceProfile {
        let decoder = makeDecoder()
        return try decoder.decode(AnalysisDifferentialToleranceProfile.self, from: data)
    }

    public static func encodePairedDifferentialReport(_ report: AnalysisPairedDifferentialReport) throws -> Data {
        let encoder = makeEncoder()
        return try encoder.encode(report)
    }

    public static func decodePairedDifferentialReport(_ data: Data) throws -> AnalysisPairedDifferentialReport {
        let decoder = makeDecoder()
        return try decoder.decode(AnalysisPairedDifferentialReport.self, from: data)
    }

    private static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return encoder
    }

    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

import Foundation

public enum AnalysisRealAudioBenchmarkCodec {
    public static func decodeManifest(_ data: Data) throws -> AnalysisRealAudioBenchmarkManifest {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
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
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(AnalysisRealAudioBenchmarkReport.self, from: data)
    }

    private static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return encoder
    }
}

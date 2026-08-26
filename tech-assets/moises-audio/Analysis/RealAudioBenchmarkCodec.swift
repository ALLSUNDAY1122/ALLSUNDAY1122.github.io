import Foundation

public enum AnalysisRealAudioBenchmarkCodec {
    public static func decodeManifest(_ data: Data) throws -> AnalysisRealAudioBenchmarkManifest {
        let decoder = makeDecoder()
        return try decoder.decode(AnalysisRealAudioBenchmarkManifest.self, from: data)
    }

    public static func encodeManifest(_ manifest: AnalysisRealAudioBenchmarkManifest) throws -> Data {
        let encoder = makeEncoder()
        return try encoder.encode(CanonicalManifest(manifest))
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

    // A manifest hash is used as provenance throughout W22/W36/W46/W47. Swift Set
    // iteration order is deliberately unspecified, so directly synthesizing Codable for
    // AnalysisRightsEvidence.permittedUses makes otherwise-identical manifests capable of
    // producing different bytes and therefore different provenance roots. Encode through a
    // wire-compatible surrogate that sorts the set while preserving the existing JSON shape.
    private struct CanonicalManifest: Encodable {
        let schemaVersion: Int
        let manifestID: String
        let createdAt: Date
        let cases: [CanonicalCase]

        init(_ manifest: AnalysisRealAudioBenchmarkManifest) {
            schemaVersion = manifest.schemaVersion
            manifestID = manifest.manifestID
            createdAt = manifest.createdAt
            cases = manifest.cases.map(CanonicalCase.init)
        }
    }

    private struct CanonicalCase: Encodable {
        let fixtureID: String
        let projectID: UUID
        let assetID: UUID
        let relativePath: String
        let genre: String
        let sourceKind: AnalysisBenchmarkSourceKind
        let expectedDurationSeconds: Double
        let rights: CanonicalRights
        let reference: AnalysisReferenceAnnotation

        init(_ item: AnalysisRealAudioBenchmarkCase) {
            fixtureID = item.fixtureID
            projectID = item.projectID
            assetID = item.assetID
            relativePath = item.relativePath
            genre = item.genre
            sourceKind = item.sourceKind
            expectedDurationSeconds = item.expectedDurationSeconds
            rights = CanonicalRights(item.rights)
            reference = item.reference
        }
    }

    private struct CanonicalRights: Encodable {
        let grantID: String
        let rightsClass: AnalysisRightsClass
        let permittedUses: [AnalysisBenchmarkPermittedUse]
        let expiresAt: Date?
        let sourceSHA256: String
        let notes: String?

        init(_ rights: AnalysisRightsEvidence) {
            grantID = rights.grantID
            rightsClass = rights.rightsClass
            permittedUses = rights.permittedUses.sorted { $0.rawValue < $1.rawValue }
            expiresAt = rights.expiresAt
            sourceSHA256 = rights.sourceSHA256
            notes = rights.notes
        }
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

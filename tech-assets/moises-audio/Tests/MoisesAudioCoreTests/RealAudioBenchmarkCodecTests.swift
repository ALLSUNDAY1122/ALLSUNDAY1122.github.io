import Foundation
import XCTest
@testable import MoisesAudioCore

final class RealAudioBenchmarkCodecTests: XCTestCase {
    func testManifestUsesISO8601RoundTrip() throws {
        let createdAt = Date(timeIntervalSince1970: 1_800_000_000)
        let manifest = AnalysisRealAudioBenchmarkManifest(
            manifestID: "codec-test",
            createdAt: createdAt,
            cases: [
                AnalysisRealAudioBenchmarkCase(
                    fixtureID: "fixture",
                    projectID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
                    assetID: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
                    relativePath: "fixtures/a.wav",
                    genre: "test",
                    sourceKind: .syntheticTest,
                    expectedDurationSeconds: 1,
                    rights: AnalysisRightsEvidence(
                        grantID: "test",
                        rightsClass: .projectOwned,
                        permittedUses: [.analysisBenchmark],
                        sourceSHA256: String(repeating: "a", count: 64)
                    ),
                    reference: AnalysisReferenceAnnotation(bpm: 120)
                )
            ]
        )

        let data = try AnalysisRealAudioBenchmarkCodec.encodeManifest(manifest)
        let text = try XCTUnwrap(String(data: data, encoding: .utf8))
        XCTAssertTrue(text.contains("2027-01-15T08:00:00Z") || text.contains("2027-01-15T08:00:00.000Z"))
        XCTAssertEqual(try AnalysisRealAudioBenchmarkCodec.decodeManifest(data), manifest)
    }

    func testAuditedReportUsesStableSortedISO8601RoundTrip() throws {
        let row = AnalysisBenchmarkRow(
            fixtureID: "real-weak",
            rightsClass: .projectOwned,
            genre: "live",
            durationSeconds: 10,
            syntheticOnly: false,
            parityEligible: true,
            engine: "test",
            engineVersion: "w17",
            domain: "tempo",
            metrics: [
                "exact_within_4pct": 0,
                "tempo_rel_error": 0.2,
                "predicted_bpm": 96,
                "w15_snapshot_beat_input_limit": 2_048
            ],
            wallSeconds: 0.1,
            rtf: 0.01,
            peakRSSMB: nil,
            thermal: nil,
            knownLimitations: []
        )
        let report = AnalysisAuditedRealAudioBenchmarkReport(
            manifestID: "audited-codec",
            generatedAt: Date(timeIntervalSince1970: 1_800_000_000),
            engine: "test",
            engineVersion: "w17",
            parityEligible: true,
            rows: [row],
            domainQualitySummaries: AnalysisBenchmarkAggregation.domainSummaries(rows: [row]),
            genreQualitySummaries: AnalysisBenchmarkAggregation.genreSummaries(rows: [row]),
            evaluatorRejectedRows: [],
            nonParityRows: [],
            excludedContextMetricNames: AnalysisBenchmarkAggregation.excludedContextMetricNames(rows: [row]),
            validationIssues: []
        )

        let first = try AnalysisRealAudioBenchmarkCodec.encodeAuditedReport(report)
        let second = try AnalysisRealAudioBenchmarkCodec.encodeAuditedReport(report)
        XCTAssertEqual(first, second)
        let text = try XCTUnwrap(String(data: first, encoding: .utf8))
        XCTAssertTrue(text.contains("2027-01-15T08:00:00Z") || text.contains("2027-01-15T08:00:00.000Z"))
        XCTAssertTrue(text.contains("\"parityEligibleWorst\""))
        XCTAssertTrue(text.contains("\"excludedContextMetricNames\""))
        XCTAssertEqual(try AnalysisRealAudioBenchmarkCodec.decodeAuditedReport(first), report)
    }
}

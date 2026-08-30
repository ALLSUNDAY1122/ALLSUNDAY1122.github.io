import Foundation
import XCTest
@testable import MoisesAudioCore

final class AnalysisBenchmarkAggregationTests: XCTestCase {
    func testContextAndDiagnosticMetricsNeverBecomeQualityMeans() throws {
        let row = makeRow(
            fixtureID: "tempo-001",
            genre: "rock",
            domain: "tempo",
            parityEligible: true,
            metrics: [
                "tempo_rel_error": 0.02,
                "exact_within_4pct": 1,
                "predicted_bpm": 120,
                "confidence": 0.91,
                "w15_snapshot_beat_input_count": 400,
                "w15_snapshot_beat_input_limit": 2_048,
                "w16_product_pipeline": 1
            ]
        )

        let means = AnalysisBenchmarkAggregation.qualityMeanMetrics(rows: [row])
        XCTAssertEqual(try XCTUnwrap(means["tempo_rel_error"]), 0.02, accuracy: 1e-12)
        XCTAssertEqual(try XCTUnwrap(means["exact_within_4pct"]), 1, accuracy: 1e-12)
        XCTAssertEqual(try XCTUnwrap(means["decision_emitted"]), 1, accuracy: 1e-12)
        XCTAssertNil(means["predicted_bpm"])
        XCTAssertNil(means["confidence"])
        XCTAssertNil(means["w15_snapshot_beat_input_count"])
        XCTAssertNil(means["w15_snapshot_beat_input_limit"])
        XCTAssertNil(means["w16_product_pipeline"])

        let excluded = AnalysisBenchmarkAggregation.excludedContextMetricNames(rows: [row])
        XCTAssertTrue(excluded.contains("predicted_bpm"))
        XCTAssertTrue(excluded.contains("w15_snapshot_beat_input_limit"))
    }

    func testDomainAndGenreSummariesExposeWorstFixtureInsteadOfOnlyMean() throws {
        let good = makeRow(
            fixtureID: "rock-good",
            genre: "rock",
            domain: "tempo",
            parityEligible: true,
            metrics: ["tempo_rel_error": 0.01, "exact_within_4pct": 1, "predicted_bpm": 120]
        )
        let bad = makeRow(
            fixtureID: "jazz-bad",
            genre: "jazz",
            domain: "tempo",
            parityEligible: true,
            metrics: ["tempo_rel_error": 0.20, "exact_within_4pct": 0, "predicted_bpm": 96]
        )

        let domain = try XCTUnwrap(AnalysisBenchmarkAggregation.domainSummaries(rows: [good, bad]).first)
        let exact = try XCTUnwrap(domain.metrics.first { $0.metric == "exact_within_4pct" })
        XCTAssertEqual(try XCTUnwrap(exact.mean), 0.5, accuracy: 1e-12)
        XCTAssertEqual(exact.worst?.fixtureID, "jazz-bad")
        XCTAssertEqual(exact.worst?.genre, "jazz")
        XCTAssertEqual(exact.worst?.value, 0)

        let error = try XCTUnwrap(domain.metrics.first { $0.metric == "tempo_rel_error" })
        XCTAssertEqual(error.worst?.fixtureID, "jazz-bad")
        XCTAssertEqual(error.worst?.value, 0.20)

        let genre = AnalysisBenchmarkAggregation.genreSummaries(rows: [good, bad])
        let jazz = try XCTUnwrap(genre.first { $0.domain == "tempo" && $0.genre == "jazz" })
        let jazzExact = try XCTUnwrap(jazz.metrics.first { $0.metric == "exact_within_4pct" })
        XCTAssertEqual(try XCTUnwrap(jazzExact.mean), 0, accuracy: 1e-12)
    }

    func testSyntheticGoodRowCannotInflateParityEligibleQualityMean() throws {
        let realWeak = makeRow(
            fixtureID: "real-weak",
            genre: "live",
            domain: "key",
            parityEligible: true,
            metrics: ["exact_key_accuracy": 0, "tonic_accuracy": 0, "mode_accuracy": 1]
        )
        let syntheticPerfect = makeRow(
            fixtureID: "synthetic-perfect",
            genre: "synthetic",
            domain: "key",
            parityEligible: false,
            metrics: ["exact_key_accuracy": 1, "tonic_accuracy": 1, "mode_accuracy": 1],
            limitations: ["SYNTHETIC_UNIT_ONLY_NOT_PARITY_EVIDENCE"]
        )

        let summary = try XCTUnwrap(AnalysisBenchmarkAggregation.domainSummaries(rows: [realWeak, syntheticPerfect]).first)
        let exact = try XCTUnwrap(summary.metrics.first { $0.metric == "exact_key_accuracy" })
        XCTAssertEqual(try XCTUnwrap(exact.mean), 0.5, accuracy: 1e-12)
        XCTAssertEqual(try XCTUnwrap(exact.parityEligibleMean), 0, accuracy: 1e-12)
        XCTAssertEqual(exact.parityEligibleWorst?.fixtureID, "real-weak")
        XCTAssertEqual(summary.parityEligibleRowCount, 1)
        XCTAssertEqual(summary.nonParityRowCount, 1)
    }

    func testEvaluatorRejectedRowIsListedAndCannotImproveQualityMean() throws {
        let acceptedWeak = makeRow(
            fixtureID: "accepted",
            genre: "rock",
            domain: "beat",
            parityEligible: true,
            metrics: ["beat_f_70ms": 0.2, "evaluator_input_accepted": 1]
        )
        let rejectedPerfect = makeRow(
            fixtureID: "rejected",
            genre: "rock",
            domain: "beat",
            parityEligible: false,
            metrics: ["beat_f_70ms": 1, "evaluator_input_accepted": 0],
            limitations: ["EVALUATOR_BEAT_CARDINALITY_REJECTED_NOT_PARITY_EVIDENCE"]
        )

        let summary = try XCTUnwrap(AnalysisBenchmarkAggregation.domainSummaries(rows: [acceptedWeak, rejectedPerfect]).first)
        let beat = try XCTUnwrap(summary.metrics.first { $0.metric == "beat_f_70ms" })
        XCTAssertEqual(try XCTUnwrap(beat.mean), 0.2, accuracy: 1e-12)
        XCTAssertEqual(summary.rowCount, 2)
        XCTAssertEqual(summary.acceptedRowCount, 1)
        XCTAssertEqual(summary.evaluatorRejectedRowCount, 1)

        let rejected = AnalysisBenchmarkAggregation.evaluatorRejectedRows(rows: [acceptedWeak, rejectedPerfect])
        XCTAssertEqual(rejected.count, 1)
        XCTAssertEqual(rejected[0].fixtureID, "rejected")
        XCTAssertTrue(rejected[0].knownLimitations.contains("EVALUATOR_BEAT_CARDINALITY_REJECTED_NOT_PARITY_EVIDENCE"))
    }

    func testDecisionRatePopulationIsCompleteForSuccessAndUnknown() throws {
        let success = makeRow(
            fixtureID: "tempo-success",
            genre: "pop",
            domain: "tempo",
            parityEligible: true,
            metrics: ["predicted_bpm": 120, "tempo_rel_error": 0.01]
        )
        let unknown = makeRow(
            fixtureID: "tempo-unknown",
            genre: "live",
            domain: "tempo",
            parityEligible: true,
            metrics: ["decision_emitted": 0]
        )

        let summary = try XCTUnwrap(AnalysisBenchmarkAggregation.domainSummaries(rows: [success, unknown]).first)
        let decision = try XCTUnwrap(summary.metrics.first { $0.metric == "decision_emitted" })
        XCTAssertEqual(decision.sampleCount, 2)
        XCTAssertTrue(decision.populationComplete)
        XCTAssertTrue(decision.parityEligiblePopulationComplete)
        XCTAssertEqual(try XCTUnwrap(decision.mean), 0.5, accuracy: 1e-12)
        XCTAssertEqual(decision.worst?.fixtureID, "tempo-unknown")

        let error = try XCTUnwrap(summary.metrics.first { $0.metric == "tempo_rel_error" })
        XCTAssertEqual(error.sampleCount, 1)
        XCTAssertFalse(error.populationComplete)
    }

    func testAuditedProductRunnerProducesAntiMaskingReportAndSyntheticRemainsNonParity() async throws {
        let signal = makeAggregationSignal(duration: 8)
        let sha = String(repeating: "a", count: 64)
        let item = AnalysisRealAudioBenchmarkCase(
            fixtureID: "w17-audited-synthetic",
            projectID: UUID(),
            assetID: UUID(),
            relativePath: "bench/w17.wav",
            genre: "synthetic-regression",
            sourceKind: .syntheticTest,
            expectedDurationSeconds: signal.durationSeconds,
            rights: AnalysisRightsEvidence(
                grantID: "w17-test-grant",
                rightsClass: .projectOwned,
                permittedUses: [.analysisBenchmark],
                sourceSHA256: sha
            ),
            reference: AnalysisReferenceAnnotation(
                bpm: 120,
                beatTimesSeconds: stride(from: 0.0, to: 8.0, by: 0.5).map { $0 }
            )
        )
        let report = try await AnalysisRealAudioBenchmarkRunner.runProductAlignedAudited(
            manifest: AnalysisRealAudioBenchmarkManifest(
                manifestID: "w17-audited",
                createdAt: Date(timeIntervalSince1970: 1),
                cases: [item]
            ),
            loader: AggregationMemoryLoader(signal: signal, sha: sha),
            runDate: Date(timeIntervalSince1970: 2)
        )

        XCTAssertFalse(report.parityEligible)
        XCTAssertFalse(report.rows.isEmpty)
        XCTAssertFalse(report.domainQualitySummaries.isEmpty)
        XCTAssertFalse(report.genreQualitySummaries.isEmpty)
        XCTAssertTrue(report.nonParityRows.allSatisfy { $0.fixtureID == item.fixtureID })
        XCTAssertTrue(report.excludedContextMetricNames.contains("w15_snapshot_chord_input_limit"))
        XCTAssertFalse(report.domainQualitySummaries.flatMap(\.metrics).contains { $0.metric.hasPrefix("w15_") })

        let data = try JSONEncoder().encode(report)
        XCTAssertEqual(try JSONDecoder().decode(AnalysisAuditedRealAudioBenchmarkReport.self, from: data), report)
    }
}

private func makeRow(
    fixtureID: String,
    genre: String,
    domain: String,
    parityEligible: Bool,
    metrics: [String: Double],
    limitations: [String] = []
) -> AnalysisBenchmarkRow {
    AnalysisBenchmarkRow(
        fixtureID: fixtureID,
        rightsClass: .projectOwned,
        genre: genre,
        durationSeconds: 10,
        syntheticOnly: !parityEligible,
        parityEligible: parityEligible,
        engine: "test",
        engineVersion: "w17",
        domain: domain,
        metrics: metrics,
        wallSeconds: 0.1,
        rtf: 0.01,
        peakRSSMB: nil,
        thermal: nil,
        knownLimitations: limitations
    )
}

private struct AggregationMemoryLoader: AnalysisBenchmarkSignalLoading {
    let signal: AnalysisSignal
    let sha: String
    func loadBenchmarkSignal(projectID: ProjectID, asset: LocalAudioAsset) async throws -> AnalysisBenchmarkLoadedSignal {
        AnalysisBenchmarkLoadedSignal(signal: signal, sourceSHA256: sha)
    }
}

private func makeAggregationSignal(duration: Double) -> AnalysisSignal {
    let sampleRate = 8_000.0
    let count = Int(sampleRate * duration)
    var samples = Array(repeating: Float(0), count: count)
    for index in samples.indices {
        let time = Double(index) / sampleRate
        var value = 0.12 * sin(2 * Double.pi * 261.6256 * time)
            + 0.10 * sin(2 * Double.pi * 329.6276 * time)
            + 0.08 * sin(2 * Double.pi * 391.9954 * time)
        let phase = time.truncatingRemainder(dividingBy: 0.5)
        if phase < 0.015 { value += 0.65 * (1 - phase / 0.015) }
        samples[index] = Float(max(-1, min(1, value)))
    }
    return AnalysisSignal(sampleRate: sampleRate, monoSamples: samples)
}

import Foundation
import XCTest
@testable import MoisesAudioCore

final class AnalysisBenchmarkDifferentialTests: XCTestCase {
    func testHigherIsBetterPairWithinSuppliedToleranceRemainsPendingHQ() throws {
        let project = audited(engine: "project-owned-dsp", rows: [
            row(fixture: "a", domain: "beat", genre: "rock", metrics: ["beat_f_70ms": 0.90])
        ])
        let reference = audited(engine: "moises-current-iphone", rows: [
            row(fixture: "a", domain: "beat", genre: "rock", metrics: ["beat_f_70ms": 0.94])
        ])
        let report = AnalysisPairedDifferentialComparator.compare(
            project: project,
            reference: reference,
            profile: profile(rules: [.init(domain: "beat", metric: "beat_f_70ms", maximumRegression: 0.05)]),
            generatedAt: epoch(3)
        )

        XCTAssertEqual(report.status, .withinSuppliedTolerancePendingHQ)
        XCTAssertTrue(report.comparisonComplete)
        XCTAssertTrue(report.allPairedEvidenceParityCandidate)
        XCTAssertTrue(report.allWithinSuppliedTolerance)
        let pair = try XCTUnwrap(report.pairs.first)
        XCTAssertEqual(pair.direction, .higherIsBetter)
        XCTAssertEqual(pair.signedQualityDelta, -0.04, accuracy: 1e-12)
        XCTAssertEqual(pair.regression, 0.04, accuracy: 1e-12)
        XCTAssertEqual(pair.withinTolerance, true)
        XCTAssertEqual(report.finalParityAuthority, "HQ_LATE_INTEGRATION")
    }

    func testLowerIsBetterDirectionUsesReferenceMinusProject() throws {
        let project = audited(engine: "project-owned-dsp", rows: [
            row(fixture: "a", domain: "beat", genre: "live", metrics: ["median_abs_error_seconds": 0.08])
        ])
        let reference = audited(engine: "moises-current-iphone", rows: [
            row(fixture: "a", domain: "beat", genre: "live", metrics: ["median_abs_error_seconds": 0.05])
        ])
        let report = AnalysisPairedDifferentialComparator.compare(
            project: project,
            reference: reference,
            profile: profile(rules: [.init(domain: "beat", metric: "median_abs_error_seconds", maximumRegression: 0.04)])
        )

        let pair = try XCTUnwrap(report.pairs.first)
        XCTAssertEqual(pair.direction, .lowerIsBetter)
        XCTAssertEqual(pair.signedQualityDelta, -0.03, accuracy: 1e-12)
        XCTAssertEqual(pair.regression, 0.03, accuracy: 1e-12)
        XCTAssertEqual(report.status, .withinSuppliedTolerancePendingHQ)
    }

    func testOutsideToleranceExposesWorstRegressionFixture() throws {
        let project = audited(engine: "project-owned-dsp", rows: [
            row(fixture: "good", domain: "beat", genre: "studio", metrics: ["beat_f_70ms": 0.96]),
            row(fixture: "bad", domain: "beat", genre: "live", metrics: ["beat_f_70ms": 0.60])
        ])
        let reference = audited(engine: "moises-current-iphone", rows: [
            row(fixture: "good", domain: "beat", genre: "studio", metrics: ["beat_f_70ms": 0.95]),
            row(fixture: "bad", domain: "beat", genre: "live", metrics: ["beat_f_70ms": 0.90])
        ])
        let report = AnalysisPairedDifferentialComparator.compare(
            project: project,
            reference: reference,
            profile: profile(rules: [.init(domain: "beat", metric: "beat_f_70ms", maximumRegression: 0.05)])
        )

        XCTAssertEqual(report.status, .outsideSuppliedTolerance)
        XCTAssertFalse(report.allWithinSuppliedTolerance)
        let summary = try XCTUnwrap(report.metricSummaries.first)
        XCTAssertEqual(summary.failedPairCount, 1)
        XCTAssertEqual(summary.worstRegression?.fixtureID, "bad")
        XCTAssertEqual(summary.worstRegression?.regression ?? -1, 0.30, accuracy: 1e-12)
    }

    func testCherryPickedMissingRowFailsPairing() {
        let project = audited(engine: "project-owned-dsp", rows: [
            row(fixture: "good", domain: "beat", genre: "studio", metrics: ["beat_f_70ms": 1])
        ])
        let reference = audited(engine: "moises-current-iphone", rows: [
            row(fixture: "good", domain: "beat", genre: "studio", metrics: ["beat_f_70ms": 1]),
            row(fixture: "missing-from-project", domain: "beat", genre: "live", metrics: ["beat_f_70ms": 0.4])
        ])
        let report = AnalysisPairedDifferentialComparator.compare(
            project: project,
            reference: reference,
            profile: profile(rules: [.init(domain: "beat", metric: "beat_f_70ms", maximumRegression: 0.05)])
        )

        XCTAssertEqual(report.status, .incompletePairing)
        XCTAssertFalse(report.sameCorpusComplete)
        XCTAssertTrue(report.issues.contains { $0.code == .referenceOnlyRow && $0.fixtureID == "missing-from-project" })
    }

    func testMetricMissingOnOneSideFailsPairing() {
        let project = audited(engine: "project-owned-dsp", rows: [
            row(fixture: "a", domain: "beat", genre: "rock", metrics: ["beat_f_70ms": 0.9])
        ])
        let reference = audited(engine: "moises-current-iphone", rows: [
            row(fixture: "a", domain: "beat", genre: "rock", metrics: [:])
        ])
        let report = AnalysisPairedDifferentialComparator.compare(
            project: project,
            reference: reference,
            profile: profile(rules: [.init(domain: "beat", metric: "beat_f_70ms", maximumRegression: 0.1)])
        )

        XCTAssertEqual(report.status, .incompletePairing)
        XCTAssertFalse(report.metricPairingComplete)
        XCTAssertTrue(report.issues.contains { $0.code == .projectOnlyMetric && $0.metric == "beat_f_70ms" })
    }

    func testOmittingUnfavorableToleranceRuleFailsClosed() {
        let project = audited(engine: "project-owned-dsp", rows: [
            row(fixture: "a", domain: "beat", genre: "rock", metrics: [
                "beat_f_70ms": 0.95,
                "median_abs_error_seconds": 0.20
            ])
        ])
        let reference = audited(engine: "moises-current-iphone", rows: [
            row(fixture: "a", domain: "beat", genre: "rock", metrics: [
                "beat_f_70ms": 0.95,
                "median_abs_error_seconds": 0.05
            ])
        ])
        let report = AnalysisPairedDifferentialComparator.compare(
            project: project,
            reference: reference,
            profile: profile(rules: [.init(domain: "beat", metric: "beat_f_70ms", maximumRegression: 0.01)])
        )

        XCTAssertEqual(report.status, .incompletePairing)
        XCTAssertTrue(report.issues.contains { $0.code == .missingToleranceRule && $0.metric == "median_abs_error_seconds" })
    }

    func testRequiredProfileMetricAbsentFailsClosed() {
        let project = audited(engine: "project-owned-dsp", rows: [
            row(fixture: "a", domain: "beat", genre: "rock", metrics: ["beat_f_70ms": 0.9])
        ])
        let reference = audited(engine: "moises-current-iphone", rows: [
            row(fixture: "a", domain: "beat", genre: "rock", metrics: ["beat_f_70ms": 0.9])
        ])
        let report = AnalysisPairedDifferentialComparator.compare(
            project: project,
            reference: reference,
            profile: profile(rules: [
                .init(domain: "beat", metric: "beat_f_70ms", maximumRegression: 0.1),
                .init(domain: "key", metric: "weighted_key_score", maximumRegression: 0.1, required: true)
            ])
        )

        XCTAssertEqual(report.status, .incompletePairing)
        XCTAssertTrue(report.issues.contains { $0.code == .requiredMetricAbsent && $0.domain == "key" })
    }

    func testSyntheticWithinToleranceNeverBecomesParityCandidate() {
        let project = audited(engine: "project-owned-dsp", parityEligible: false, rows: [
            row(fixture: "synthetic", domain: "beat", genre: "synthetic", synthetic: true, parityEligible: false, metrics: ["beat_f_70ms": 1])
        ])
        let reference = audited(engine: "moises-current-iphone", parityEligible: false, rows: [
            row(fixture: "synthetic", domain: "beat", genre: "synthetic", synthetic: true, parityEligible: false, metrics: ["beat_f_70ms": 1])
        ])
        let report = AnalysisPairedDifferentialComparator.compare(
            project: project,
            reference: reference,
            profile: profile(rules: [.init(domain: "beat", metric: "beat_f_70ms", maximumRegression: 0)])
        )

        XCTAssertEqual(report.status, .withinToleranceNonParityEvidence)
        XCTAssertTrue(report.comparisonComplete)
        XCTAssertTrue(report.allWithinSuppliedTolerance)
        XCTAssertFalse(report.allPairedEvidenceParityCandidate)
        XCTAssertFalse(report.pairs[0].parityCandidateEvidence)
    }

    func testInvalidAuthorityAndEngineSwapFailProfileGate() {
        let project = audited(engine: "project-owned-dsp", rows: [
            row(fixture: "a", domain: "beat", genre: "rock", metrics: ["beat_f_70ms": 1])
        ])
        let reference = audited(engine: "moises-current-iphone", rows: [
            row(fixture: "a", domain: "beat", genre: "rock", metrics: ["beat_f_70ms": 1])
        ])
        let badProfile = AnalysisDifferentialToleranceProfile(
            profileID: "bad",
            authority: "WORKER_SELF_APPROVED",
            approvalReference: "self",
            approvedAt: epoch(1),
            expectedProjectEngine: "moises-current-iphone",
            expectedReferenceEngine: "project-owned-dsp",
            rules: [.init(domain: "beat", metric: "beat_f_70ms", maximumRegression: 1)]
        )
        let report = AnalysisPairedDifferentialComparator.compare(project: project, reference: reference, profile: badProfile)

        XCTAssertEqual(report.status, .invalidProfile)
        XCTAssertTrue(report.issues.contains { $0.code == .invalidProfile })
        XCTAssertTrue(report.issues.contains { $0.code == .engineMismatch })
    }

    func testDuplicateRowsAndMetadataMismatchCannotBePairedAmbiguously() {
        let duplicated = row(fixture: "a", domain: "beat", genre: "rock", metrics: ["beat_f_70ms": 1])
        let project = audited(engine: "project-owned-dsp", rows: [duplicated, duplicated])
        let reference = audited(engine: "moises-current-iphone", rows: [
            row(fixture: "a", domain: "beat", genre: "jazz", metrics: ["beat_f_70ms": 1])
        ])
        let report = AnalysisPairedDifferentialComparator.compare(
            project: project,
            reference: reference,
            profile: profile(rules: [.init(domain: "beat", metric: "beat_f_70ms", maximumRegression: 0)])
        )

        XCTAssertEqual(report.status, .incompletePairing)
        XCTAssertTrue(report.issues.contains { $0.code == .duplicateProjectRow })
        XCTAssertTrue(report.issues.contains { $0.code == .rowMetadataMismatch })
    }

    func testToleranceProfileAndDifferentialReportCodecRoundTrip() throws {
        let tolerance = profile(rules: [.init(domain: "beat", metric: "beat_f_70ms", maximumRegression: 0.05)])
        let profileData = try AnalysisRealAudioBenchmarkCodec.encodeDifferentialToleranceProfile(tolerance)
        XCTAssertEqual(try AnalysisRealAudioBenchmarkCodec.decodeDifferentialToleranceProfile(profileData), tolerance)

        let project = audited(engine: "project-owned-dsp", rows: [
            row(fixture: "a", domain: "beat", genre: "rock", metrics: ["beat_f_70ms": 0.95])
        ])
        let reference = audited(engine: "moises-current-iphone", rows: [
            row(fixture: "a", domain: "beat", genre: "rock", metrics: ["beat_f_70ms": 0.96])
        ])
        let report = AnalysisPairedDifferentialComparator.compare(
            project: project,
            reference: reference,
            profile: tolerance,
            generatedAt: epoch(9)
        )
        let data = try AnalysisRealAudioBenchmarkCodec.encodePairedDifferentialReport(report)
        XCTAssertEqual(try AnalysisRealAudioBenchmarkCodec.decodePairedDifferentialReport(data), report)
    }
}

private func profile(rules: [AnalysisDifferentialToleranceRule]) -> AnalysisDifferentialToleranceProfile {
    AnalysisDifferentialToleranceProfile(
        profileID: "hq-test-profile",
        authority: "HQ_LATE_INTEGRATION",
        approvalReference: "TEST_ONLY_NOT_PRODUCTION_APPROVAL",
        approvedAt: epoch(1),
        expectedProjectEngine: "project-owned-dsp",
        expectedReferenceEngine: "moises-current-iphone",
        rules: rules
    )
}

private func audited(
    engine: String,
    parityEligible: Bool = true,
    manifestID: String = "same-corpus",
    rows: [AnalysisBenchmarkRow]
) -> AnalysisAuditedRealAudioBenchmarkReport {
    AnalysisAuditedRealAudioBenchmarkReport(
        manifestID: manifestID,
        generatedAt: epoch(2),
        engine: engine,
        engineVersion: engine + "-test",
        parityEligible: parityEligible,
        rows: rows,
        domainQualitySummaries: AnalysisBenchmarkAggregation.domainSummaries(rows: rows),
        genreQualitySummaries: AnalysisBenchmarkAggregation.genreSummaries(rows: rows),
        evaluatorRejectedRows: AnalysisBenchmarkAggregation.evaluatorRejectedRows(rows: rows),
        nonParityRows: AnalysisBenchmarkAggregation.nonParityRows(rows: rows),
        excludedContextMetricNames: AnalysisBenchmarkAggregation.excludedContextMetricNames(rows: rows),
        validationIssues: []
    )
}

private func row(
    fixture: String,
    domain: String,
    genre: String,
    duration: Double = 30,
    synthetic: Bool = false,
    parityEligible: Bool = true,
    metrics: [String: Double]
) -> AnalysisBenchmarkRow {
    AnalysisBenchmarkRow(
        fixtureID: fixture,
        rightsClass: .projectOwned,
        genre: genre,
        durationSeconds: duration,
        syntheticOnly: synthetic,
        parityEligible: parityEligible,
        engine: "row-engine",
        engineVersion: "test",
        domain: domain,
        metrics: metrics,
        wallSeconds: 0.1,
        rtf: 0.01,
        peakRSSMB: nil,
        thermal: nil,
        knownLimitations: []
    )
}

private func epoch(_ seconds: TimeInterval) -> Date {
    Date(timeIntervalSince1970: seconds)
}

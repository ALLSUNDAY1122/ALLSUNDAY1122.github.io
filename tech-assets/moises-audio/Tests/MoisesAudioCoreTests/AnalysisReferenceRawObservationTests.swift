import Foundation
import XCTest
@testable import MoisesAudioCore

final class AnalysisReferenceRawObservationTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_787_527_400)
    private let manifestSHA = String(repeating: "a", count: 64)
    private let artifactSHA = String(repeating: "b", count: 64)

    private func manifest() -> AnalysisRealAudioBenchmarkManifest {
        let chords = [
            ChordEvent(startSeconds: 0, endSeconds: 5, normalizedLabel: "C:maj", confidence: nil),
            ChordEvent(startSeconds: 5, endSeconds: 10, normalizedLabel: "F:maj", confidence: nil)
        ]
        let sections = [
            SongSection(startSeconds: 0, endSeconds: 5, structuralLabel: "A", functionalLabel: "verse", confidence: nil),
            SongSection(startSeconds: 5, endSeconds: 10, structuralLabel: "B", functionalLabel: "chorus", confidence: nil)
        ]
        let item = AnalysisRealAudioBenchmarkCase(
            fixtureID: "fixture-1",
            projectID: UUID(),
            assetID: UUID(),
            relativePath: "fixtures/reference.wav",
            genre: "rock",
            sourceKind: .realAudio,
            expectedDurationSeconds: 10,
            rights: .init(grantID: "grant-1", rightsClass: .licensedTest, permittedUses: [.analysisBenchmark, .differentialReference], sourceSHA256: String(repeating: "c", count: 64)),
            reference: .init(
                bpm: 120,
                beatTimesSeconds: stride(from: 0.0, to: 10.0, by: 0.5).map { $0 },
                key: MusicalKey(tonicPitchClass: 0, mode: "major", confidence: nil),
                chords: chords,
                sections: sections
            )
        )
        return .init(manifestID: "golden-v1", createdAt: now, cases: [item])
    }

    private func environment() -> AnalysisReferenceCaptureEnvironment {
        .init(productName: "Moises: The Musician's App", appVersion: "9.9.9", buildVersion: "999", deviceModel: "iPhone16,1", osVersion: "19.0", locale: "ja_JP", accountTier: "PREMIUM")
    }

    private func artifact() -> AnalysisReferenceCaptureArtifact {
        .init(artifactID: "evidence", sha256: artifactSHA, mediaType: "video/mp4")
    }

    private func sourceBinding() -> AnalysisReferenceCaptureSourceBinding {
        .init(manifestID: "golden-v1", manifestSHA256: manifestSHA)
    }

    private func tempoMetrics(_ bpm: Double) -> [String: Double] {
        let error = abs(bpm - 120) / 120
        let ratios = [bpm / 120, bpm / 60, bpm / 240]
        return [
            "decision_emitted": 1,
            "tempo_rel_error": error,
            "exact_within_4pct": error <= 0.04 ? 1 : 0,
            "octave_aware_within_4pct": ratios.contains { abs($0 - 1) <= 0.04 } ? 1 : 0
        ]
    }

    private func captureRun(id: String = "run-1", domain: String = "tempo", metrics: [String: Double]? = nil) -> AnalysisReferenceCaptureRun {
        .init(
            runID: id,
            operatorID: "operator-1",
            capturedAt: now,
            environment: environment(),
            sourceBinding: sourceBinding(),
            observationMethod: .screenRecordingReview,
            artifacts: [artifact()],
            rows: [.init(fixtureID: "fixture-1", rightsClass: .licensedTest, genre: "rock", durationSeconds: 10, syntheticOnly: false, domain: domain, qualityMetrics: metrics ?? tempoMetrics(120), evidenceArtifactIDs: ["evidence"])]
        )
    }

    private func captureSet(runs: [AnalysisReferenceCaptureRun]) -> AnalysisReferenceCaptureSet {
        .init(captureSetID: "capture-1", createdAt: now, runs: runs)
    }

    private func rawSet(_ observations: [AnalysisReferenceRawObservation]) -> AnalysisReferenceRawObservationSet {
        .init(rawSetID: "raw-1", captureSetID: "capture-1", sourceManifestID: "golden-v1", sourceManifestSHA256: manifestSHA, observations: observations)
    }

    private func policy(rules: [AnalysisReferenceRepeatabilityRule]) -> AnalysisReferenceCapturePolicy {
        .init(
            policyID: "policy-1",
            authority: "HQ_LATE_INTEGRATION",
            approvalReference: "HQ-approval-1",
            referenceEpochNotBefore: now.addingTimeInterval(-60),
            expectedProductName: "Moises: The Musician's App",
            expectedAppVersion: "9.9.9",
            expectedBuildVersion: "999",
            expectedDeviceModel: "iPhone16,1",
            expectedOSVersion: "19.0",
            expectedLocale: "ja_JP",
            expectedAccountTier: "PREMIUM",
            expectedSourceManifestID: "golden-v1",
            expectedSourceManifestSHA256: manifestSHA,
            minimumRepeatRuns: 2,
            repeatabilityRules: rules
        )
    }

    func testTempoRawObservationRecomputesCanonicalMetrics() {
        let capture = captureSet(runs: [captureRun()])
        let raw = rawSet([.init(runID: "run-1", fixtureID: "fixture-1", domain: "tempo", status: .observed, evidenceArtifactIDs: ["evidence"], observedBPM: 120)])
        let result = AnalysisReferenceRawObservationDeriver.derive(rawSet: raw, captureSet: capture, policy: policy(rules: []), manifest: manifest(), manifestSHA256: manifestSHA, evaluatedAt: now)
        XCTAssertTrue(result.derivationReady)
        XCTAssertEqual(result.diagnostics.first?.derivedMetrics, tempoMetrics(120))
        XCTAssertTrue(result.diagnostics.first?.metricsIdentityMatched == true)
    }

    func testWrongDeclaredMetricIsRejectedEvenWhenRepeatedRawObservationIsValid() {
        var wrong = tempoMetrics(120)
        wrong["tempo_rel_error"] = 0.25
        let capture = captureSet(runs: [captureRun(metrics: wrong)])
        let raw = rawSet([.init(runID: "run-1", fixtureID: "fixture-1", domain: "tempo", status: .observed, evidenceArtifactIDs: ["evidence"], observedBPM: 120)])
        let result = AnalysisReferenceRawObservationDeriver.derive(rawSet: raw, captureSet: capture, policy: policy(rules: []), manifest: manifest(), manifestSHA256: manifestSHA, evaluatedAt: now)
        XCTAssertFalse(result.derivationReady)
        XCTAssertTrue(result.issues.contains { $0.code == .derivedMetricValueMismatch && $0.metric == "tempo_rel_error" })
    }

    func testMetricSetOmissionCannotHideDecisionRate() {
        var incomplete = tempoMetrics(120)
        incomplete.removeValue(forKey: "decision_emitted")
        let result = AnalysisReferenceRawObservationDeriver.derive(
            rawSet: rawSet([.init(runID: "run-1", fixtureID: "fixture-1", domain: "tempo", status: .observed, evidenceArtifactIDs: ["evidence"], observedBPM: 120)]),
            captureSet: captureSet(runs: [captureRun(metrics: incomplete)]),
            policy: policy(rules: []), manifest: manifest(), manifestSHA256: manifestSHA, evaluatedAt: now
        )
        XCTAssertTrue(result.issues.contains { $0.code == .derivedMetricSetMismatch })
    }

    func testNoDecisionTempoDerivesDecisionEmittedZero() {
        let metrics = ["decision_emitted": 0.0]
        let result = AnalysisReferenceRawObservationDeriver.derive(
            rawSet: rawSet([.init(runID: "run-1", fixtureID: "fixture-1", domain: "tempo", status: .noDecision, evidenceArtifactIDs: ["evidence"])]),
            captureSet: captureSet(runs: [captureRun(metrics: metrics)]),
            policy: policy(rules: []), manifest: manifest(), manifestSHA256: manifestSHA, evaluatedAt: now
        )
        XCTAssertTrue(result.derivationReady)
        XCTAssertEqual(result.diagnostics.first?.derivedMetrics["decision_emitted"], 0)
    }

    func testUnsupportedAndUnscorableNeverBecomeZeroScores() {
        for status in [AnalysisReferenceRawObservationStatus.unsupported, .unscorable] {
            let result = AnalysisReferenceRawObservationDeriver.derive(
                rawSet: rawSet([.init(runID: "run-1", fixtureID: "fixture-1", domain: "tempo", status: status, evidenceArtifactIDs: ["evidence"], limitations: ["CURRENT_MOISES_UI_NOT_OBSERVABLE"])]),
                captureSet: captureSet(runs: [captureRun()]), policy: policy(rules: []), manifest: manifest(), manifestSHA256: manifestSHA, evaluatedAt: now
            )
            XCTAssertFalse(result.derivationReady)
            XCTAssertTrue(result.issues.contains { $0.code == (status == .unsupported ? .unsupportedObservation : .unscorableObservation) })
        }
    }

    func testMissingAndUnexpectedRawRowsFailClosed() {
        let missing = AnalysisReferenceRawObservationDeriver.derive(rawSet: rawSet([]), captureSet: captureSet(runs: [captureRun()]), policy: policy(rules: []), manifest: manifest(), manifestSHA256: manifestSHA, evaluatedAt: now)
        XCTAssertTrue(missing.issues.contains { $0.code == .invalidRawSet })
        XCTAssertTrue(missing.issues.contains { $0.code == .missingRawObservation })

        let extra = rawSet([
            .init(runID: "run-1", fixtureID: "fixture-1", domain: "tempo", status: .observed, evidenceArtifactIDs: ["evidence"], observedBPM: 120),
            .init(runID: "run-1", fixtureID: "fixture-1", domain: "key", status: .observed, evidenceArtifactIDs: ["evidence"], key: .init(tonicPitchClass: 0, mode: "major"))
        ])
        let result = AnalysisReferenceRawObservationDeriver.derive(rawSet: extra, captureSet: captureSet(runs: [captureRun()]), policy: policy(rules: []), manifest: manifest(), manifestSHA256: manifestSHA, evaluatedAt: now)
        XCTAssertTrue(result.issues.contains { $0.code == .unexpectedRawObservation })
    }

    func testArtifactAndManifestBindingAreEnforced() {
        let raw = rawSet([.init(runID: "run-1", fixtureID: "fixture-1", domain: "tempo", status: .observed, evidenceArtifactIDs: ["other"], observedBPM: 120)])
        let result = AnalysisReferenceRawObservationDeriver.derive(rawSet: raw, captureSet: captureSet(runs: [captureRun()]), policy: policy(rules: []), manifest: manifest(), manifestSHA256: String(repeating: "d", count: 64), evaluatedAt: now)
        XCTAssertTrue(result.issues.contains { $0.code == .sourceBindingMismatch })
        XCTAssertTrue(result.issues.contains { $0.code == .missingEvidenceArtifact })
    }

    func testObservedPayloadMustMatchDomainExactly() {
        let raw = rawSet([.init(runID: "run-1", fixtureID: "fixture-1", domain: "tempo", status: .observed, evidenceArtifactIDs: ["evidence"], observedBPM: 120, key: .init(tonicPitchClass: 0, mode: "major"))])
        let result = AnalysisReferenceRawObservationDeriver.derive(rawSet: raw, captureSet: captureSet(runs: [captureRun()]), policy: policy(rules: []), manifest: manifest(), manifestSHA256: manifestSHA, evaluatedAt: now)
        XCTAssertTrue(result.issues.contains { $0.code == .rawPayloadMismatch })
    }

    func testBeatRawTimelineIsScoredByCanonicalMatcher() {
        let beats = stride(from: 0.0, to: 10.0, by: 0.5).map { $0 }
        let metrics = ["beat_f_70ms": 1.0, "median_abs_error_seconds": 0.0]
        let result = AnalysisReferenceRawObservationDeriver.derive(
            rawSet: rawSet([.init(runID: "run-1", fixtureID: "fixture-1", domain: "beat", status: .observed, evidenceArtifactIDs: ["evidence"], beatTimesSeconds: beats)]),
            captureSet: captureSet(runs: [captureRun(domain: "beat", metrics: metrics)]), policy: policy(rules: []), manifest: manifest(), manifestSHA256: manifestSHA, evaluatedAt: now
        )
        XCTAssertTrue(result.derivationReady)
        XCTAssertEqual(result.diagnostics.first?.derivedMetrics["beat_f_70ms"], 1)
        XCTAssertEqual(result.diagnostics.first?.derivedMetrics["median_abs_error_seconds"], 0)
    }

    func testKeyRawObservationIsScoredByCanonicalWeightedKeyMetric() {
        let metrics = ["decision_emitted": 1.0, "exact_key_accuracy": 1.0, "tonic_accuracy": 1.0, "mode_accuracy": 1.0, "weighted_key_score": 1.0]
        let result = AnalysisReferenceRawObservationDeriver.derive(
            rawSet: rawSet([.init(runID: "run-1", fixtureID: "fixture-1", domain: "key", status: .observed, evidenceArtifactIDs: ["evidence"], key: .init(tonicPitchClass: 0, mode: "major"))]),
            captureSet: captureSet(runs: [captureRun(domain: "key", metrics: metrics)]), policy: policy(rules: []), manifest: manifest(), manifestSHA256: manifestSHA, evaluatedAt: now
        )
        XCTAssertTrue(result.derivationReady)
    }

    func testChordOverlapIsRejectedBeforeEvaluatorNormalizationCanHideIt() {
        let raw = rawSet([.init(runID: "run-1", fixtureID: "fixture-1", domain: "chord", status: .observed, evidenceArtifactIDs: ["evidence"], chords: [
            .init(startSeconds: 0, endSeconds: 6, normalizedLabel: "C:maj"),
            .init(startSeconds: 5, endSeconds: 10, normalizedLabel: "F:maj")
        ])])
        let result = AnalysisReferenceRawObservationDeriver.derive(rawSet: raw, captureSet: captureSet(runs: [captureRun(domain: "chord", metrics: ["coverage": 1])]), policy: policy(rules: []), manifest: manifest(), manifestSHA256: manifestSHA, evaluatedAt: now)
        XCTAssertTrue(result.issues.contains { $0.code == .invalidRawValue })
    }

    func testRawCodecRoundTripsDeterministically() throws {
        let raw = rawSet([.init(runID: "run-1", fixtureID: "fixture-1", domain: "tempo", status: .observed, evidenceArtifactIDs: ["evidence"], observedBPM: 120)])
        let first = try AnalysisReferenceRawObservationCodec.encodeRawSet(raw)
        let second = try AnalysisReferenceRawObservationCodec.encodeRawSet(raw)
        XCTAssertEqual(first, second)
        XCTAssertEqual(try AnalysisReferenceRawObservationCodec.decodeRawSet(first), raw)
    }

    func testTwoRunRawDerivedTempoCanPassW19AndCompileReference() throws {
        let rules = [
            AnalysisReferenceRepeatabilityRule(domain: "tempo", metric: "decision_emitted", maximumAbsoluteSpread: 0),
            AnalysisReferenceRepeatabilityRule(domain: "tempo", metric: "tempo_rel_error", maximumAbsoluteSpread: 0),
            AnalysisReferenceRepeatabilityRule(domain: "tempo", metric: "exact_within_4pct", maximumAbsoluteSpread: 0),
            AnalysisReferenceRepeatabilityRule(domain: "tempo", metric: "octave_aware_within_4pct", maximumAbsoluteSpread: 0)
        ]
        let capture = captureSet(runs: [captureRun(id: "run-1"), captureRun(id: "run-2")])
        let raw = rawSet([
            .init(runID: "run-1", fixtureID: "fixture-1", domain: "tempo", status: .observed, evidenceArtifactIDs: ["evidence"], observedBPM: 120),
            .init(runID: "run-2", fixtureID: "fixture-1", domain: "tempo", status: .observed, evidenceArtifactIDs: ["evidence"], observedBPM: 120)
        ])
        let compiled = try AnalysisReferenceRawObservationDeriver.validateAndCompileReference(rawSet: raw, captureSet: capture, policy: policy(rules: rules), manifest: manifest(), manifestSHA256: manifestSHA, evaluatedAt: now)
        XCTAssertTrue(compiled.derivation.derivationReady)
        XCTAssertTrue(compiled.captureValidation.comparisonReady)
        XCTAssertEqual(compiled.auditedReference.rows.count, 1)
        XCTAssertTrue(compiled.auditedReference.parityEligible)
    }
}

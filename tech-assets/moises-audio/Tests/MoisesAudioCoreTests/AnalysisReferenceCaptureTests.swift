import Foundation
import XCTest
@testable import MoisesAudioCore

final class AnalysisReferenceCaptureTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_787_525_600)
    private let shaA = String(repeating: "a", count: 64)
    private let shaB = String(repeating: "b", count: 64)

    private func environment(build: String = "999") -> AnalysisReferenceCaptureEnvironment {
        .init(productName: "Moises: The Musician's App", appVersion: "9.9.9", buildVersion: build, deviceModel: "iPhone16,1", osVersion: "19.0", locale: "ja_JP", accountTier: "PREMIUM")
    }

    private func artifact(_ id: String = "evidence") -> AnalysisReferenceCaptureArtifact {
        .init(artifactID: id, sha256: shaB, mediaType: "video/mp4")
    }

    private func row(fixture: String = "fixture-1", metric: String = "beat_f_70ms", value: Double = 0.90, synthetic: Bool = false, artifactID: String = "evidence") -> AnalysisReferenceCaptureRow {
        .init(fixtureID: fixture, rightsClass: .licensedTest, genre: "rock", durationSeconds: 120, syntheticOnly: synthetic, domain: "beat", qualityMetrics: [metric: value], evidenceArtifactIDs: [artifactID])
    }

    private func run(_ id: String, value: Double, capturedAt: Date? = nil, environment: AnalysisReferenceCaptureEnvironment? = nil, manifestSHA: String? = nil, rows: [AnalysisReferenceCaptureRow]? = nil) -> AnalysisReferenceCaptureRun {
        .init(runID: id, operatorID: "operator-1", capturedAt: capturedAt ?? now, environment: environment ?? self.environment(), sourceBinding: .init(manifestID: "golden-v1", manifestSHA256: manifestSHA ?? shaA), observationMethod: .screenRecordingReview, artifacts: [artifact()], rows: rows ?? [row(value: value)])
    }

    private func policy(authority: String = "HQ_LATE_INTEGRATION", minimumRuns: Int = 2, rules: [AnalysisReferenceRepeatabilityRule]? = nil) -> AnalysisReferenceCapturePolicy {
        .init(policyID: "hq-current-moises", authority: authority, approvalReference: "HQ-APPROVAL-1", referenceEpochNotBefore: now.addingTimeInterval(-3600), expectedProductName: "Moises: The Musician's App", expectedAppVersion: "9.9.9", expectedBuildVersion: "999", expectedDeviceModel: "iPhone16,1", expectedOSVersion: "19.0", expectedLocale: "ja_JP", expectedAccountTier: "PREMIUM", expectedSourceManifestID: "golden-v1", expectedSourceManifestSHA256: shaA, minimumRepeatRuns: minimumRuns, repeatabilityRules: rules ?? [.init(domain: "beat", metric: "beat_f_70ms", maximumAbsoluteSpread: 0.01)])
    }

    private func captureSet(_ runs: [AnalysisReferenceCaptureRun]) -> AnalysisReferenceCaptureSet {
        .init(captureSetID: "capture-set-1", createdAt: now, runs: runs)
    }

    func testStableRepeatedCaptureCompilesMedianReference() throws {
        let set = captureSet([run("r1", value: 0.90), run("r2", value: 0.905)])
        let validation = AnalysisReferenceCaptureValidator.validate(captureSet: set, policy: policy(), evaluatedAt: now.addingTimeInterval(10))
        XCTAssertTrue(validation.comparisonReady)
        XCTAssertEqual(validation.status, .stablePendingHQ)
        XCTAssertEqual(validation.diagnostics.count, 1)
        XCTAssertEqual(validation.diagnostics[0].absoluteSpread, 0.005, accuracy: 1e-12)
        XCTAssertEqual(validation.diagnostics[0].median, 0.9025, accuracy: 1e-12)

        let report = try AnalysisReferenceCaptureValidator.compileAuditedReferenceReport(captureSet: set, policy: policy(), evaluatedAt: now.addingTimeInterval(10))
        XCTAssertEqual(report.engine, "current-iphone-moises-reference")
        XCTAssertTrue(report.parityEligible)
        XCTAssertEqual(try XCTUnwrap(report.rows.first?.metrics["beat_f_70ms"]), 0.9025, accuracy: 1e-12)
        XCTAssertTrue(report.engineVersion.contains("capture=capture-set-1"))
    }

    func testStaleMixedBuildAndMixedCorpusFailClosed() {
        let stale = captureSet([run("r1", value: 0.90, capturedAt: now.addingTimeInterval(-7200)), run("r2", value: 0.905)])
        XCTAssertTrue(AnalysisReferenceCaptureValidator.validate(captureSet: stale, policy: policy(), evaluatedAt: now).issues.contains { $0.code == .staleCapture })

        let mixedBuild = captureSet([run("r1", value: 0.90), run("r2", value: 0.905, environment: environment(build: "1000"))])
        XCTAssertTrue(AnalysisReferenceCaptureValidator.validate(captureSet: mixedBuild, policy: policy(), evaluatedAt: now.addingTimeInterval(10)).issues.contains { $0.code == .environmentMismatch })

        let mixedCorpus = captureSet([run("r1", value: 0.90), run("r2", value: 0.905, manifestSHA: shaB)])
        XCTAssertTrue(AnalysisReferenceCaptureValidator.validate(captureSet: mixedCorpus, policy: policy(), evaluatedAt: now.addingTimeInterval(10)).issues.contains { $0.code == .sourceBindingMismatch })
    }

    func testRowAndMetricCherryPickingFailsClosed() {
        let rowMismatch = captureSet([run("r1", value: 0.90), run("r2", value: 0.905, rows: [row(fixture: "fixture-2", value: 0.905)])])
        XCTAssertTrue(AnalysisReferenceCaptureValidator.validate(captureSet: rowMismatch, policy: policy(), evaluatedAt: now.addingTimeInterval(10)).issues.contains { $0.code == .rowSetMismatch })

        let metricMismatch = captureSet([run("r1", value: 0.90), run("r2", value: 0.905, rows: [row(metric: "median_abs_error_seconds", value: 0.01)])])
        let p = policy(rules: [.init(domain: "beat", metric: "beat_f_70ms", maximumAbsoluteSpread: 0.01), .init(domain: "beat", metric: "median_abs_error_seconds", maximumAbsoluteSpread: 0.01)])
        XCTAssertTrue(AnalysisReferenceCaptureValidator.validate(captureSet: metricMismatch, policy: p, evaluatedAt: now.addingTimeInterval(10)).issues.contains { $0.code == .metricSetMismatch })
    }

    func testMissingRuleAndRequiredMetricFailClosed() {
        let set = captureSet([run("r1", value: 0.90), run("r2", value: 0.905)])
        let noObservedRule = policy(rules: [.init(domain: "beat", metric: "median_abs_error_seconds", maximumAbsoluteSpread: 0.01, required: false)])
        XCTAssertTrue(AnalysisReferenceCaptureValidator.validate(captureSet: set, policy: noObservedRule, evaluatedAt: now.addingTimeInterval(10)).issues.contains { $0.code == .missingRepeatabilityRule })

        let requiredAbsent = policy(rules: [.init(domain: "beat", metric: "beat_f_70ms", maximumAbsoluteSpread: 0.01), .init(domain: "key", metric: "exact_key_accuracy", maximumAbsoluteSpread: 0)])
        XCTAssertTrue(AnalysisReferenceCaptureValidator.validate(captureSet: set, policy: requiredAbsent, evaluatedAt: now.addingTimeInterval(10)).issues.contains { $0.code == .requiredMetricAbsent })
    }

    func testUnstableRepeatabilityCannotBecomeReference() {
        let set = captureSet([run("r1", value: 0.90), run("r2", value: 0.70)])
        let validation = AnalysisReferenceCaptureValidator.validate(captureSet: set, policy: policy(), evaluatedAt: now.addingTimeInterval(10))
        XCTAssertFalse(validation.comparisonReady)
        XCTAssertEqual(validation.status, .invalid)
        XCTAssertTrue(validation.issues.contains { $0.code == .repeatabilityExceeded })
        XCTAssertThrowsError(try AnalysisReferenceCaptureValidator.compileAuditedReferenceReport(captureSet: set, policy: policy(), evaluatedAt: now.addingTimeInterval(10)))
    }

    func testSyntheticAndMissingEvidenceArtifactFailClosed() {
        let synthetic = captureSet([run("r1", value: 0.90, rows: [row(value: 0.90, synthetic: true)]), run("r2", value: 0.90, rows: [row(value: 0.90, synthetic: true)])])
        XCTAssertTrue(AnalysisReferenceCaptureValidator.validate(captureSet: synthetic, policy: policy(), evaluatedAt: now.addingTimeInterval(10)).issues.contains { $0.code == .syntheticCaptureNotReferenceEvidence })

        let missingEvidence = captureSet([run("r1", value: 0.90, rows: [row(value: 0.90, artifactID: "missing")]), run("r2", value: 0.905, rows: [row(value: 0.905, artifactID: "missing")])])
        XCTAssertTrue(AnalysisReferenceCaptureValidator.validate(captureSet: missingEvidence, policy: policy(), evaluatedAt: now.addingTimeInterval(10)).issues.contains { $0.code == .missingEvidenceArtifact })
    }

    func testPolicyAndFutureCaptureValidation() {
        let set = captureSet([run("r1", value: 0.90), run("r2", value: 0.905)])
        XCTAssertTrue(AnalysisReferenceCaptureValidator.validate(captureSet: set, policy: policy(authority: "WORKER_4"), evaluatedAt: now.addingTimeInterval(10)).issues.contains { $0.code == .invalidPolicy })
        XCTAssertTrue(AnalysisReferenceCaptureValidator.validate(captureSet: set, policy: policy(minimumRuns: 1), evaluatedAt: now.addingTimeInterval(10)).issues.contains { $0.code == .invalidPolicy })

        let future = captureSet([run("r1", value: 0.90, capturedAt: now.addingTimeInterval(100)), run("r2", value: 0.905)])
        XCTAssertTrue(AnalysisReferenceCaptureValidator.validate(captureSet: future, policy: policy(), evaluatedAt: now).issues.contains { $0.code == .futureCapture })
    }

    func testCapturePolicyAndValidationCodecRoundTrips() throws {
        let set = captureSet([run("r1", value: 0.90), run("r2", value: 0.905)])
        let p = policy()
        let validation = AnalysisReferenceCaptureValidator.validate(captureSet: set, policy: p, evaluatedAt: now.addingTimeInterval(10))
        XCTAssertEqual(try AnalysisReferenceCaptureCodec.decodeCaptureSet(AnalysisReferenceCaptureCodec.encodeCaptureSet(set)), set)
        XCTAssertEqual(try AnalysisReferenceCaptureCodec.decodePolicy(AnalysisReferenceCaptureCodec.encodePolicy(p)), p)
        XCTAssertEqual(try AnalysisReferenceCaptureCodec.decodeValidationReport(AnalysisReferenceCaptureCodec.encodeValidationReport(validation)), validation)
    }
}

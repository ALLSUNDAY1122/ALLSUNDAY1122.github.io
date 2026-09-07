import Foundation
import XCTest
@testable import MoisesAudioCore

final class AnalysisRealAudioParityCanonicalGateTests: XCTestCase {
    private func sha(_ character: Character) -> String {
        String(repeating: String(character), count: 64)
    }

    private func manifest() -> AnalysisRealAudioBenchmarkManifest {
        .init(
            manifestID: "manifest-canonical-w46",
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            cases: []
        )
    }

    private func coveragePolicy(manifestSHA: String) -> AnalysisCorpusCoveragePolicy {
        .init(
            policyID: "coverage-canonical-w46",
            authority: "HQ_LATE_INTEGRATION",
            approvalReference: "HQ-W46",
            expectedManifestID: "manifest-canonical-w46",
            expectedManifestSHA256: manifestSHA,
            minimumUniqueFixtureCount: 1,
            minimumTotalDurationSeconds: 1,
            domainMinimums: [],
            strata: []
        )
    }

    private func capturePolicy(manifestSHA: String) -> AnalysisReferenceCapturePolicy {
        .init(
            policyID: "capture-policy-canonical-w46",
            authority: "HQ_LATE_INTEGRATION",
            approvalReference: "HQ-W46",
            referenceEpochNotBefore: Date(timeIntervalSince1970: 1_699_000_000),
            expectedProductName: "Moises",
            expectedAppVersion: "current",
            expectedBuildVersion: "current",
            expectedDeviceModel: "iPhone",
            expectedOSVersion: "iOS",
            expectedLocale: "ja-JP",
            expectedAccountTier: "Premium",
            expectedSourceManifestID: "manifest-canonical-w46",
            expectedSourceManifestSHA256: manifestSHA,
            minimumRepeatRuns: 2,
            repeatabilityRules: []
        )
    }

    private func binding(manifestSHA: String) -> AnalysisAnalysisParityEvidenceBinding {
        .init(
            authority: "HQ_LATE_INTEGRATION",
            approvalReference: "HQ-W46",
            bindingID: "binding-canonical-w46",
            rightsApprovalReference: "HQ-W46-RIGHTS",
            manifestID: "manifest-canonical-w46",
            manifestSHA256: manifestSHA,
            expectedCoveragePolicyID: "coverage-canonical-w46",
            expectedCoveragePolicySHA256: sha("1"),
            expectedCaptureSetID: "capture-canonical-w46",
            expectedCaptureSetSHA256: sha("2"),
            expectedCapturePolicyID: "capture-policy-canonical-w46",
            expectedCapturePolicySHA256: sha("3"),
            expectedReviewSetID: "review-canonical-w46",
            expectedReviewSetSHA256: sha("4"),
            expectedReviewPolicyID: "review-policy-canonical-w46",
            expectedReviewPolicySHA256: sha("5"),
            expectedToleranceProfileID: "tolerance-canonical-w46",
            expectedToleranceProfileSHA256: sha("6"),
            expectedProjectReportSHA256: sha("7"),
            expectedProjectEngine: "project",
            expectedProjectEngineVersion: "1",
            projectPlatform: "iphoneos",
            projectArchitecture: "arm64",
            projectSourceRevision: "revision",
            projectBuildIdentity: "build",
            projectDeviceModel: "iPhone",
            projectOSVersion: "iOS",
            projectCaptureSessionID: "session",
            expectedReferenceEngine: "current-iphone-moises-reference",
            referencePlatform: "iphoneos",
            referenceProductName: "Moises",
            referenceAppVersion: "current",
            referenceBuildVersion: "current",
            referenceDeviceModel: "iPhone",
            referenceOSVersion: "iOS",
            referenceLocale: "ja-JP",
            referenceAccountTier: "Premium",
            referenceEpochNotBefore: Date(timeIntervalSince1970: 1_699_000_000),
            minimumIndependentReviewers: 2,
            minimumReferenceRuns: 2
        )
    }

    private func invoke(bytes: Data, binding: AnalysisAnalysisParityEvidenceBinding) throws -> AnalysisAnalysisParityAdjudicationReport {
        let coverage = coveragePolicy(manifestSHA: binding.manifestSHA256)
        let captureSet = AnalysisReferenceCaptureSet(
            captureSetID: "capture-canonical-w46",
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            runs: []
        )
        let capturePolicy = capturePolicy(manifestSHA: binding.manifestSHA256)
        let reviewSet = AnalysisReferenceReviewSet(
            reviewSetID: "review-canonical-w46",
            captureSetID: captureSet.captureSetID,
            sourceManifestID: binding.manifestID,
            sourceManifestSHA256: binding.manifestSHA256,
            submissions: []
        )
        let reviewPolicy = AnalysisReferenceReviewConsensusPolicy(
            policyID: "review-policy-canonical-w46",
            authority: "HQ_LATE_INTEGRATION",
            approvalReference: "HQ-W46",
            minimumIndependentReviewers: 2,
            reviewersMustDifferFromCaptureOperator: true,
            rules: []
        )
        let project = AnalysisAuditedRealAudioBenchmarkReport(
            manifestID: binding.manifestID,
            generatedAt: Date(timeIntervalSince1970: 1_700_000_000),
            engine: "project",
            engineVersion: "1",
            parityEligible: false,
            rows: [],
            domainQualitySummaries: [],
            genreQualitySummaries: [],
            evaluatorRejectedRows: [],
            nonParityRows: [],
            excludedContextMetricNames: [],
            validationIssues: []
        )
        let tolerance = AnalysisDifferentialToleranceProfile(
            profileID: "tolerance-canonical-w46",
            authority: "HQ_LATE_INTEGRATION",
            approvalReference: "HQ-W46",
            approvedAt: Date(timeIntervalSince1970: 1_700_000_000),
            expectedProjectEngine: "project",
            expectedReferenceEngine: "current-iphone-moises-reference",
            rules: []
        )
        return try AnalysisRealAudioParityCanonicalAdjudicator.adjudicate(
            manifestBytes: bytes,
            coveragePolicy: coverage,
            captureSet: captureSet,
            capturePolicy: capturePolicy,
            reviewSet: reviewSet,
            reviewPolicy: reviewPolicy,
            projectReport: project,
            toleranceProfile: tolerance,
            binding: binding,
            evaluatedAt: Date(timeIntervalSince1970: 1_700_000_100)
        )
    }

    func testMalformedManifestBytesAreRejectedBeforeAdjudication() throws {
        XCTAssertThrowsError(try invoke(bytes: Data("not-json".utf8), binding: binding(manifestSHA: sha("a")))) { error in
            XCTAssertEqual(error as? AnalysisAnalysisParityCanonicalGateError, .manifestDecodeFailed)
        }
    }

    func testSemanticallyValidButNonCanonicalManifestBytesAreRejected() throws {
        let canonical = try AnalysisRealAudioBenchmarkCodec.encodeManifest(manifest())
        var object = try JSONSerialization.jsonObject(with: canonical) as! [String: Any]
        object["manifestID"] = object.removeValue(forKey: "manifestID")
        let noncanonical = try JSONSerialization.data(withJSONObject: object, options: [])
        let digest = AnalysisDeviceWorkloadSHA256.hexDigest(noncanonical)
        XCTAssertThrowsError(try invoke(bytes: noncanonical, binding: binding(manifestSHA: digest))) { error in
            XCTAssertEqual(error as? AnalysisAnalysisParityCanonicalGateError, .manifestNotCanonical)
        }
    }

    func testCanonicalManifestDigestMustMatchHQBinding() throws {
        let canonical = try AnalysisRealAudioBenchmarkCodec.encodeManifest(manifest())
        XCTAssertThrowsError(try invoke(bytes: canonical, binding: binding(manifestSHA: sha("f")))) { error in
            XCTAssertEqual(error as? AnalysisAnalysisParityCanonicalGateError, .manifestDigestMismatch)
        }
    }

    func testCanonicalManifestWithMatchingDigestReachesFailClosedAdjudication() throws {
        let canonical = try AnalysisRealAudioBenchmarkCodec.encodeManifest(manifest())
        let digest = AnalysisDeviceWorkloadSHA256.hexDigest(canonical)
        let report = try invoke(bytes: canonical, binding: binding(manifestSHA: digest))
        XCTAssertEqual(report.status, .notReadyForHQJudgment)
        XCTAssertFalse(report.issues.isEmpty)
    }
}

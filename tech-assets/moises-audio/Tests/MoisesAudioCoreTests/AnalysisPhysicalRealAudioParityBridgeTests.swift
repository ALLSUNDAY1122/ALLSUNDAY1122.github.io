import Foundation
import XCTest
@testable import MoisesAudioCore

final class AnalysisPhysicalRealAudioParityBridgeTests: XCTestCase {
    private let generatedAt = Date(timeIntervalSince1970: 1_785_000_000)

    private struct Context {
        let manifest: AnalysisRealAudioBenchmarkManifest
        let manifestBytes: Data
        let package: AnalysisPhysicalRealAudioCorpusExecutionPackage
        let packageBytes: Data
        let coveragePolicy: AnalysisCorpusCoveragePolicy
        let captureSet: AnalysisReferenceCaptureSet
        let capturePolicy: AnalysisReferenceCapturePolicy
        let reviewSet: AnalysisReferenceReviewSet
        let reviewPolicy: AnalysisReferenceReviewConsensusPolicy
        let toleranceProfile: AnalysisDifferentialToleranceProfile
        let binding: AnalysisAnalysisParityEvidenceBinding
        let expectation: AnalysisPhysicalRealAudioParityBridgeExpectation
    }

    private func sha(_ character: Character) -> String {
        String(repeating: String(character), count: 64)
    }

    private func runtime(
        physicalSessionID: String = "physical-session-w48",
        sourceRevision: String = "source-revision-w48",
        buildIdentity: String = "build-w48"
    ) -> AnalysisPhysicalRealAudioRuntimeBinding {
        .init(
            authority: "HQ_LATE_INTEGRATION",
            approvalReference: "HQ-W48-PHYSICAL",
            platform: "iphoneos",
            architecture: "arm64",
            sourceRevision: sourceRevision,
            buildIdentity: buildIdentity,
            deviceModel: "iPhone17,1",
            osVersion: "20.0",
            physicalSessionID: physicalSessionID,
            analyzerID: "project-analysis",
            analyzerVersion: "w48",
            analysisConfigurationID: "product-baseline",
            engine: "project-owned-analysis",
            engineVersion: "w48-physical",
            decoder: .init(
                kind: .genuineLane2BoundedDecoder,
                decoderID: "lane2-decoder",
                decoderVersion: "1",
                decoderSessionID: "decoder-session-w48"
            )
        )
    }

    private func manifest() -> AnalysisRealAudioBenchmarkManifest {
        let rights = AnalysisRightsEvidence(
            grantID: "grant-w48",
            rightsClass: .projectOwned,
            permittedUses: [.analysisBenchmark, .internalQualityReview, .differentialReference],
            sourceSHA256: sha("a")
        )
        return .init(
            manifestID: "manifest-w48",
            createdAt: generatedAt,
            cases: [
                .init(
                    fixtureID: "fixture-w48",
                    projectID: UUID(uuidString: "00000000-0000-0000-0000-000000000048")!,
                    assetID: UUID(uuidString: "00000000-0000-0000-0000-000000000148")!,
                    relativePath: "bench/fixture-w48.wav",
                    genre: "rock",
                    sourceKind: .realAudio,
                    expectedDurationSeconds: 8,
                    rights: rights,
                    reference: .init(
                        bpm: 120,
                        beatTimesSeconds: [0.5, 1.0, 1.5, 2.0],
                        key: .init(tonicPitchClass: 0, mode: "major", confidence: nil),
                        chords: [.init(startSeconds: 0, endSeconds: 8, normalizedLabel: "C:maj", confidence: nil)],
                        sections: [.init(startSeconds: 0, endSeconds: 8, structuralLabel: "A", functionalLabel: "verse", confidence: nil)]
                    )
                )
            ]
        )
    }

    private func snapshot() -> AnalysisSnapshot {
        .init(
            tempo: .init(bpm: 120, confidence: 0.95, beatTimesSeconds: [0.5, 1.0, 1.5, 2.0]),
            key: .init(tonicPitchClass: 0, mode: "major", confidence: 0.95),
            chords: [.init(startSeconds: 0, endSeconds: 8, normalizedLabel: "C:maj", confidence: 0.95)],
            sections: [.init(startSeconds: 0, endSeconds: 8, structuralLabel: "A", functionalLabel: "verse", confidence: 0.95)]
        )
    }

    private func receipt(
        runtime: AnalysisPhysicalRealAudioRuntimeBinding,
        manifestSHA256: String
    ) throws -> AnalysisPhysicalRealAudioFixtureExecutionReceipt {
        let actualSnapshot = snapshot()
        let snapshotBytes = try AnalysisSnapshotRobustness.canonicalJSON(actualSnapshot)
        let snapshotSHA = AnalysisDeviceWorkloadSHA256.hexDigest(snapshotBytes)
        let source = AnalysisDeviceWorkloadSourceBinding(
            fixtureID: "fixture-w48",
            sourceSHA256: sha("a"),
            sourceDurationSeconds: 8,
            sourceSampleRate: 100,
            sourceChannelCount: 2
        )
        let identity = AnalysisDeviceWorkloadIdentity(
            analyzerID: runtime.analyzerID,
            analyzerVersion: runtime.analyzerVersion,
            analysisConfigurationID: runtime.analysisConfigurationID,
            buildIdentity: runtime.buildIdentity
        )
        let stages = AnalysisDeviceWorkloadStage.requiredCompleteOrder.enumerated().map {
            AnalysisDeviceWorkloadStageEvent(
                stage: $0.element,
                startedOffsetSeconds: Double($0.offset),
                endedOffsetSeconds: Double($0.offset) + 0.5,
                status: .completed
            )
        }
        let outputSummary = AnalysisDeviceWorkloadOutputSummary(snapshot: actualSnapshot)
        let executionBinding = AnalysisDeviceWorkloadReceiptValidator.executionBindingSHA256(
            runID: "run-w48",
            performanceEvidenceRunID: "run-w48",
            runKind: .completeAnalysis,
            manifestID: "manifest-w48",
            manifestSHA256: manifestSHA256,
            source: source,
            identity: identity,
            executionID: "execution-w48",
            workloadStartedAt: generatedAt,
            stages: stages,
            snapshotSHA256: snapshotSHA,
            outputSummary: outputSummary
        )
        let workload = AnalysisDeviceWorkloadReceipt(
            runID: "run-w48",
            performanceEvidenceRunID: "run-w48",
            runKind: .completeAnalysis,
            manifestID: "manifest-w48",
            manifestSHA256: manifestSHA256,
            source: source,
            identity: identity,
            executionID: "execution-w48",
            workloadStartedAt: generatedAt,
            stages: stages,
            snapshotCanonicalJSON: snapshotBytes,
            snapshotSHA256: snapshotSHA,
            outputSummary: outputSummary,
            executionBindingSHA256: executionBinding
        )
        return .init(
            fixtureID: "fixture-w48",
            runtimeBindingSHA256: try AnalysisPhysicalRealAudioCorpusCanonical.runtimeSHA256(runtime),
            decoderExecutionID: "decoder-execution-w48",
            sourceSHA256: sha("a"),
            sourceSampleRate: 100,
            sourceSampleCount: 800,
            sourceChannelCount: 2,
            observedSourceChunkCount: 4,
            observedSourceSampleCount: 800,
            workloadReceipt: workload
        )
    }

    private func coveragePolicy(manifestSHA256: String) -> AnalysisCorpusCoveragePolicy {
        .init(
            policyID: "coverage-w48",
            authority: "HQ_LATE_INTEGRATION",
            approvalReference: "HQ-W48-COVERAGE",
            expectedManifestID: "manifest-w48",
            expectedManifestSHA256: manifestSHA256,
            minimumUniqueFixtureCount: 1,
            minimumTotalDurationSeconds: 1,
            domainMinimums: [
                .init(domain: "tempo", minimumFixtureCount: 1, minimumTotalDurationSeconds: 1),
                .init(domain: "beat", minimumFixtureCount: 1, minimumTotalDurationSeconds: 1),
                .init(domain: "key", minimumFixtureCount: 1, minimumTotalDurationSeconds: 1),
                .init(domain: "chord", minimumFixtureCount: 1, minimumTotalDurationSeconds: 1),
                .init(domain: "structure", minimumFixtureCount: 1, minimumTotalDurationSeconds: 1)
            ],
            strata: [
                .init(
                    stratumID: "tempo-rock-w48",
                    domain: "tempo",
                    minimumFixtureCount: 1,
                    minimumTotalDurationSeconds: 1,
                    predicate: .init(genreExact: "rock")
                )
            ]
        )
    }

    private func captureSet() -> AnalysisReferenceCaptureSet {
        .init(captureSetID: "capture-w48", createdAt: generatedAt, runs: [])
    }

    private func capturePolicy(manifestSHA256: String) -> AnalysisReferenceCapturePolicy {
        .init(
            policyID: "capture-policy-w48",
            authority: "HQ_LATE_INTEGRATION",
            approvalReference: "HQ-W48-REFERENCE",
            referenceEpochNotBefore: generatedAt.addingTimeInterval(-60),
            expectedProductName: "Moises",
            expectedAppVersion: "current",
            expectedBuildVersion: "current-build",
            expectedDeviceModel: "iPhone-current",
            expectedOSVersion: "iOS-current",
            expectedLocale: "ja-JP",
            expectedAccountTier: "Premium",
            expectedSourceManifestID: "manifest-w48",
            expectedSourceManifestSHA256: manifestSHA256,
            minimumRepeatRuns: 2,
            repeatabilityRules: []
        )
    }

    private func reviewSet(manifestSHA256: String) -> AnalysisReferenceReviewSet {
        .init(
            reviewSetID: "review-w48",
            captureSetID: "capture-w48",
            sourceManifestID: "manifest-w48",
            sourceManifestSHA256: manifestSHA256,
            submissions: []
        )
    }

    private func reviewPolicy(id: String = "review-policy-w48") -> AnalysisReferenceReviewConsensusPolicy {
        .init(
            policyID: id,
            authority: "HQ_LATE_INTEGRATION",
            approvalReference: "HQ-W48-REVIEW",
            minimumIndependentReviewers: 2,
            reviewersMustDifferFromCaptureOperator: true,
            rules: [.init(spreadClass: .tempoBPM, maximumAbsoluteSpread: 0.1)]
        )
    }

    private func toleranceProfile(projectEngine: String) -> AnalysisDifferentialToleranceProfile {
        .init(
            profileID: "tolerance-w48",
            authority: "HQ_LATE_INTEGRATION",
            approvalReference: "HQ-W48-TOLERANCE",
            approvedAt: generatedAt,
            expectedProjectEngine: projectEngine,
            expectedReferenceEngine: "current-iphone-moises-reference",
            rules: []
        )
    }

    private func binding(
        package: AnalysisPhysicalRealAudioCorpusExecutionPackage,
        manifestSHA256: String,
        coveragePolicy: AnalysisCorpusCoveragePolicy,
        captureSet: AnalysisReferenceCaptureSet,
        capturePolicy: AnalysisReferenceCapturePolicy,
        reviewSet: AnalysisReferenceReviewSet,
        reviewPolicy: AnalysisReferenceReviewConsensusPolicy,
        toleranceProfile: AnalysisDifferentialToleranceProfile,
        projectCaptureSessionID: String? = nil,
        expectedProjectReportSHA256: String? = nil
    ) throws -> AnalysisAnalysisParityEvidenceBinding {
        .init(
            authority: "HQ_LATE_INTEGRATION",
            approvalReference: "HQ-W48-BINDING",
            bindingID: "binding-w48",
            rightsApprovalReference: "HQ-W48-RIGHTS",
            manifestID: package.manifestID,
            manifestSHA256: manifestSHA256,
            expectedCoveragePolicyID: coveragePolicy.policyID,
            expectedCoveragePolicySHA256: try AnalysisAnalysisParityAdjudicationRoot.stableSHA256(coveragePolicy),
            expectedCaptureSetID: captureSet.captureSetID,
            expectedCaptureSetSHA256: try AnalysisAnalysisParityAdjudicationRoot.stableSHA256(captureSet),
            expectedCapturePolicyID: capturePolicy.policyID,
            expectedCapturePolicySHA256: try AnalysisAnalysisParityAdjudicationRoot.stableSHA256(capturePolicy),
            expectedReviewSetID: reviewSet.reviewSetID,
            expectedReviewSetSHA256: try AnalysisAnalysisParityAdjudicationRoot.stableSHA256(reviewSet),
            expectedReviewPolicyID: reviewPolicy.policyID,
            expectedReviewPolicySHA256: try AnalysisAnalysisParityAdjudicationRoot.stableSHA256(reviewPolicy),
            expectedToleranceProfileID: toleranceProfile.profileID,
            expectedToleranceProfileSHA256: try AnalysisAnalysisParityAdjudicationRoot.stableSHA256(toleranceProfile),
            expectedProjectReportSHA256: expectedProjectReportSHA256 ?? package.auditedProjectReportSHA256,
            expectedProjectEngine: package.runtime.engine,
            expectedProjectEngineVersion: package.runtime.engineVersion,
            projectPlatform: package.runtime.platform,
            projectArchitecture: package.runtime.architecture,
            projectSourceRevision: package.runtime.sourceRevision,
            projectBuildIdentity: package.runtime.buildIdentity,
            projectDeviceModel: package.runtime.deviceModel,
            projectOSVersion: package.runtime.osVersion,
            projectCaptureSessionID: projectCaptureSessionID ?? package.runtime.physicalSessionID,
            expectedReferenceEngine: "current-iphone-moises-reference",
            referencePlatform: "iphoneos",
            referenceProductName: "Moises",
            referenceAppVersion: "current",
            referenceBuildVersion: "current-build",
            referenceDeviceModel: "iPhone-current",
            referenceOSVersion: "iOS-current",
            referenceLocale: "ja-JP",
            referenceAccountTier: "Premium",
            referenceEpochNotBefore: capturePolicy.referenceEpochNotBefore,
            minimumIndependentReviewers: 2,
            minimumReferenceRuns: 2
        )
    }

    private func makeContext() throws -> Context {
        let manifest = manifest()
        let manifestBytes = try AnalysisRealAudioBenchmarkCodec.encodeManifest(manifest)
        let manifestSHA = AnalysisDeviceWorkloadSHA256.hexDigest(manifestBytes)
        let runtime = runtime()
        let package = try AnalysisPhysicalRealAudioCorpusAssembler.assemble(
            manifest: manifest,
            manifestSHA256: manifestSHA,
            runtime: runtime,
            receipts: [try receipt(runtime: runtime, manifestSHA256: manifestSHA)],
            generatedAt: generatedAt
        )
        let packageBytes = try AnalysisPhysicalRealAudioCorpusCodec.encode(package)
        let coverage = coveragePolicy(manifestSHA256: manifestSHA)
        let captureSet = captureSet()
        let capturePolicy = capturePolicy(manifestSHA256: manifestSHA)
        let reviewSet = reviewSet(manifestSHA256: manifestSHA)
        let reviewPolicy = reviewPolicy()
        let tolerance = toleranceProfile(projectEngine: runtime.engine)
        let binding = try binding(
            package: package,
            manifestSHA256: manifestSHA,
            coveragePolicy: coverage,
            captureSet: captureSet,
            capturePolicy: capturePolicy,
            reviewSet: reviewSet,
            reviewPolicy: reviewPolicy,
            toleranceProfile: tolerance
        )
        let expectation = AnalysisPhysicalRealAudioParityBridgeExpectation(
            authority: "HQ_LATE_INTEGRATION",
            approvalReference: "HQ-W48-EXPECTATION",
            bridgeID: "bridge-w48",
            expectedW47PackageRootSHA256: package.declaredPackageRootSHA256,
            expectedW47PackageBytesSHA256: AnalysisDeviceWorkloadSHA256.hexDigest(packageBytes),
            expectedManifestID: manifest.manifestID,
            expectedManifestSHA256: manifestSHA,
            expectedRuntimeBindingSHA256: package.runtimeBindingSHA256,
            expectedPhysicalSessionID: runtime.physicalSessionID,
            expectedAuditedProjectReportSHA256: package.auditedProjectReportSHA256,
            expectedW46BindingSHA256: try AnalysisAnalysisParityAdjudicationRoot.stableSHA256(binding)
        )
        return .init(
            manifest: manifest,
            manifestBytes: manifestBytes,
            package: package,
            packageBytes: packageBytes,
            coveragePolicy: coverage,
            captureSet: captureSet,
            capturePolicy: capturePolicy,
            reviewSet: reviewSet,
            reviewPolicy: reviewPolicy,
            toleranceProfile: tolerance,
            binding: binding,
            expectation: expectation
        )
    }

    private func execute(
        _ context: Context,
        expectation: AnalysisPhysicalRealAudioParityBridgeExpectation? = nil,
        reviewPolicy: AnalysisReferenceReviewConsensusPolicy? = nil,
        binding: AnalysisAnalysisParityEvidenceBinding? = nil,
        packageBytes: Data? = nil,
        manifestBytes: Data? = nil
    ) throws -> AnalysisPhysicalRealAudioParityBridgeResult {
        try AnalysisPhysicalRealAudioParityBridge.adjudicate(
            w47PackageBytes: packageBytes ?? context.packageBytes,
            manifestBytes: manifestBytes ?? context.manifestBytes,
            expectation: expectation ?? context.expectation,
            coveragePolicy: context.coveragePolicy,
            captureSet: context.captureSet,
            capturePolicy: context.capturePolicy,
            reviewSet: context.reviewSet,
            reviewPolicy: reviewPolicy ?? context.reviewPolicy,
            toleranceProfile: context.toleranceProfile,
            w46Binding: binding ?? context.binding,
            evaluatedAt: generatedAt
        )
    }

    private func assertIssue(
        _ expected: AnalysisPhysicalRealAudioParityBridgeIssueCode,
        in body: () throws -> Void,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertThrowsError(try body(), file: file, line: line) { error in
            guard case let AnalysisPhysicalRealAudioParityBridgeError.invalid(issues) = error else {
                return XCTFail("unexpected error: \(error)", file: file, line: line)
            }
            XCTAssertTrue(issues.contains { $0.code == expected }, "missing issue \(expected): \(issues)", file: file, line: line)
        }
    }

    func testPinnedW47PackageInvokesW46AndEmitsDeterministicNonParityCertificate() throws {
        let context = try makeContext()
        let first = try execute(context)
        let second = try execute(context)

        XCTAssertEqual(first, second)
        XCTAssertEqual(first.certificate.status, .nonParityBridgeExecuted)
        XCTAssertEqual(first.certificate.w47PackageRootSHA256, context.package.declaredPackageRootSHA256)
        XCTAssertEqual(first.certificate.auditedProjectReportSHA256, context.package.auditedProjectReportSHA256)
        XCTAssertEqual(first.certificate.w46AdjudicationReportRootSHA256, first.adjudicationReport.declaredReportRootSHA256)
        XCTAssertEqual(first.certificate.limitations, AnalysisPhysicalRealAudioParityBridge.limitations)
        XCTAssertTrue(AnalysisAnalysisParityAdjudicationReportValidator.validate(first.adjudicationReport))
        XCTAssertEqual(first.adjudicationReport.status, .notReadyForHQJudgment)
    }

    func testDifferentPackageBytesRootFailsClosed() throws {
        let context = try makeContext()
        let wrong = AnalysisPhysicalRealAudioParityBridgeExpectation(
            authority: context.expectation.authority,
            approvalReference: context.expectation.approvalReference,
            bridgeID: context.expectation.bridgeID,
            expectedW47PackageRootSHA256: context.expectation.expectedW47PackageRootSHA256,
            expectedW47PackageBytesSHA256: sha("f"),
            expectedManifestID: context.expectation.expectedManifestID,
            expectedManifestSHA256: context.expectation.expectedManifestSHA256,
            expectedRuntimeBindingSHA256: context.expectation.expectedRuntimeBindingSHA256,
            expectedPhysicalSessionID: context.expectation.expectedPhysicalSessionID,
            expectedAuditedProjectReportSHA256: context.expectation.expectedAuditedProjectReportSHA256,
            expectedW46BindingSHA256: context.expectation.expectedW46BindingSHA256
        )
        assertIssue(.packageRootMismatch) { _ = try execute(context, expectation: wrong) }
    }

    func testPreviouslyConsumedW47PackageRootIsRejectedAsReplay() throws {
        let context = try makeContext()
        let replay = AnalysisPhysicalRealAudioParityBridgeExpectation(
            authority: context.expectation.authority,
            approvalReference: context.expectation.approvalReference,
            bridgeID: context.expectation.bridgeID,
            expectedW47PackageRootSHA256: context.expectation.expectedW47PackageRootSHA256,
            expectedW47PackageBytesSHA256: context.expectation.expectedW47PackageBytesSHA256,
            expectedManifestID: context.expectation.expectedManifestID,
            expectedManifestSHA256: context.expectation.expectedManifestSHA256,
            expectedRuntimeBindingSHA256: context.expectation.expectedRuntimeBindingSHA256,
            expectedPhysicalSessionID: context.expectation.expectedPhysicalSessionID,
            expectedAuditedProjectReportSHA256: context.expectation.expectedAuditedProjectReportSHA256,
            expectedW46BindingSHA256: context.expectation.expectedW46BindingSHA256,
            previouslyConsumedW47PackageRootSHA256s: [context.package.declaredPackageRootSHA256]
        )
        assertIssue(.packageRootReplay) { _ = try execute(context, expectation: replay) }
    }

    func testManifestRootSubstitutionFailsClosed() throws {
        let context = try makeContext()
        let wrong = AnalysisPhysicalRealAudioParityBridgeExpectation(
            authority: context.expectation.authority,
            approvalReference: context.expectation.approvalReference,
            bridgeID: context.expectation.bridgeID,
            expectedW47PackageRootSHA256: context.expectation.expectedW47PackageRootSHA256,
            expectedW47PackageBytesSHA256: context.expectation.expectedW47PackageBytesSHA256,
            expectedManifestID: context.expectation.expectedManifestID,
            expectedManifestSHA256: sha("e"),
            expectedRuntimeBindingSHA256: context.expectation.expectedRuntimeBindingSHA256,
            expectedPhysicalSessionID: context.expectation.expectedPhysicalSessionID,
            expectedAuditedProjectReportSHA256: context.expectation.expectedAuditedProjectReportSHA256,
            expectedW46BindingSHA256: context.expectation.expectedW46BindingSHA256
        )
        assertIssue(.manifestRootMismatch) { _ = try execute(context, expectation: wrong) }
    }

    func testRuntimeAndPhysicalSessionSubstitutionFailsClosed() throws {
        let context = try makeContext()
        let wrong = AnalysisPhysicalRealAudioParityBridgeExpectation(
            authority: context.expectation.authority,
            approvalReference: context.expectation.approvalReference,
            bridgeID: context.expectation.bridgeID,
            expectedW47PackageRootSHA256: context.expectation.expectedW47PackageRootSHA256,
            expectedW47PackageBytesSHA256: context.expectation.expectedW47PackageBytesSHA256,
            expectedManifestID: context.expectation.expectedManifestID,
            expectedManifestSHA256: context.expectation.expectedManifestSHA256,
            expectedRuntimeBindingSHA256: sha("d"),
            expectedPhysicalSessionID: "different-physical-session",
            expectedAuditedProjectReportSHA256: context.expectation.expectedAuditedProjectReportSHA256,
            expectedW46BindingSHA256: context.expectation.expectedW46BindingSHA256
        )
        assertIssue(.runtimeBindingMismatch) { _ = try execute(context, expectation: wrong) }
        assertIssue(.physicalSessionMismatch) { _ = try execute(context, expectation: wrong) }
    }

    func testW46SessionSubstitutionFailsBeforeCanonicalAdjudication() throws {
        let context = try makeContext()
        let mismatched = try binding(
            package: context.package,
            manifestSHA256: context.package.manifestSHA256,
            coveragePolicy: context.coveragePolicy,
            captureSet: context.captureSet,
            capturePolicy: context.capturePolicy,
            reviewSet: context.reviewSet,
            reviewPolicy: context.reviewPolicy,
            toleranceProfile: context.toleranceProfile,
            projectCaptureSessionID: "substituted-session"
        )
        let expectation = AnalysisPhysicalRealAudioParityBridgeExpectation(
            authority: context.expectation.authority,
            approvalReference: context.expectation.approvalReference,
            bridgeID: context.expectation.bridgeID,
            expectedW47PackageRootSHA256: context.expectation.expectedW47PackageRootSHA256,
            expectedW47PackageBytesSHA256: context.expectation.expectedW47PackageBytesSHA256,
            expectedManifestID: context.expectation.expectedManifestID,
            expectedManifestSHA256: context.expectation.expectedManifestSHA256,
            expectedRuntimeBindingSHA256: context.expectation.expectedRuntimeBindingSHA256,
            expectedPhysicalSessionID: context.expectation.expectedPhysicalSessionID,
            expectedAuditedProjectReportSHA256: context.expectation.expectedAuditedProjectReportSHA256,
            expectedW46BindingSHA256: try AnalysisAnalysisParityAdjudicationRoot.stableSHA256(mismatched)
        )
        assertIssue(.physicalSessionMismatch) { _ = try execute(context, expectation: expectation, binding: mismatched) }
        assertIssue(.w46ProjectBindingMismatch) { _ = try execute(context, expectation: expectation, binding: mismatched) }
    }

    func testW46ProjectReportSubstitutionFailsClosed() throws {
        let context = try makeContext()
        let substituted = try binding(
            package: context.package,
            manifestSHA256: context.package.manifestSHA256,
            coveragePolicy: context.coveragePolicy,
            captureSet: context.captureSet,
            capturePolicy: context.capturePolicy,
            reviewSet: context.reviewSet,
            reviewPolicy: context.reviewPolicy,
            toleranceProfile: context.toleranceProfile,
            expectedProjectReportSHA256: sha("c")
        )
        let expectation = AnalysisPhysicalRealAudioParityBridgeExpectation(
            authority: context.expectation.authority,
            approvalReference: context.expectation.approvalReference,
            bridgeID: context.expectation.bridgeID,
            expectedW47PackageRootSHA256: context.expectation.expectedW47PackageRootSHA256,
            expectedW47PackageBytesSHA256: context.expectation.expectedW47PackageBytesSHA256,
            expectedManifestID: context.expectation.expectedManifestID,
            expectedManifestSHA256: context.expectation.expectedManifestSHA256,
            expectedRuntimeBindingSHA256: context.expectation.expectedRuntimeBindingSHA256,
            expectedPhysicalSessionID: context.expectation.expectedPhysicalSessionID,
            expectedAuditedProjectReportSHA256: context.expectation.expectedAuditedProjectReportSHA256,
            expectedW46BindingSHA256: try AnalysisAnalysisParityAdjudicationRoot.stableSHA256(substituted)
        )
        assertIssue(.projectReportMismatch) { _ = try execute(context, expectation: expectation, binding: substituted) }
    }

    func testMixedReviewPolicyRootFailsBeforeW46() throws {
        let context = try makeContext()
        let mixed = reviewPolicy(id: "different-review-policy")
        assertIssue(.w46EvidenceRootMismatch) { _ = try execute(context, reviewPolicy: mixed) }
    }
}

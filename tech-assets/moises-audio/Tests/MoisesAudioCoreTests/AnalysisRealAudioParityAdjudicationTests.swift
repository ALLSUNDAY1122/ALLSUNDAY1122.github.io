import Foundation
import XCTest
@testable import MoisesAudioCore

final class AnalysisRealAudioParityAdjudicationTests: XCTestCase {
    private func sha(_ character: Character) -> String {
        String(repeating: String(character), count: 64)
    }

    private func sourceReference() -> AnalysisReferenceAnnotation {
        AnalysisReferenceAnnotation(
            bpm: 120,
            beatTimesSeconds: [0, 0.5, 1.0, 1.5],
            key: MusicalKey(tonicPitchClass: 0, mode: "major", confidence: 1),
            chords: [
                ChordEvent(startSeconds: 0, endSeconds: 1, normalizedLabel: "C:maj", confidence: 1),
                ChordEvent(startSeconds: 1, endSeconds: 2, normalizedLabel: "G:maj", confidence: 1)
            ],
            sections: [
                SongSection(startSeconds: 0, endSeconds: 1, structuralLabel: "A", functionalLabel: "verse", confidence: 1),
                SongSection(startSeconds: 1, endSeconds: 2, structuralLabel: "B", functionalLabel: "chorus", confidence: 1)
            ]
        )
    }

    private func fixture(
        id: String = "fixture-a",
        sourceKind: AnalysisBenchmarkSourceKind = .realAudio,
        uses: Set<AnalysisBenchmarkPermittedUse> = [.analysisBenchmark, .internalQualityReview, .differentialReference]
    ) -> AnalysisRealAudioBenchmarkCase {
        AnalysisRealAudioBenchmarkCase(
            fixtureID: id,
            projectID: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            assetID: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            relativePath: "fixtures/\(id).wav",
            genre: "rock",
            sourceKind: sourceKind,
            expectedDurationSeconds: 2,
            rights: AnalysisRightsEvidence(
                grantID: "grant-\(id)",
                rightsClass: .projectOwned,
                permittedUses: uses,
                sourceSHA256: sha("a")
            ),
            reference: sourceReference()
        )
    }

    private func manifest(_ item: AnalysisRealAudioBenchmarkCase? = nil) -> AnalysisRealAudioBenchmarkManifest {
        .init(
            manifestID: "manifest-w46",
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            cases: [item ?? fixture()]
        )
    }

    private func coveragePolicy(manifestSHA: String) -> AnalysisCorpusCoveragePolicy {
        .init(
            policyID: "coverage-w46",
            authority: "HQ_LATE_INTEGRATION",
            approvalReference: "HQ-W46-COVERAGE",
            expectedManifestID: "manifest-w46",
            expectedManifestSHA256: manifestSHA,
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
                .init(stratumID: "tempo-rock", domain: "tempo", minimumFixtureCount: 1, minimumTotalDurationSeconds: 1, predicate: .init(genreExact: "rock"))
            ]
        )
    }

    private func coverage() -> AnalysisCorpusCoverageReport {
        .init(
            schemaVersion: 1,
            generatedAt: Date(timeIntervalSince1970: 1_700_000_200),
            policyID: "coverage-w46",
            manifestID: "manifest-w46",
            manifestSHA256: sha("b"),
            status: .sufficientPendingHQ,
            comparisonCorpusReady: true,
            eligibleFixtureCount: 1,
            eligibleTotalDurationSeconds: 2,
            eligibleFixtureIDs: ["fixture-a"],
            domainDiagnostics: [],
            stratumDiagnostics: [],
            issues: []
        )
    }

    private func captureSet(manifestSHA: String) -> AnalysisReferenceCaptureSet {
        .init(
            captureSetID: "capture-w46",
            createdAt: Date(timeIntervalSince1970: 1_700_000_100),
            runs: []
        )
    }

    private func capturePolicy(manifestSHA: String) -> AnalysisReferenceCapturePolicy {
        .init(
            policyID: "capture-policy-w46",
            authority: "HQ_LATE_INTEGRATION",
            approvalReference: "HQ-W46-REFERENCE",
            referenceEpochNotBefore: Date(timeIntervalSince1970: 1_699_999_000),
            expectedProductName: "Moises",
            expectedAppVersion: "current",
            expectedBuildVersion: "current-build",
            expectedDeviceModel: "iPhone-current",
            expectedOSVersion: "iOS-current",
            expectedLocale: "ja-JP",
            expectedAccountTier: "Premium",
            expectedSourceManifestID: "manifest-w46",
            expectedSourceManifestSHA256: manifestSHA,
            minimumRepeatRuns: 2,
            repeatabilityRules: []
        )
    }

    private func reviewSet(manifestSHA: String) -> AnalysisReferenceReviewSet {
        .init(
            reviewSetID: "review-w46",
            captureSetID: "capture-w46",
            sourceManifestID: "manifest-w46",
            sourceManifestSHA256: manifestSHA,
            submissions: []
        )
    }

    private func reviewPolicy() -> AnalysisReferenceReviewConsensusPolicy {
        .init(
            policyID: "review-policy-w46",
            authority: "HQ_LATE_INTEGRATION",
            approvalReference: "HQ-W46-REVIEW",
            minimumIndependentReviewers: 2,
            reviewersMustDifferFromCaptureOperator: true,
            rules: [.init(spreadClass: .tempoBPM, maximumAbsoluteSpread: 0.1)]
        )
    }

    private func projectReport() -> AnalysisAuditedRealAudioBenchmarkReport {
        .init(
            manifestID: "manifest-w46",
            generatedAt: Date(timeIntervalSince1970: 1_700_000_300),
            engine: "project-physical-analysis",
            engineVersion: "w46-selected",
            parityEligible: true,
            rows: [],
            domainQualitySummaries: [],
            genreQualitySummaries: [],
            evaluatorRejectedRows: [],
            nonParityRows: [],
            excludedContextMetricNames: [],
            validationIssues: []
        )
    }

    private func toleranceProfile() -> AnalysisDifferentialToleranceProfile {
        .init(
            profileID: "tolerance-w46",
            authority: "HQ_LATE_INTEGRATION",
            approvalReference: "HQ-W46-TOLERANCE",
            approvedAt: Date(timeIntervalSince1970: 1_700_000_000),
            expectedProjectEngine: "project-physical-analysis",
            expectedReferenceEngine: "current-iphone-moises-reference",
            rules: []
        )
    }

    private func binding(
        manifest: AnalysisRealAudioBenchmarkManifest,
        manifestSHA: String,
        coveragePolicy: AnalysisCorpusCoveragePolicy,
        captureSet: AnalysisReferenceCaptureSet,
        capturePolicy: AnalysisReferenceCapturePolicy,
        reviewSet: AnalysisReferenceReviewSet,
        reviewPolicy: AnalysisReferenceReviewConsensusPolicy,
        projectReport: AnalysisAuditedRealAudioBenchmarkReport,
        toleranceProfile: AnalysisDifferentialToleranceProfile,
        projectPlatform: String = "iphoneos",
        projectArchitecture: String = "arm64",
        overrideCaptureRoot: String? = nil
    ) throws -> AnalysisAnalysisParityEvidenceBinding {
        .init(
            authority: "HQ_LATE_INTEGRATION",
            approvalReference: "HQ-W46-BINDING",
            bindingID: "binding-w46",
            rightsApprovalReference: "HQ-W46-RIGHTS",
            manifestID: manifest.manifestID,
            manifestSHA256: manifestSHA,
            expectedCoveragePolicyID: coveragePolicy.policyID,
            expectedCoveragePolicySHA256: try AnalysisAnalysisParityAdjudicationRoot.stableSHA256(coveragePolicy),
            expectedCaptureSetID: captureSet.captureSetID,
            expectedCaptureSetSHA256: try (overrideCaptureRoot ?? AnalysisAnalysisParityAdjudicationRoot.stableSHA256(captureSet)),
            expectedCapturePolicyID: capturePolicy.policyID,
            expectedCapturePolicySHA256: try AnalysisAnalysisParityAdjudicationRoot.stableSHA256(capturePolicy),
            expectedReviewSetID: reviewSet.reviewSetID,
            expectedReviewSetSHA256: try AnalysisAnalysisParityAdjudicationRoot.stableSHA256(reviewSet),
            expectedReviewPolicyID: reviewPolicy.policyID,
            expectedReviewPolicySHA256: try AnalysisAnalysisParityAdjudicationRoot.stableSHA256(reviewPolicy),
            expectedToleranceProfileID: toleranceProfile.profileID,
            expectedToleranceProfileSHA256: try AnalysisAnalysisParityAdjudicationRoot.stableSHA256(toleranceProfile),
            expectedProjectReportSHA256: try AnalysisAnalysisParityAdjudicationRoot.stableSHA256(projectReport),
            expectedProjectEngine: projectReport.engine,
            expectedProjectEngineVersion: projectReport.engineVersion,
            projectPlatform: projectPlatform,
            projectArchitecture: projectArchitecture,
            projectSourceRevision: "revision-w46",
            projectBuildIdentity: "build-w46",
            projectDeviceModel: "iPhone-selected",
            projectOSVersion: "iOS-selected",
            projectCaptureSessionID: "project-session-w46",
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

    private func pair(
        domain: String,
        metric: String,
        within: Bool = true,
        candidate: Bool = true,
        regression: Double = 0
    ) -> AnalysisDifferentialMetricPair {
        .init(
            fixtureID: "fixture-a",
            domain: domain,
            genre: "rock",
            metric: metric,
            direction: AnalysisBenchmarkAggregation.metricDirections[metric]!,
            projectValue: 1,
            referenceValue: 1,
            signedQualityDelta: regression == 0 ? 0 : -regression,
            regression: regression,
            maximumRegression: 0.05,
            withinTolerance: within,
            parityCandidateEvidence: candidate
        )
    }

    private var requiredPairs: [AnalysisDifferentialMetricPair] {
        let definitions: [(String, [String])] = [
            ("tempo", ["decision_emitted", "exact_within_4pct", "octave_aware_within_4pct", "tempo_rel_error"]),
            ("key", ["decision_emitted", "exact_key_accuracy", "tonic_accuracy", "mode_accuracy", "weighted_key_score"]),
            ("chord", ["root_weighted_accuracy", "majmin_weighted_accuracy", "no_chord_precision", "no_chord_recall", "coverage"]),
            ("structure", ["boundary_f_0_5s", "boundary_f_3_0s", "pairwise_f", "adjusted_rand_index", "structural_coverage"])
        ]
        return definitions.flatMap { domain, metrics in metrics.map { pair(domain: domain, metric: $0) } }
    }

    private func differential(_ pairs: [AnalysisDifferentialMetricPair]) -> AnalysisPairedDifferentialReport {
        .init(
            generatedAt: Date(timeIntervalSince1970: 1_700_000_400),
            status: .withinSuppliedTolerancePendingHQ,
            comparisonComplete: true,
            sameCorpusComplete: true,
            metricPairingComplete: true,
            allPairedEvidenceParityCandidate: pairs.allSatisfy(\.parityCandidateEvidence),
            allWithinSuppliedTolerance: pairs.allSatisfy { $0.withinTolerance == true },
            toleranceProfile: toleranceProfile(),
            project: .init(engine: "project-physical-analysis", engineVersion: "w46-selected", manifestID: "manifest-w46", generatedAt: Date(timeIntervalSince1970: 1_700_000_300)),
            reference: .init(engine: "current-iphone-moises-reference", engineVersion: "current", manifestID: "manifest-w46", generatedAt: Date(timeIntervalSince1970: 1_700_000_300)),
            pairs: pairs,
            metricSummaries: [],
            issues: []
        )
    }

    private func report(
        item: AnalysisRealAudioBenchmarkCase? = nil,
        pairs: [AnalysisDifferentialMetricPair]? = nil,
        bindingTransform: ((AnalysisAnalysisParityEvidenceBinding) throws -> AnalysisAnalysisParityEvidenceBinding)? = nil
    ) throws -> AnalysisAnalysisParityAdjudicationReport {
        let manifest = manifest(item)
        let manifestSHA = sha("b")
        let coveragePolicy = coveragePolicy(manifestSHA: manifestSHA)
        let captureSet = captureSet(manifestSHA: manifestSHA)
        let capturePolicy = capturePolicy(manifestSHA: manifestSHA)
        let reviewSet = reviewSet(manifestSHA: manifestSHA)
        let reviewPolicy = reviewPolicy()
        let project = projectReport()
        let tolerance = toleranceProfile()
        let baseBinding = try binding(
            manifest: manifest,
            manifestSHA: manifestSHA,
            coveragePolicy: coveragePolicy,
            captureSet: captureSet,
            capturePolicy: capturePolicy,
            reviewSet: reviewSet,
            reviewPolicy: reviewPolicy,
            projectReport: project,
            toleranceProfile: tolerance
        )
        let actualBinding = try bindingTransform?(baseBinding) ?? baseBinding
        return try AnalysisRealAudioParityAdjudicator.adjudicateVerifiedInputs(
            manifest: manifest,
            manifestSHA256: manifestSHA,
            coveragePolicy: coveragePolicy,
            coverage: coverage(),
            captureSet: captureSet,
            capturePolicy: capturePolicy,
            reviewSet: reviewSet,
            reviewPolicy: reviewPolicy,
            projectReport: project,
            toleranceProfile: tolerance,
            reviewed: nil,
            differential: differential(pairs ?? requiredPairs),
            binding: actualBinding,
            evaluatedAt: Date(timeIntervalSince1970: 1_700_000_500)
        )
    }

    func testSyntheticFixtureFailsClosed() throws {
        let value = try report(item: fixture(sourceKind: .syntheticTest))
        XCTAssertEqual(value.status, .notReadyForHQJudgment)
        XCTAssertTrue(value.issues.contains { $0.code == .syntheticEvidence })
    }

    func testRightsMustCoverReferenceAndInternalReviewNotOnlyBenchmark() throws {
        let value = try report(item: fixture(uses: [.analysisBenchmark]))
        XCTAssertEqual(value.status, .notReadyForHQJudgment)
        XCTAssertTrue(value.issues.contains { $0.code == .rightsNotCleared })
    }

    func testMixedEvidenceRootFailsClosed() throws {
        let manifest = manifest()
        let manifestSHA = sha("b")
        let cp = coveragePolicy(manifestSHA: manifestSHA)
        let cs = captureSet(manifestSHA: manifestSHA)
        let cap = capturePolicy(manifestSHA: manifestSHA)
        let rs = reviewSet(manifestSHA: manifestSHA)
        let rp = reviewPolicy()
        let project = projectReport()
        let tolerance = toleranceProfile()
        let wrong = try binding(
            manifest: manifest,
            manifestSHA: manifestSHA,
            coveragePolicy: cp,
            captureSet: cs,
            capturePolicy: cap,
            reviewSet: rs,
            reviewPolicy: rp,
            projectReport: project,
            toleranceProfile: tolerance,
            overrideCaptureRoot: sha("f")
        )
        let value = try AnalysisRealAudioParityAdjudicator.adjudicateVerifiedInputs(
            manifest: manifest,
            manifestSHA256: manifestSHA,
            coveragePolicy: cp,
            coverage: coverage(),
            captureSet: cs,
            capturePolicy: cap,
            reviewSet: rs,
            reviewPolicy: rp,
            projectReport: project,
            toleranceProfile: tolerance,
            reviewed: nil,
            differential: differential(requiredPairs),
            binding: wrong,
            evaluatedAt: Date(timeIntervalSince1970: 1_700_000_500)
        )
        XCTAssertTrue(value.issues.contains { $0.code == .mixedEvidenceRoots })
    }

    func testProjectSimulatorOrNonArm64BindingIsInvalid() throws {
        let manifest = manifest()
        let manifestSHA = sha("b")
        let cp = coveragePolicy(manifestSHA: manifestSHA)
        let cs = captureSet(manifestSHA: manifestSHA)
        let cap = capturePolicy(manifestSHA: manifestSHA)
        let rs = reviewSet(manifestSHA: manifestSHA)
        let rp = reviewPolicy()
        let project = projectReport()
        let tolerance = toleranceProfile()
        let simulator = try binding(
            manifest: manifest,
            manifestSHA: manifestSHA,
            coveragePolicy: cp,
            captureSet: cs,
            capturePolicy: cap,
            reviewSet: rs,
            reviewPolicy: rp,
            projectReport: project,
            toleranceProfile: tolerance,
            projectPlatform: "iphonesimulator",
            projectArchitecture: "x86_64"
        )
        let value = try AnalysisRealAudioParityAdjudicator.adjudicateVerifiedInputs(
            manifest: manifest,
            manifestSHA256: manifestSHA,
            coveragePolicy: cp,
            coverage: coverage(),
            captureSet: cs,
            capturePolicy: cap,
            reviewSet: rs,
            reviewPolicy: rp,
            projectReport: project,
            toleranceProfile: tolerance,
            reviewed: nil,
            differential: differential(requiredPairs),
            binding: simulator,
            evaluatedAt: Date(timeIntervalSince1970: 1_700_000_500)
        )
        XCTAssertTrue(value.issues.contains { $0.code == .invalidBinding })
    }

    func testOneMissingTempoMetricMakesOnlyTempoRowInventoryIncomplete() throws {
        let pairs = requiredPairs.filter { !($0.domain == "tempo" && $0.metric == "tempo_rel_error") }
        let value = try report(pairs: pairs)
        let tempo = value.rowAdjudications.first { $0.parityRowID == "MOI-P009" }!
        XCTAssertEqual(tempo.status, .notReadyForHQRowJudgment)
        XCTAssertTrue(tempo.issues.contains { $0.code == .rowInventoryMismatch || $0.code == .requiredMetricMissing })
        XCTAssertEqual(tempo.expectedPairCount, 4)
        XCTAssertEqual(tempo.observedPairCount, 3)
    }

    func testPairOutsideToleranceCannotBeMaskedByOtherGoodPairs() throws {
        var pairs = requiredPairs
        let index = pairs.firstIndex { $0.domain == "chord" && $0.metric == "root_weighted_accuracy" }!
        pairs[index] = pair(domain: "chord", metric: "root_weighted_accuracy", within: false, regression: 0.25)
        let value = try report(pairs: pairs)
        let chord = value.rowAdjudications.first { $0.parityRowID == "MOI-P013" }!
        XCTAssertEqual(chord.status, .notReadyForHQRowJudgment)
        XCTAssertEqual(chord.failedPairCount, 1)
        XCTAssertTrue(chord.issues.contains { $0.code == .pairOutsideTolerance })
    }

    func testNonParityCandidateCannotBeMaskedByOtherGoodPairs() throws {
        var pairs = requiredPairs
        let index = pairs.firstIndex { $0.domain == "structure" && $0.metric == "pairwise_f" }!
        pairs[index] = pair(domain: "structure", metric: "pairwise_f", candidate: false)
        let value = try report(pairs: pairs)
        let section = value.rowAdjudications.first { $0.parityRowID == "MOI-P016" }!
        XCTAssertEqual(section.status, .notReadyForHQRowJudgment)
        XCTAssertEqual(section.nonParityCandidatePairCount, 1)
        XCTAssertTrue(section.issues.contains { $0.code == .nonParityCandidatePair })
    }

    func testReportRootAndCodecAreDeterministic() throws {
        let a = try report()
        let b = try report()
        XCTAssertEqual(a, b)
        XCTAssertEqual(a.declaredReportRootSHA256, try AnalysisAnalysisParityAdjudicationRoot.reportSHA256(a))
        let data = try AnalysisAnalysisParityAdjudicationCodec.encodeReport(a)
        XCTAssertEqual(try AnalysisAnalysisParityAdjudicationCodec.decodeReport(data), a)
    }
}

import Foundation

public struct AnalysisAnalysisParityEvidenceBinding: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let authority: String
    public let approvalReference: String
    public let bindingID: String
    public let rightsApprovalReference: String
    public let manifestID: String
    public let manifestSHA256: String
    public let expectedCoveragePolicyID: String
    public let expectedCoveragePolicySHA256: String
    public let expectedCaptureSetID: String
    public let expectedCaptureSetSHA256: String
    public let expectedCapturePolicyID: String
    public let expectedCapturePolicySHA256: String
    public let expectedReviewSetID: String
    public let expectedReviewSetSHA256: String
    public let expectedReviewPolicyID: String
    public let expectedReviewPolicySHA256: String
    public let expectedToleranceProfileID: String
    public let expectedToleranceProfileSHA256: String
    public let expectedProjectReportSHA256: String
    public let expectedProjectEngine: String
    public let expectedProjectEngineVersion: String
    public let projectPlatform: String
    public let projectArchitecture: String
    public let projectSourceRevision: String
    public let projectBuildIdentity: String
    public let projectDeviceModel: String
    public let projectOSVersion: String
    public let projectCaptureSessionID: String
    public let expectedReferenceEngine: String
    public let referencePlatform: String
    public let referenceProductName: String
    public let referenceAppVersion: String
    public let referenceBuildVersion: String
    public let referenceDeviceModel: String
    public let referenceOSVersion: String
    public let referenceLocale: String
    public let referenceAccountTier: String
    public let referenceEpochNotBefore: Date
    public let minimumIndependentReviewers: Int
    public let minimumReferenceRuns: Int

    public init(
        schemaVersion: Int = 1,
        authority: String,
        approvalReference: String,
        bindingID: String,
        rightsApprovalReference: String,
        manifestID: String,
        manifestSHA256: String,
        expectedCoveragePolicyID: String,
        expectedCoveragePolicySHA256: String,
        expectedCaptureSetID: String,
        expectedCaptureSetSHA256: String,
        expectedCapturePolicyID: String,
        expectedCapturePolicySHA256: String,
        expectedReviewSetID: String,
        expectedReviewSetSHA256: String,
        expectedReviewPolicyID: String,
        expectedReviewPolicySHA256: String,
        expectedToleranceProfileID: String,
        expectedToleranceProfileSHA256: String,
        expectedProjectReportSHA256: String,
        expectedProjectEngine: String,
        expectedProjectEngineVersion: String,
        projectPlatform: String,
        projectArchitecture: String,
        projectSourceRevision: String,
        projectBuildIdentity: String,
        projectDeviceModel: String,
        projectOSVersion: String,
        projectCaptureSessionID: String,
        expectedReferenceEngine: String,
        referencePlatform: String,
        referenceProductName: String,
        referenceAppVersion: String,
        referenceBuildVersion: String,
        referenceDeviceModel: String,
        referenceOSVersion: String,
        referenceLocale: String,
        referenceAccountTier: String,
        referenceEpochNotBefore: Date,
        minimumIndependentReviewers: Int,
        minimumReferenceRuns: Int
    ) {
        self.schemaVersion = schemaVersion
        self.authority = authority
        self.approvalReference = approvalReference
        self.bindingID = bindingID
        self.rightsApprovalReference = rightsApprovalReference
        self.manifestID = manifestID
        self.manifestSHA256 = manifestSHA256.lowercased()
        self.expectedCoveragePolicyID = expectedCoveragePolicyID
        self.expectedCoveragePolicySHA256 = expectedCoveragePolicySHA256.lowercased()
        self.expectedCaptureSetID = expectedCaptureSetID
        self.expectedCaptureSetSHA256 = expectedCaptureSetSHA256.lowercased()
        self.expectedCapturePolicyID = expectedCapturePolicyID
        self.expectedCapturePolicySHA256 = expectedCapturePolicySHA256.lowercased()
        self.expectedReviewSetID = expectedReviewSetID
        self.expectedReviewSetSHA256 = expectedReviewSetSHA256.lowercased()
        self.expectedReviewPolicyID = expectedReviewPolicyID
        self.expectedReviewPolicySHA256 = expectedReviewPolicySHA256.lowercased()
        self.expectedToleranceProfileID = expectedToleranceProfileID
        self.expectedToleranceProfileSHA256 = expectedToleranceProfileSHA256.lowercased()
        self.expectedProjectReportSHA256 = expectedProjectReportSHA256.lowercased()
        self.expectedProjectEngine = expectedProjectEngine
        self.expectedProjectEngineVersion = expectedProjectEngineVersion
        self.projectPlatform = projectPlatform
        self.projectArchitecture = projectArchitecture
        self.projectSourceRevision = projectSourceRevision
        self.projectBuildIdentity = projectBuildIdentity
        self.projectDeviceModel = projectDeviceModel
        self.projectOSVersion = projectOSVersion
        self.projectCaptureSessionID = projectCaptureSessionID
        self.expectedReferenceEngine = expectedReferenceEngine
        self.referencePlatform = referencePlatform
        self.referenceProductName = referenceProductName
        self.referenceAppVersion = referenceAppVersion
        self.referenceBuildVersion = referenceBuildVersion
        self.referenceDeviceModel = referenceDeviceModel
        self.referenceOSVersion = referenceOSVersion
        self.referenceLocale = referenceLocale
        self.referenceAccountTier = referenceAccountTier
        self.referenceEpochNotBefore = referenceEpochNotBefore
        self.minimumIndependentReviewers = minimumIndependentReviewers
        self.minimumReferenceRuns = minimumReferenceRuns
    }
}

public enum AnalysisAnalysisParityAdjudicationStatus: String, Codable, Sendable {
    case notReadyForHQJudgment = "NOT_READY_FOR_HQ_ANALYSIS_PARITY_JUDGMENT"
    case readyForHQJudgment = "READY_FOR_HQ_ANALYSIS_PARITY_JUDGMENT"
}

public enum AnalysisAnalysisParityRowStatus: String, Codable, Sendable {
    case notReadyForHQRowJudgment = "NOT_READY_FOR_HQ_ROW_JUDGMENT"
    case readyForHQRowJudgment = "READY_FOR_HQ_ROW_JUDGMENT"
}

public enum AnalysisAnalysisParityAdjudicationIssueCode: String, Codable, Hashable, Sendable {
    case invalidBinding = "W46_INVALID_BINDING"
    case mixedEvidenceRoots = "W46_MIXED_EVIDENCE_ROOTS"
    case invalidManifest = "W46_INVALID_MANIFEST"
    case rightsNotCleared = "W46_RIGHTS_NOT_CLEARED"
    case syntheticEvidence = "W46_SYNTHETIC_EVIDENCE"
    case coverageNotReady = "W46_CORPUS_COVERAGE_NOT_READY"
    case referenceNotReady = "W46_REFERENCE_NOT_READY"
    case staleReferenceBinding = "W46_STALE_REFERENCE_BINDING"
    case referenceEnvironmentMismatch = "W46_REFERENCE_ENVIRONMENT_MISMATCH"
    case reviewerIndependenceInsufficient = "W46_REVIEWER_INDEPENDENCE_INSUFFICIENT"
    case projectReportInvalid = "W46_PROJECT_REPORT_INVALID"
    case projectRuntimeBindingMismatch = "W46_PROJECT_RUNTIME_BINDING_MISMATCH"
    case differentialNotReady = "W46_PAIRED_DIFFERENTIAL_NOT_READY"
    case rowInventoryMismatch = "W46_ROW_INVENTORY_MISMATCH"
    case requiredMetricMissing = "W46_REQUIRED_METRIC_MISSING"
    case pairOutsideTolerance = "W46_PAIR_OUTSIDE_TOLERANCE"
    case nonParityCandidatePair = "W46_NON_PARITY_CANDIDATE_PAIR"
}

public struct AnalysisAnalysisParityAdjudicationIssue: Codable, Equatable, Sendable {
    public let code: AnalysisAnalysisParityAdjudicationIssueCode
    public let parityRowID: String?
    public let fixtureID: String?
    public let domain: String?
    public let metric: String?
    public let detail: String

    public init(
        code: AnalysisAnalysisParityAdjudicationIssueCode,
        parityRowID: String? = nil,
        fixtureID: String? = nil,
        domain: String? = nil,
        metric: String? = nil,
        detail: String
    ) {
        self.code = code
        self.parityRowID = parityRowID
        self.fixtureID = fixtureID
        self.domain = domain
        self.metric = metric
        self.detail = detail
    }
}

public struct AnalysisAnalysisParityRowAdjudication: Codable, Equatable, Sendable {
    public let parityRowID: String
    public let feature: String
    public let domain: String
    public let status: AnalysisAnalysisParityRowStatus
    public let expectedFixtureIDs: [String]
    public let requiredMetrics: [String]
    public let expectedPairCount: Int
    public let observedPairCount: Int
    public let failedPairCount: Int
    public let nonParityCandidatePairCount: Int
    public let worstRegression: Double?
    public let worstFixtureID: String?
    public let issues: [AnalysisAnalysisParityAdjudicationIssue]

    public init(
        parityRowID: String,
        feature: String,
        domain: String,
        status: AnalysisAnalysisParityRowStatus,
        expectedFixtureIDs: [String],
        requiredMetrics: [String],
        expectedPairCount: Int,
        observedPairCount: Int,
        failedPairCount: Int,
        nonParityCandidatePairCount: Int,
        worstRegression: Double?,
        worstFixtureID: String?,
        issues: [AnalysisAnalysisParityAdjudicationIssue]
    ) {
        self.parityRowID = parityRowID
        self.feature = feature
        self.domain = domain
        self.status = status
        self.expectedFixtureIDs = expectedFixtureIDs.sorted()
        self.requiredMetrics = requiredMetrics.sorted()
        self.expectedPairCount = expectedPairCount
        self.observedPairCount = observedPairCount
        self.failedPairCount = failedPairCount
        self.nonParityCandidatePairCount = nonParityCandidatePairCount
        self.worstRegression = worstRegression
        self.worstFixtureID = worstFixtureID
        self.issues = issues.sorted(by: AnalysisRealAudioParityAdjudicator.issueOrder)
    }
}

public struct AnalysisAnalysisParityAdjudicationReport: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let status: AnalysisAnalysisParityAdjudicationStatus
    public let bindingID: String
    public let bindingRootSHA256: String
    public let manifestID: String
    public let manifestSHA256: String
    public let coveragePolicyRootSHA256: String
    public let captureSetRootSHA256: String
    public let capturePolicyRootSHA256: String
    public let reviewSetRootSHA256: String
    public let reviewPolicyRootSHA256: String
    public let toleranceProfileRootSHA256: String
    public let projectReportRootSHA256: String
    public let referenceReportRootSHA256: String?
    public let differentialReportRootSHA256: String?
    public let eligibleFixtureIDs: [String]
    public let rowAdjudications: [AnalysisAnalysisParityRowAdjudication]
    public let issues: [AnalysisAnalysisParityAdjudicationIssue]
    public let limitations: [String]
    public let declaredReportRootSHA256: String

    public init(
        schemaVersion: Int = 1,
        status: AnalysisAnalysisParityAdjudicationStatus,
        bindingID: String,
        bindingRootSHA256: String,
        manifestID: String,
        manifestSHA256: String,
        coveragePolicyRootSHA256: String,
        captureSetRootSHA256: String,
        capturePolicyRootSHA256: String,
        reviewSetRootSHA256: String,
        reviewPolicyRootSHA256: String,
        toleranceProfileRootSHA256: String,
        projectReportRootSHA256: String,
        referenceReportRootSHA256: String?,
        differentialReportRootSHA256: String?,
        eligibleFixtureIDs: [String],
        rowAdjudications: [AnalysisAnalysisParityRowAdjudication],
        issues: [AnalysisAnalysisParityAdjudicationIssue],
        limitations: [String],
        declaredReportRootSHA256: String
    ) {
        self.schemaVersion = schemaVersion
        self.status = status
        self.bindingID = bindingID
        self.bindingRootSHA256 = bindingRootSHA256.lowercased()
        self.manifestID = manifestID
        self.manifestSHA256 = manifestSHA256.lowercased()
        self.coveragePolicyRootSHA256 = coveragePolicyRootSHA256.lowercased()
        self.captureSetRootSHA256 = captureSetRootSHA256.lowercased()
        self.capturePolicyRootSHA256 = capturePolicyRootSHA256.lowercased()
        self.reviewSetRootSHA256 = reviewSetRootSHA256.lowercased()
        self.reviewPolicyRootSHA256 = reviewPolicyRootSHA256.lowercased()
        self.toleranceProfileRootSHA256 = toleranceProfileRootSHA256.lowercased()
        self.projectReportRootSHA256 = projectReportRootSHA256.lowercased()
        self.referenceReportRootSHA256 = referenceReportRootSHA256?.lowercased()
        self.differentialReportRootSHA256 = differentialReportRootSHA256?.lowercased()
        self.eligibleFixtureIDs = eligibleFixtureIDs.sorted()
        self.rowAdjudications = rowAdjudications.sorted { $0.parityRowID < $1.parityRowID }
        self.issues = issues.sorted(by: AnalysisRealAudioParityAdjudicator.issueOrder)
        self.limitations = limitations
        self.declaredReportRootSHA256 = declaredReportRootSHA256.lowercased()
    }
}

public enum AnalysisAnalysisParityAdjudicationError: Error, Equatable, Sendable {
    case canonicalEncodingFailed
}

public enum AnalysisAnalysisParityAdjudicationRoot {
    public static func stableSHA256<T: Encodable>(_ value: T) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return AnalysisDeviceWorkloadSHA256.hexDigest(try encoder.encode(value))
    }

    private struct ReportRootPayload: Codable {
        let schemaVersion: Int
        let status: AnalysisAnalysisParityAdjudicationStatus
        let bindingID: String
        let bindingRootSHA256: String
        let manifestID: String
        let manifestSHA256: String
        let coveragePolicyRootSHA256: String
        let captureSetRootSHA256: String
        let capturePolicyRootSHA256: String
        let reviewSetRootSHA256: String
        let reviewPolicyRootSHA256: String
        let toleranceProfileRootSHA256: String
        let projectReportRootSHA256: String
        let referenceReportRootSHA256: String?
        let differentialReportRootSHA256: String?
        let eligibleFixtureIDs: [String]
        let rowAdjudications: [AnalysisAnalysisParityRowAdjudication]
        let issues: [AnalysisAnalysisParityAdjudicationIssue]
        let limitations: [String]
    }

    public static func reportSHA256(_ report: AnalysisAnalysisParityAdjudicationReport) throws -> String {
        let payload = ReportRootPayload(
            schemaVersion: report.schemaVersion,
            status: report.status,
            bindingID: report.bindingID,
            bindingRootSHA256: report.bindingRootSHA256,
            manifestID: report.manifestID,
            manifestSHA256: report.manifestSHA256,
            coveragePolicyRootSHA256: report.coveragePolicyRootSHA256,
            captureSetRootSHA256: report.captureSetRootSHA256,
            capturePolicyRootSHA256: report.capturePolicyRootSHA256,
            reviewSetRootSHA256: report.reviewSetRootSHA256,
            reviewPolicyRootSHA256: report.reviewPolicyRootSHA256,
            toleranceProfileRootSHA256: report.toleranceProfileRootSHA256,
            projectReportRootSHA256: report.projectReportRootSHA256,
            referenceReportRootSHA256: report.referenceReportRootSHA256,
            differentialReportRootSHA256: report.differentialReportRootSHA256,
            eligibleFixtureIDs: report.eligibleFixtureIDs.sorted(),
            rowAdjudications: report.rowAdjudications.sorted { $0.parityRowID < $1.parityRowID },
            issues: report.issues.sorted(by: AnalysisRealAudioParityAdjudicator.issueOrder),
            limitations: report.limitations
        )
        return try stableSHA256(payload)
    }
}

public enum AnalysisRealAudioParityAdjudicator {
    public static let requiredAuthority = "HQ_LATE_INTEGRATION"
    public static let limitations = [
        "NON_PARITY: READY_FOR_HQ_ANALYSIS_PARITY_JUDGMENT means the real-audio evidence package is complete enough for HQ to judge MOI-P009/P011/P013/P016; it does not itself promote any PARITY row.",
        "W46 SHA-256 roots and HQ metadata bindings are tamper-evident commitments, not signatures, Apple attestation, Secure Enclave proofs or trusted timestamps.",
        "The selected Project physical-runtime fields in the HQ binding are provenance metadata unless independently attested or externally signed; W46 cannot manufacture device origin from a portable report.",
        "Reference observations remain valid only for the exact HQ-selected Moises app build, iPhone/OS, locale and tier bound by the W19-W21 policies and evidence.",
        "HQ must independently inspect rights grants, current-iPhone evidence artifacts and paired differential results before editing PARITY_MATRIX.json."
    ]

    private struct RowRequirement {
        let parityRowID: String
        let feature: String
        let domain: String
        let requiredMetrics: [String]
    }

    private static let rowRequirements: [RowRequirement] = [
        .init(
            parityRowID: "MOI-P009",
            feature: "BPM detection",
            domain: "tempo",
            requiredMetrics: ["decision_emitted", "exact_within_4pct", "octave_aware_within_4pct", "tempo_rel_error"]
        ),
        .init(
            parityRowID: "MOI-P011",
            feature: "AI key detection",
            domain: "key",
            requiredMetrics: ["decision_emitted", "exact_key_accuracy", "tonic_accuracy", "mode_accuracy", "weighted_key_score"]
        ),
        .init(
            parityRowID: "MOI-P013",
            feature: "chord detection",
            domain: "chord",
            requiredMetrics: ["root_weighted_accuracy", "majmin_weighted_accuracy", "no_chord_precision", "no_chord_recall", "coverage"]
        ),
        .init(
            parityRowID: "MOI-P016",
            feature: "song parts / section detection",
            domain: "structure",
            requiredMetrics: ["boundary_f_0_5s", "boundary_f_3_0s", "pairwise_f", "adjusted_rand_index", "structural_coverage"]
        )
    ]

    public static func adjudicate(
        manifest: AnalysisRealAudioBenchmarkManifest,
        manifestSHA256: String,
        coveragePolicy: AnalysisCorpusCoveragePolicy,
        captureSet: AnalysisReferenceCaptureSet,
        capturePolicy: AnalysisReferenceCapturePolicy,
        reviewSet: AnalysisReferenceReviewSet,
        reviewPolicy: AnalysisReferenceReviewConsensusPolicy,
        projectReport: AnalysisAuditedRealAudioBenchmarkReport,
        toleranceProfile: AnalysisDifferentialToleranceProfile,
        binding: AnalysisAnalysisParityEvidenceBinding,
        configuration: MusicAnalysisConfiguration = .productBaseline,
        evaluatedAt: Date = Date()
    ) throws -> AnalysisAnalysisParityAdjudicationReport {
        let coverage = AnalysisCorpusCoverageValidator.validate(
            manifest: manifest,
            manifestSHA256: manifestSHA256,
            policy: coveragePolicy,
            evaluatedAt: evaluatedAt
        )

        let reviewed: AnalysisReferenceReviewedCompilation?
        do {
            reviewed = try AnalysisReferenceReviewConsensusEngine.validateAndCompileReference(
                reviewSet: reviewSet,
                captureSet: captureSet,
                reviewPolicy: reviewPolicy,
                capturePolicy: capturePolicy,
                manifest: manifest,
                manifestSHA256: manifestSHA256,
                configuration: configuration,
                evaluatedAt: evaluatedAt,
                engine: binding.expectedReferenceEngine
            )
        } catch {
            reviewed = nil
        }

        let differential: AnalysisPairedDifferentialReport?
        if let reference = reviewed?.rawCompilation.auditedReference {
            differential = AnalysisPairedDifferentialComparator.compare(
                project: projectReport,
                reference: reference,
                profile: toleranceProfile,
                generatedAt: evaluatedAt
            )
        } else {
            differential = nil
        }

        return try adjudicateVerifiedInputs(
            manifest: manifest,
            manifestSHA256: manifestSHA256,
            coveragePolicy: coveragePolicy,
            coverage: coverage,
            captureSet: captureSet,
            capturePolicy: capturePolicy,
            reviewSet: reviewSet,
            reviewPolicy: reviewPolicy,
            projectReport: projectReport,
            toleranceProfile: toleranceProfile,
            reviewed: reviewed,
            differential: differential,
            binding: binding,
            evaluatedAt: evaluatedAt
        )
    }

    static func adjudicateVerifiedInputs(
        manifest: AnalysisRealAudioBenchmarkManifest,
        manifestSHA256: String,
        coveragePolicy: AnalysisCorpusCoveragePolicy,
        coverage: AnalysisCorpusCoverageReport,
        captureSet: AnalysisReferenceCaptureSet,
        capturePolicy: AnalysisReferenceCapturePolicy,
        reviewSet: AnalysisReferenceReviewSet,
        reviewPolicy: AnalysisReferenceReviewConsensusPolicy,
        projectReport: AnalysisAuditedRealAudioBenchmarkReport,
        toleranceProfile: AnalysisDifferentialToleranceProfile,
        reviewed: AnalysisReferenceReviewedCompilation?,
        differential: AnalysisPairedDifferentialReport?,
        binding: AnalysisAnalysisParityEvidenceBinding,
        evaluatedAt: Date
    ) throws -> AnalysisAnalysisParityAdjudicationReport {
        let normalizedManifestSHA = manifestSHA256.lowercased()
        let bindingRoot = try AnalysisAnalysisParityAdjudicationRoot.stableSHA256(binding)
        let coveragePolicyRoot = try AnalysisAnalysisParityAdjudicationRoot.stableSHA256(coveragePolicy)
        let captureSetRoot = try AnalysisAnalysisParityAdjudicationRoot.stableSHA256(captureSet)
        let capturePolicyRoot = try AnalysisAnalysisParityAdjudicationRoot.stableSHA256(capturePolicy)
        let reviewSetRoot = try AnalysisAnalysisParityAdjudicationRoot.stableSHA256(reviewSet)
        let reviewPolicyRoot = try AnalysisAnalysisParityAdjudicationRoot.stableSHA256(reviewPolicy)
        let toleranceProfileRoot = try AnalysisAnalysisParityAdjudicationRoot.stableSHA256(toleranceProfile)
        let projectReportRoot = try AnalysisAnalysisParityAdjudicationRoot.stableSHA256(projectReport)
        let referenceReportRoot = try reviewed.map { try AnalysisAnalysisParityAdjudicationRoot.stableSHA256($0.rawCompilation.auditedReference) }
        let differentialReportRoot = try differential.map { try AnalysisAnalysisParityAdjudicationRoot.stableSHA256($0) }

        var issues: [AnalysisAnalysisParityAdjudicationIssue] = []
        validateBindingShape(binding, issues: &issues)
        validateBindingRoots(
            binding,
            manifest: manifest,
            manifestSHA256: normalizedManifestSHA,
            coveragePolicy: coveragePolicy,
            coveragePolicyRoot: coveragePolicyRoot,
            captureSet: captureSet,
            captureSetRoot: captureSetRoot,
            capturePolicy: capturePolicy,
            capturePolicyRoot: capturePolicyRoot,
            reviewSet: reviewSet,
            reviewSetRoot: reviewSetRoot,
            reviewPolicy: reviewPolicy,
            reviewPolicyRoot: reviewPolicyRoot,
            toleranceProfile: toleranceProfile,
            toleranceProfileRoot: toleranceProfileRoot,
            projectReport: projectReport,
            projectReportRoot: projectReportRoot,
            issues: &issues
        )
        validateManifestAndRights(manifest, manifestSHA256: normalizedManifestSHA, evaluatedAt: evaluatedAt, issues: &issues)
        validateCoverage(coverage, manifest: manifest, policy: coveragePolicy, issues: &issues)
        validateReference(
            reviewed,
            captureSet: captureSet,
            capturePolicy: capturePolicy,
            reviewPolicy: reviewPolicy,
            binding: binding,
            issues: &issues
        )
        validateProject(projectReport, binding: binding, manifest: manifest, issues: &issues)
        validateDifferential(differential, issues: &issues)

        let rows = rowRequirements.map { requirement in
            adjudicateRow(requirement, manifest: manifest, differential: differential)
        }
        issues.append(contentsOf: rows.flatMap(\.issues))
        issues.sort(by: issueOrder)

        let ready = issues.isEmpty
            && rows.count == rowRequirements.count
            && rows.allSatisfy { $0.status == .readyForHQRowJudgment }
        let provisional = AnalysisAnalysisParityAdjudicationReport(
            status: ready ? .readyForHQJudgment : .notReadyForHQJudgment,
            bindingID: binding.bindingID,
            bindingRootSHA256: bindingRoot,
            manifestID: manifest.manifestID,
            manifestSHA256: normalizedManifestSHA,
            coveragePolicyRootSHA256: coveragePolicyRoot,
            captureSetRootSHA256: captureSetRoot,
            capturePolicyRootSHA256: capturePolicyRoot,
            reviewSetRootSHA256: reviewSetRoot,
            reviewPolicyRootSHA256: reviewPolicyRoot,
            toleranceProfileRootSHA256: toleranceProfileRoot,
            projectReportRootSHA256: projectReportRoot,
            referenceReportRootSHA256: referenceReportRoot,
            differentialReportRootSHA256: differentialReportRoot,
            eligibleFixtureIDs: coverage.eligibleFixtureIDs,
            rowAdjudications: rows,
            issues: issues,
            limitations: limitations,
            declaredReportRootSHA256: String(repeating: "0", count: 64)
        )
        let reportRoot = try AnalysisAnalysisParityAdjudicationRoot.reportSHA256(provisional)
        return .init(
            status: provisional.status,
            bindingID: provisional.bindingID,
            bindingRootSHA256: provisional.bindingRootSHA256,
            manifestID: provisional.manifestID,
            manifestSHA256: provisional.manifestSHA256,
            coveragePolicyRootSHA256: provisional.coveragePolicyRootSHA256,
            captureSetRootSHA256: provisional.captureSetRootSHA256,
            capturePolicyRootSHA256: provisional.capturePolicyRootSHA256,
            reviewSetRootSHA256: provisional.reviewSetRootSHA256,
            reviewPolicyRootSHA256: provisional.reviewPolicyRootSHA256,
            toleranceProfileRootSHA256: provisional.toleranceProfileRootSHA256,
            projectReportRootSHA256: provisional.projectReportRootSHA256,
            referenceReportRootSHA256: provisional.referenceReportRootSHA256,
            differentialReportRootSHA256: provisional.differentialReportRootSHA256,
            eligibleFixtureIDs: provisional.eligibleFixtureIDs,
            rowAdjudications: provisional.rowAdjudications,
            issues: provisional.issues,
            limitations: provisional.limitations,
            declaredReportRootSHA256: reportRoot
        )
    }

    private static func validateBindingShape(
        _ binding: AnalysisAnalysisParityEvidenceBinding,
        issues: inout [AnalysisAnalysisParityAdjudicationIssue]
    ) {
        let strings = [
            binding.approvalReference, binding.bindingID, binding.rightsApprovalReference, binding.manifestID,
            binding.expectedCoveragePolicyID, binding.expectedCaptureSetID, binding.expectedCapturePolicyID,
            binding.expectedReviewSetID, binding.expectedReviewPolicyID, binding.expectedToleranceProfileID,
            binding.expectedProjectEngine, binding.expectedProjectEngineVersion, binding.projectSourceRevision,
            binding.projectBuildIdentity, binding.projectDeviceModel, binding.projectOSVersion,
            binding.projectCaptureSessionID, binding.expectedReferenceEngine, binding.referenceProductName,
            binding.referenceAppVersion, binding.referenceBuildVersion, binding.referenceDeviceModel,
            binding.referenceOSVersion, binding.referenceLocale, binding.referenceAccountTier
        ]
        let hashes = [
            binding.manifestSHA256, binding.expectedCoveragePolicySHA256, binding.expectedCaptureSetSHA256,
            binding.expectedCapturePolicySHA256, binding.expectedReviewSetSHA256, binding.expectedReviewPolicySHA256,
            binding.expectedToleranceProfileSHA256, binding.expectedProjectReportSHA256
        ]
        let valid = binding.schemaVersion == 1
            && binding.authority == requiredAuthority
            && strings.allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            && AnalysisPhysicalEvidenceW39BatchLoader.safeComponent(binding.bindingID)
            && hashes.allSatisfy(AnalysisPhysicalEvidenceW39BatchLoader.isSHA256)
            && binding.projectPlatform.lowercased() == "iphoneos"
            && binding.projectArchitecture.lowercased() == "arm64"
            && binding.referencePlatform.lowercased() == "iphoneos"
            && binding.minimumIndependentReviewers >= 2
            && binding.minimumReferenceRuns >= 2
        if !valid {
            issues.append(.init(code: .invalidBinding, detail: "HQ binding requires schema 1, exact hashes/IDs, iphoneos/arm64 Project runtime, current-iPhone Reference and repeat/reviewer minimums"))
        }
    }

    private static func validateBindingRoots(
        _ binding: AnalysisAnalysisParityEvidenceBinding,
        manifest: AnalysisRealAudioBenchmarkManifest,
        manifestSHA256: String,
        coveragePolicy: AnalysisCorpusCoveragePolicy,
        coveragePolicyRoot: String,
        captureSet: AnalysisReferenceCaptureSet,
        captureSetRoot: String,
        capturePolicy: AnalysisReferenceCapturePolicy,
        capturePolicyRoot: String,
        reviewSet: AnalysisReferenceReviewSet,
        reviewSetRoot: String,
        reviewPolicy: AnalysisReferenceReviewConsensusPolicy,
        reviewPolicyRoot: String,
        toleranceProfile: AnalysisDifferentialToleranceProfile,
        toleranceProfileRoot: String,
        projectReport: AnalysisAuditedRealAudioBenchmarkReport,
        projectReportRoot: String,
        issues: inout [AnalysisAnalysisParityAdjudicationIssue]
    ) {
        let rootsMatch = binding.manifestID == manifest.manifestID
            && binding.manifestSHA256 == manifestSHA256
            && binding.expectedCoveragePolicyID == coveragePolicy.policyID
            && binding.expectedCoveragePolicySHA256 == coveragePolicyRoot
            && binding.expectedCaptureSetID == captureSet.captureSetID
            && binding.expectedCaptureSetSHA256 == captureSetRoot
            && binding.expectedCapturePolicyID == capturePolicy.policyID
            && binding.expectedCapturePolicySHA256 == capturePolicyRoot
            && binding.expectedReviewSetID == reviewSet.reviewSetID
            && binding.expectedReviewSetSHA256 == reviewSetRoot
            && binding.expectedReviewPolicyID == reviewPolicy.policyID
            && binding.expectedReviewPolicySHA256 == reviewPolicyRoot
            && binding.expectedToleranceProfileID == toleranceProfile.profileID
            && binding.expectedToleranceProfileSHA256 == toleranceProfileRoot
            && binding.expectedProjectReportSHA256 == projectReportRoot
            && projectReport.manifestID == manifest.manifestID
        if !rootsMatch {
            issues.append(.init(code: .mixedEvidenceRoots, detail: "manifest/policy/capture/review/tolerance/Project report roots or IDs differ from the independent HQ binding"))
        }
    }

    private static func validateManifestAndRights(
        _ manifest: AnalysisRealAudioBenchmarkManifest,
        manifestSHA256: String,
        evaluatedAt: Date,
        issues: inout [AnalysisAnalysisParityAdjudicationIssue]
    ) {
        guard AnalysisPhysicalEvidenceW39BatchLoader.isSHA256(manifestSHA256) else {
            issues.append(.init(code: .invalidManifest, detail: "manifest SHA-256 is invalid"))
            return
        }
        let manifestIssues = AnalysisRealAudioManifestValidator.validate(manifest, at: evaluatedAt)
        if !manifestIssues.isEmpty {
            issues.append(.init(code: .invalidManifest, detail: "canonical real-audio manifest validation returned \(manifestIssues.count) issue(s)"))
        }
        let requiredUses: Set<AnalysisBenchmarkPermittedUse> = [.analysisBenchmark, .internalQualityReview, .differentialReference]
        for item in manifest.cases {
            if item.sourceKind != .realAudio {
                issues.append(.init(code: .syntheticEvidence, fixtureID: item.fixtureID, detail: "synthetic fixtures cannot satisfy real-audio Analysis parity"))
            }
            let grantValid = !item.rights.grantID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && requiredUses.isSubset(of: item.rights.permittedUses)
                && AnalysisPhysicalEvidenceW39BatchLoader.isSHA256(item.rights.sourceSHA256)
                && (item.rights.expiresAt.map { $0 > evaluatedAt } ?? true)
            if !grantValid {
                issues.append(.init(code: .rightsNotCleared, fixtureID: item.fixtureID, detail: "fixture rights must explicitly cover benchmark, internal review and differential-reference use and remain unexpired"))
            }
        }
    }

    private static func validateCoverage(
        _ coverage: AnalysisCorpusCoverageReport,
        manifest: AnalysisRealAudioBenchmarkManifest,
        policy: AnalysisCorpusCoveragePolicy,
        issues: inout [AnalysisAnalysisParityAdjudicationIssue]
    ) {
        let expectedIDs = manifest.cases.map(\.fixtureID).sorted()
        let exactInventory = expectedIDs.count == Set(expectedIDs).count
            && coverage.eligibleFixtureIDs == expectedIDs
            && coverage.eligibleFixtureCount == expectedIDs.count
        let ready = coverage.schemaVersion == 1
            && coverage.policyID == policy.policyID
            && coverage.manifestID == manifest.manifestID
            && coverage.status == .sufficientPendingHQ
            && coverage.comparisonCorpusReady
            && coverage.issues.isEmpty
            && exactInventory
            && coverage.domainDiagnostics.allSatisfy(\.satisfied)
            && coverage.stratumDiagnostics.allSatisfy(\.satisfied)
        if !ready {
            issues.append(.init(code: .coverageNotReady, detail: "W22 coverage must be sufficient with the exact full real-audio fixture inventory and all domain/stratum minimums satisfied"))
        }
    }

    private static func validateReference(
        _ reviewed: AnalysisReferenceReviewedCompilation?,
        captureSet: AnalysisReferenceCaptureSet,
        capturePolicy: AnalysisReferenceCapturePolicy,
        reviewPolicy: AnalysisReferenceReviewConsensusPolicy,
        binding: AnalysisAnalysisParityEvidenceBinding,
        issues: inout [AnalysisAnalysisParityAdjudicationIssue]
    ) {
        guard let reviewed else {
            issues.append(.init(code: .referenceNotReady, detail: "W19-W21 current-iPhone reference review/derivation could not be compiled"))
            return
        }
        let consensus = reviewed.consensus
        let raw = reviewed.rawCompilation
        if consensus.status != .resolvedPendingW20
            || !consensus.consensusReady
            || !consensus.issues.isEmpty
            || !raw.derivation.derivationReady
            || !raw.derivation.issues.isEmpty
            || raw.captureValidation.status != .stablePendingHQ
            || !raw.captureValidation.comparisonReady
            || !raw.captureValidation.issues.isEmpty
            || !raw.auditedReference.parityEligible
            || !raw.auditedReference.validationIssues.isEmpty {
            issues.append(.init(code: .referenceNotReady, detail: "review consensus, raw derivation, repeated capture validation and audited current-iPhone reference must all be clean"))
        }

        if capturePolicy.referenceEpochNotBefore != binding.referenceEpochNotBefore
            || capturePolicy.minimumRepeatRuns < binding.minimumReferenceRuns
            || captureSet.runs.count < binding.minimumReferenceRuns {
            issues.append(.init(code: .staleReferenceBinding, detail: "Reference capture epoch/repeat inventory does not satisfy the independently supplied current-reference binding"))
        }

        let environmentMatches = capturePolicy.expectedProductName == binding.referenceProductName
            && capturePolicy.expectedAppVersion == binding.referenceAppVersion
            && capturePolicy.expectedBuildVersion == binding.referenceBuildVersion
            && capturePolicy.expectedDeviceModel == binding.referenceDeviceModel
            && capturePolicy.expectedOSVersion == binding.referenceOSVersion
            && capturePolicy.expectedLocale == binding.referenceLocale
            && capturePolicy.expectedAccountTier == binding.referenceAccountTier
            && raw.auditedReference.engine == binding.expectedReferenceEngine
            && captureSet.runs.allSatisfy {
                $0.environment.productName == binding.referenceProductName
                    && $0.environment.appVersion == binding.referenceAppVersion
                    && $0.environment.buildVersion == binding.referenceBuildVersion
                    && $0.environment.deviceModel == binding.referenceDeviceModel
                    && $0.environment.osVersion == binding.referenceOSVersion
                    && $0.environment.locale == binding.referenceLocale
                    && $0.environment.accountTier == binding.referenceAccountTier
                    && $0.capturedAt >= binding.referenceEpochNotBefore
            }
        if !environmentMatches {
            issues.append(.init(code: .referenceEnvironmentMismatch, detail: "W19-W21 reference evidence must come from the exact HQ-selected current Moises build/iPhone/OS/locale/tier"))
        }

        if reviewPolicy.minimumIndependentReviewers < binding.minimumIndependentReviewers
            || !reviewPolicy.reviewersMustDifferFromCaptureOperator {
            issues.append(.init(code: .reviewerIndependenceInsufficient, detail: "W21 must require at least the HQ-bound independent reviewer count and reviewers distinct from capture operator"))
        }
    }

    private static func validateProject(
        _ project: AnalysisAuditedRealAudioBenchmarkReport,
        binding: AnalysisAnalysisParityEvidenceBinding,
        manifest: AnalysisRealAudioBenchmarkManifest,
        issues: inout [AnalysisAnalysisParityAdjudicationIssue]
    ) {
        let valid = project.schemaVersion == 1
            && project.manifestID == manifest.manifestID
            && project.engine == binding.expectedProjectEngine
            && project.engineVersion == binding.expectedProjectEngineVersion
            && project.parityEligible
            && project.validationIssues.isEmpty
            && project.evaluatorRejectedRows.isEmpty
            && project.nonParityRows.isEmpty
        if !valid {
            issues.append(.init(code: .projectReportInvalid, detail: "Project audited report must cover the exact real corpus with no validation/evaluator/non-parity rows"))
        }

        let runtimeBound = binding.projectPlatform.lowercased() == "iphoneos"
            && binding.projectArchitecture.lowercased() == "arm64"
            && !binding.projectSourceRevision.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !binding.projectBuildIdentity.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !binding.projectDeviceModel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !binding.projectOSVersion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !binding.projectCaptureSessionID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if !runtimeBound {
            issues.append(.init(code: .projectRuntimeBindingMismatch, detail: "Project comparison must be externally bound to one selected iphoneos/arm64 physical runtime/build/device session"))
        }
    }

    private static func validateDifferential(
        _ differential: AnalysisPairedDifferentialReport?,
        issues: inout [AnalysisAnalysisParityAdjudicationIssue]
    ) {
        guard let differential else {
            issues.append(.init(code: .differentialNotReady, detail: "W18 paired differential could not be computed from reviewed Reference and Project reports"))
            return
        }
        let ready = differential.schemaVersion == 1
            && differential.status == .withinSuppliedTolerancePendingHQ
            && differential.comparisonComplete
            && differential.sameCorpusComplete
            && differential.metricPairingComplete
            && differential.allPairedEvidenceParityCandidate
            && differential.allWithinSuppliedTolerance
            && differential.finalParityAuthority == requiredAuthority
            && differential.issues.isEmpty
            && !differential.pairs.isEmpty
        if !ready {
            issues.append(.init(code: .differentialNotReady, detail: "W18 must be complete, same-corpus, metric-complete, parity-candidate and within all HQ-supplied pair tolerances"))
        }
    }

    private static func adjudicateRow(
        _ requirement: RowRequirement,
        manifest: AnalysisRealAudioBenchmarkManifest,
        differential: AnalysisPairedDifferentialReport?
    ) -> AnalysisAnalysisParityRowAdjudication {
        let fixtureIDs = manifest.cases
            .filter { $0.reference.coveredDomains.contains(requirement.domain) }
            .map(\.fixtureID)
            .sorted()
        let expectedKeys = Set(fixtureIDs.flatMap { fixtureID in
            requirement.requiredMetrics.map { "\(fixtureID)|\(requirement.domain)|\($0)" }
        })
        let relevantPairs = differential?.pairs.filter {
            $0.domain == requirement.domain && requirement.requiredMetrics.contains($0.metric)
        } ?? []
        let observedKeys = relevantPairs.map { "\($0.fixtureID)|\($0.domain)|\($0.metric)" }
        let uniqueObserved = Set(observedKeys)
        var rowIssues: [AnalysisAnalysisParityAdjudicationIssue] = []

        if fixtureIDs.isEmpty
            || uniqueObserved != expectedKeys
            || observedKeys.count != uniqueObserved.count
            || relevantPairs.count != expectedKeys.count {
            rowIssues.append(.init(
                code: .rowInventoryMismatch,
                parityRowID: requirement.parityRowID,
                domain: requirement.domain,
                detail: "every real fixture covering this domain must contribute every required quality metric exactly once"
            ))
        }

        for fixtureID in fixtureIDs {
            for metric in requirement.requiredMetrics {
                let matches = relevantPairs.filter { $0.fixtureID == fixtureID && $0.metric == metric }
                if matches.count != 1 {
                    rowIssues.append(.init(
                        code: .requiredMetricMissing,
                        parityRowID: requirement.parityRowID,
                        fixtureID: fixtureID,
                        domain: requirement.domain,
                        metric: metric,
                        detail: "required paired metric is missing or duplicated"
                    ))
                    continue
                }
                let pair = matches[0]
                if pair.withinTolerance != true {
                    rowIssues.append(.init(
                        code: .pairOutsideTolerance,
                        parityRowID: requirement.parityRowID,
                        fixtureID: fixtureID,
                        domain: requirement.domain,
                        metric: metric,
                        detail: "fixture-level regression exceeds or lacks the HQ-supplied tolerance"
                    ))
                }
                if !pair.parityCandidateEvidence {
                    rowIssues.append(.init(
                        code: .nonParityCandidatePair,
                        parityRowID: requirement.parityRowID,
                        fixtureID: fixtureID,
                        domain: requirement.domain,
                        metric: metric,
                        detail: "paired evidence is synthetic, rights-ineligible, metadata-mismatched or evaluator-rejected"
                    ))
                }
            }
        }

        rowIssues.sort(by: issueOrder)
        let failed = relevantPairs.filter { $0.withinTolerance != true }.count
        let nonCandidate = relevantPairs.filter { !$0.parityCandidateEvidence }.count
        let worst = relevantPairs.max { lhs, rhs in
            if lhs.regression == rhs.regression { return lhs.fixtureID > rhs.fixtureID }
            return lhs.regression < rhs.regression
        }
        let ready = rowIssues.isEmpty
            && !fixtureIDs.isEmpty
            && relevantPairs.count == expectedKeys.count
            && relevantPairs.allSatisfy { $0.withinTolerance == true && $0.parityCandidateEvidence }
        return .init(
            parityRowID: requirement.parityRowID,
            feature: requirement.feature,
            domain: requirement.domain,
            status: ready ? .readyForHQRowJudgment : .notReadyForHQRowJudgment,
            expectedFixtureIDs: fixtureIDs,
            requiredMetrics: requirement.requiredMetrics,
            expectedPairCount: expectedKeys.count,
            observedPairCount: relevantPairs.count,
            failedPairCount: failed,
            nonParityCandidatePairCount: nonCandidate,
            worstRegression: worst?.regression,
            worstFixtureID: worst?.fixtureID,
            issues: rowIssues
        )
    }

    static func issueOrder(
        _ lhs: AnalysisAnalysisParityAdjudicationIssue,
        _ rhs: AnalysisAnalysisParityAdjudicationIssue
    ) -> Bool {
        (
            lhs.code.rawValue,
            lhs.parityRowID ?? "",
            lhs.fixtureID ?? "",
            lhs.domain ?? "",
            lhs.metric ?? "",
            lhs.detail
        ) < (
            rhs.code.rawValue,
            rhs.parityRowID ?? "",
            rhs.fixtureID ?? "",
            rhs.domain ?? "",
            rhs.metric ?? "",
            rhs.detail
        )
    }
}

public enum AnalysisAnalysisParityAdjudicationCodec {
    private static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    public static func encodeBinding(_ value: AnalysisAnalysisParityEvidenceBinding) throws -> Data {
        try encoder().encode(value)
    }

    public static func decodeBinding(_ data: Data) throws -> AnalysisAnalysisParityEvidenceBinding {
        try decoder().decode(AnalysisAnalysisParityEvidenceBinding.self, from: data)
    }

    public static func encodeReport(_ value: AnalysisAnalysisParityAdjudicationReport) throws -> Data {
        try encoder().encode(value)
    }

    public static func decodeReport(_ data: Data) throws -> AnalysisAnalysisParityAdjudicationReport {
        try decoder().decode(AnalysisAnalysisParityAdjudicationReport.self, from: data)
    }
}

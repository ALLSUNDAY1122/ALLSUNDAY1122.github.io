import Foundation

public enum AnalysisReferenceEvidenceAnchorKind: String, Codable, Sendable {
    case timeRangeSeconds = "TIME_RANGE_SECONDS"
    case frameRange = "FRAME_RANGE"
    case imageRegion = "IMAGE_REGION"
    case pageRegion = "PAGE_REGION"
}

public struct AnalysisReferenceNormalizedRegion: Codable, Equatable, Sendable {
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

public struct AnalysisReferenceFieldEvidenceAnchor: Codable, Equatable, Sendable {
    public let fieldPath: String
    public let artifactID: String
    public let kind: AnalysisReferenceEvidenceAnchorKind
    public let startSeconds: Double?
    public let endSeconds: Double?
    public let startFrame: Int?
    public let endFrame: Int?
    public let pageIndex: Int?
    public let region: AnalysisReferenceNormalizedRegion?

    public init(
        fieldPath: String,
        artifactID: String,
        kind: AnalysisReferenceEvidenceAnchorKind,
        startSeconds: Double? = nil,
        endSeconds: Double? = nil,
        startFrame: Int? = nil,
        endFrame: Int? = nil,
        pageIndex: Int? = nil,
        region: AnalysisReferenceNormalizedRegion? = nil
    ) {
        self.fieldPath = fieldPath
        self.artifactID = artifactID
        self.kind = kind
        self.startSeconds = startSeconds
        self.endSeconds = endSeconds
        self.startFrame = startFrame
        self.endFrame = endFrame
        self.pageIndex = pageIndex
        self.region = region
    }
}

public struct AnalysisReferenceReviewSubmission: Codable, Equatable, Sendable {
    public let submissionID: String
    public let reviewerID: String
    public let reviewSessionID: String
    public let reviewRecordSHA256: String
    public let submittedAt: Date
    public let observation: AnalysisReferenceRawObservation
    public let anchors: [AnalysisReferenceFieldEvidenceAnchor]

    public init(
        submissionID: String,
        reviewerID: String,
        reviewSessionID: String,
        reviewRecordSHA256: String,
        submittedAt: Date,
        observation: AnalysisReferenceRawObservation,
        anchors: [AnalysisReferenceFieldEvidenceAnchor]
    ) {
        self.submissionID = submissionID
        self.reviewerID = reviewerID
        self.reviewSessionID = reviewSessionID
        self.reviewRecordSHA256 = reviewRecordSHA256.lowercased()
        self.submittedAt = submittedAt
        self.observation = observation
        self.anchors = anchors
    }
}

public struct AnalysisReferenceReviewSet: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let reviewSetID: String
    public let captureSetID: String
    public let sourceManifestID: String
    public let sourceManifestSHA256: String
    public let submissions: [AnalysisReferenceReviewSubmission]

    public init(
        schemaVersion: Int = 1,
        reviewSetID: String,
        captureSetID: String,
        sourceManifestID: String,
        sourceManifestSHA256: String,
        submissions: [AnalysisReferenceReviewSubmission]
    ) {
        self.schemaVersion = schemaVersion
        self.reviewSetID = reviewSetID
        self.captureSetID = captureSetID
        self.sourceManifestID = sourceManifestID
        self.sourceManifestSHA256 = sourceManifestSHA256.lowercased()
        self.submissions = submissions
    }
}

public enum AnalysisReferenceReviewSpreadClass: String, Codable, Hashable, Sendable {
    case tempoBPM = "TEMPO_BPM"
    case beatTimestampSeconds = "BEAT_TIMESTAMP_SECONDS"
    case chordBoundarySeconds = "CHORD_BOUNDARY_SECONDS"
    case sectionBoundarySeconds = "SECTION_BOUNDARY_SECONDS"
    case anchorTimeSeconds = "ANCHOR_TIME_SECONDS"
    case anchorFrameIndex = "ANCHOR_FRAME_INDEX"
    case anchorRegionCoordinate = "ANCHOR_REGION_COORDINATE"
}

public struct AnalysisReferenceReviewConsensusRule: Codable, Equatable, Sendable {
    public let spreadClass: AnalysisReferenceReviewSpreadClass
    public let maximumAbsoluteSpread: Double

    public init(spreadClass: AnalysisReferenceReviewSpreadClass, maximumAbsoluteSpread: Double) {
        self.spreadClass = spreadClass
        self.maximumAbsoluteSpread = maximumAbsoluteSpread
    }
}

public struct AnalysisReferenceReviewConsensusPolicy: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let policyID: String
    public let authority: String
    public let approvalReference: String
    public let minimumIndependentReviewers: Int
    public let reviewersMustDifferFromCaptureOperator: Bool
    public let rules: [AnalysisReferenceReviewConsensusRule]

    public init(
        schemaVersion: Int = 1,
        policyID: String,
        authority: String,
        approvalReference: String,
        minimumIndependentReviewers: Int,
        reviewersMustDifferFromCaptureOperator: Bool,
        rules: [AnalysisReferenceReviewConsensusRule]
    ) {
        self.schemaVersion = schemaVersion
        self.policyID = policyID
        self.authority = authority
        self.approvalReference = approvalReference
        self.minimumIndependentReviewers = minimumIndependentReviewers
        self.reviewersMustDifferFromCaptureOperator = reviewersMustDifferFromCaptureOperator
        self.rules = rules
    }
}

public enum AnalysisReferenceReviewConsensusIssueCode: String, Codable, Hashable, Sendable {
    case invalidPolicy = "INVALID_POLICY"
    case invalidReviewSet = "INVALID_REVIEW_SET"
    case sourceBindingMismatch = "SOURCE_BINDING_MISMATCH"
    case duplicateSubmissionID = "DUPLICATE_SUBMISSION_ID"
    case unexpectedSubmission = "UNEXPECTED_SUBMISSION"
    case missingSubmission = "MISSING_SUBMISSION"
    case invalidReviewerIdentity = "INVALID_REVIEWER_IDENTITY"
    case reviewerMatchesCaptureOperator = "REVIEWER_MATCHES_CAPTURE_OPERATOR"
    case insufficientIndependentReviewers = "INSUFFICIENT_INDEPENDENT_REVIEWERS"
    case duplicateReviewer = "DUPLICATE_REVIEWER"
    case suspectedCopiedSubmission = "SUSPECTED_COPIED_SUBMISSION"
    case invalidReviewTimestamp = "INVALID_REVIEW_TIMESTAMP"
    case observationIdentityMismatch = "OBSERVATION_IDENTITY_MISMATCH"
    case missingEvidenceArtifact = "MISSING_EVIDENCE_ARTIFACT"
    case duplicateAnchor = "DUPLICATE_ANCHOR"
    case missingAnchor = "MISSING_ANCHOR"
    case unexpectedAnchor = "UNEXPECTED_ANCHOR"
    case invalidAnchor = "INVALID_ANCHOR"
    case anchorDisagreement = "ANCHOR_DISAGREEMENT"
    case missingConsensusRule = "MISSING_CONSENSUS_RULE"
    case statusDisagreement = "STATUS_DISAGREEMENT"
    case payloadShapeDisagreement = "PAYLOAD_SHAPE_DISAGREEMENT"
    case valueDisagreement = "VALUE_DISAGREEMENT"
}

public struct AnalysisReferenceReviewConsensusIssue: Codable, Equatable, Sendable {
    public let code: AnalysisReferenceReviewConsensusIssueCode
    public let runID: String?
    public let fixtureID: String?
    public let domain: String?
    public let fieldPath: String?
    public let reviewerID: String?
    public let detail: String

    public init(
        code: AnalysisReferenceReviewConsensusIssueCode,
        runID: String? = nil,
        fixtureID: String? = nil,
        domain: String? = nil,
        fieldPath: String? = nil,
        reviewerID: String? = nil,
        detail: String
    ) {
        self.code = code
        self.runID = runID
        self.fixtureID = fixtureID
        self.domain = domain
        self.fieldPath = fieldPath
        self.reviewerID = reviewerID
        self.detail = detail
    }
}

public struct AnalysisReferenceReviewFieldConsensusDiagnostic: Codable, Equatable, Sendable {
    public let runID: String
    public let fixtureID: String
    public let domain: String
    public let fieldPath: String
    public let reviewerCount: Int
    public let exactAgreement: Bool
    public let observedMinimum: Double?
    public let observedMaximum: Double?
    public let observedSpread: Double?
    public let maximumAllowedSpread: Double?
    public let anchorAgreement: Bool
}

public struct AnalysisReferenceReviewObservationDiagnostic: Codable, Equatable, Sendable {
    public let runID: String
    public let fixtureID: String
    public let domain: String
    public let reviewerIDs: [String]
    public let consensusStatus: AnalysisReferenceRawObservationStatus
    public let resolved: Bool
    public let fieldDiagnostics: [AnalysisReferenceReviewFieldConsensusDiagnostic]
}

public enum AnalysisReferenceReviewConsensusStatus: String, Codable, Sendable {
    case invalid = "INVALID"
    case resolvedPendingW20 = "REVIEW_CONSENSUS_RESOLVED_PENDING_W20"
}

public struct AnalysisReferenceReviewConsensusReport: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let generatedAt: Date
    public let reviewSetID: String
    public let policyID: String
    public let status: AnalysisReferenceReviewConsensusStatus
    public let consensusReady: Bool
    public let diagnostics: [AnalysisReferenceReviewObservationDiagnostic]
    public let issues: [AnalysisReferenceReviewConsensusIssue]
    public let consensusRawObservationSet: AnalysisReferenceRawObservationSet

    public init(
        schemaVersion: Int = 1,
        generatedAt: Date,
        reviewSetID: String,
        policyID: String,
        status: AnalysisReferenceReviewConsensusStatus,
        consensusReady: Bool,
        diagnostics: [AnalysisReferenceReviewObservationDiagnostic],
        issues: [AnalysisReferenceReviewConsensusIssue],
        consensusRawObservationSet: AnalysisReferenceRawObservationSet
    ) {
        self.schemaVersion = schemaVersion
        self.generatedAt = generatedAt
        self.reviewSetID = reviewSetID
        self.policyID = policyID
        self.status = status
        self.consensusReady = consensusReady
        self.diagnostics = diagnostics
        self.issues = issues
        self.consensusRawObservationSet = consensusRawObservationSet
    }
}

public struct AnalysisReferenceReviewedCompilation: Codable, Equatable, Sendable {
    public let consensus: AnalysisReferenceReviewConsensusReport
    public let rawCompilation: AnalysisReferenceRawCompilation
}

public enum AnalysisReferenceReviewCompilerError: Error, Equatable, Sendable {
    case invalidConsensus([AnalysisReferenceReviewConsensusIssue])
    case downstreamRawCompilationFailed
}

public enum AnalysisReferenceReviewConsensusEngine {
    public static let requiredAuthority = "HQ_LATE_INTEGRATION"

    public static func resolve(
        reviewSet: AnalysisReferenceReviewSet,
        captureSet: AnalysisReferenceCaptureSet,
        policy: AnalysisReferenceReviewConsensusPolicy,
        evaluatedAt: Date = Date()
    ) -> AnalysisReferenceReviewConsensusReport {
        var issues = validatePolicy(policy)
        if reviewSet.schemaVersion != 1 || trimmed(reviewSet.reviewSetID).isEmpty || reviewSet.submissions.isEmpty {
            issues.append(.init(code: .invalidReviewSet, detail: "review set schema/id/submissions are invalid"))
        }
        if reviewSet.captureSetID != captureSet.captureSetID || !isSHA256(reviewSet.sourceManifestSHA256) {
            issues.append(.init(code: .sourceBindingMismatch, detail: "review set capture/source identity is invalid"))
        }
        if let firstRun = captureSet.runs.first {
            if reviewSet.sourceManifestID != firstRun.sourceBinding.manifestID || reviewSet.sourceManifestSHA256.caseInsensitiveCompare(firstRun.sourceBinding.manifestSHA256) != .orderedSame {
                issues.append(.init(code: .sourceBindingMismatch, detail: "review set source manifest differs from W19 capture binding"))
            }
        }

        if captureSet.runs.isEmpty {
            issues.append(.init(code: .invalidReviewSet, detail: "W19 capture set must contain at least one run"))
        }

        var runIndex: [String: AnalysisReferenceCaptureRun] = [:]
        var expectedRows: [ReviewObservationKey: AnalysisReferenceCaptureRow] = [:]
        for run in captureSet.runs {
            if runIndex[run.runID] == nil { runIndex[run.runID] = run }
            for row in run.rows {
                let key = ReviewObservationKey(runID: run.runID, fixtureID: row.fixtureID, domain: row.domain)
                if expectedRows[key] == nil { expectedRows[key] = row }
            }
        }

        var seenSubmissionIDs = Set<String>()
        var submissionsByKey: [ReviewObservationKey: [AnalysisReferenceReviewSubmission]] = [:]
        for submission in reviewSet.submissions {
            let observation = submission.observation
            let key = ReviewObservationKey(runID: observation.runID, fixtureID: observation.fixtureID, domain: observation.domain)
            if trimmed(submission.submissionID).isEmpty || !seenSubmissionIDs.insert(submission.submissionID).inserted {
                issues.append(.init(code: .duplicateSubmissionID, runID: key.runID, fixtureID: key.fixtureID, domain: key.domain, reviewerID: submission.reviewerID, detail: "submission_id must be non-empty and globally unique"))
            }
            if expectedRows[key] == nil {
                issues.append(.init(code: .unexpectedSubmission, runID: key.runID, fixtureID: key.fixtureID, domain: key.domain, reviewerID: submission.reviewerID, detail: "review submission has no W19 fixture/domain row"))
            }
            submissionsByKey[key, default: []].append(submission)
        }

        var diagnostics: [AnalysisReferenceReviewObservationDiagnostic] = []
        var outputObservations: [AnalysisReferenceRawObservation] = []
        var ruleIndex: [AnalysisReferenceReviewSpreadClass: AnalysisReferenceReviewConsensusRule] = [:]
        for rule in policy.rules where ruleIndex[rule.spreadClass] == nil {
            ruleIndex[rule.spreadClass] = rule
        }

        for key in expectedRows.keys.sorted() {
            guard let row = expectedRows[key], let run = runIndex[key.runID] else { continue }
            let submissions = (submissionsByKey[key] ?? []).sorted(by: submissionOrder)
            let issueStart = issues.count
            if submissions.isEmpty {
                issues.append(.init(code: .missingSubmission, runID: key.runID, fixtureID: key.fixtureID, domain: key.domain, detail: "no reviewer submission exists for W19 row"))
            }

            var reviewerIDs = Set<String>()
            var sessionOwners: [String: String] = [:]
            var recordOwners: [String: String] = [:]
            for submission in submissions {
                validateSubmission(submission, key: key, row: row, run: run, policy: policy, evaluatedAt: evaluatedAt, issues: &issues)
                let reviewer = trimmed(submission.reviewerID)
                if !reviewer.isEmpty, !reviewerIDs.insert(reviewer).inserted {
                    issues.append(.init(code: .duplicateReviewer, runID: key.runID, fixtureID: key.fixtureID, domain: key.domain, reviewerID: reviewer, detail: "same reviewer cannot count twice toward independent consensus"))
                }
                let session = trimmed(submission.reviewSessionID)
                if let owner = sessionOwners[session], owner != reviewer {
                    issues.append(.init(code: .suspectedCopiedSubmission, runID: key.runID, fixtureID: key.fixtureID, domain: key.domain, reviewerID: reviewer, detail: "distinct reviewers reused one review_session_id"))
                } else if !session.isEmpty {
                    sessionOwners[session] = reviewer
                }
                if let owner = recordOwners[submission.reviewRecordSHA256], owner != reviewer {
                    issues.append(.init(code: .suspectedCopiedSubmission, runID: key.runID, fixtureID: key.fixtureID, domain: key.domain, reviewerID: reviewer, detail: "distinct reviewers supplied byte-identical review record SHA-256"))
                } else if isSHA256(submission.reviewRecordSHA256) {
                    recordOwners[submission.reviewRecordSHA256] = reviewer
                }
            }
            if reviewerIDs.count < policy.minimumIndependentReviewers {
                issues.append(.init(code: .insufficientIndependentReviewers, runID: key.runID, fixtureID: key.fixtureID, domain: key.domain, detail: "unique reviewer count is below HQ policy"))
            }

            let groupHasStructuralIssue = issues.count != issueStart
            let consensusResult = groupHasStructuralIssue
                ? unresolvedObservation(key: key, row: row, submissions: submissions, reason: "REVIEW_STRUCTURAL_GATE_FAILED")
                : consensusObservation(key: key, row: row, submissions: submissions, ruleIndex: ruleIndex, issues: &issues)
            let resolved = issues.count == issueStart && consensusResult.resolved
            outputObservations.append(resolved ? consensusResult.observation : unresolvedObservation(key: key, row: row, submissions: submissions, reason: "REVIEW_CONSENSUS_UNRESOLVED").observation)
            diagnostics.append(.init(
                runID: key.runID,
                fixtureID: key.fixtureID,
                domain: key.domain,
                reviewerIDs: reviewerIDs.sorted(),
                consensusStatus: resolved ? consensusResult.observation.status : .unscorable,
                resolved: resolved,
                fieldDiagnostics: consensusResult.fieldDiagnostics.sorted(by: fieldDiagnosticOrder)
            ))
        }

        issues.sort(by: issueOrder)
        diagnostics.sort(by: observationDiagnosticOrder)
        outputObservations.sort(by: rawObservationOrder)
        let rawSet = AnalysisReferenceRawObservationSet(
            rawSetID: "review-consensus:\(reviewSet.reviewSetID)",
            captureSetID: captureSet.captureSetID,
            sourceManifestID: reviewSet.sourceManifestID,
            sourceManifestSHA256: reviewSet.sourceManifestSHA256,
            observations: outputObservations
        )
        let ready = issues.isEmpty && diagnostics.count == expectedRows.count && diagnostics.allSatisfy(\.resolved)
        return .init(
            generatedAt: evaluatedAt,
            reviewSetID: reviewSet.reviewSetID,
            policyID: policy.policyID,
            status: ready ? .resolvedPendingW20 : .invalid,
            consensusReady: ready,
            diagnostics: diagnostics,
            issues: issues,
            consensusRawObservationSet: rawSet
        )
    }

    public static func validateAndCompileReference(
        reviewSet: AnalysisReferenceReviewSet,
        captureSet: AnalysisReferenceCaptureSet,
        reviewPolicy: AnalysisReferenceReviewConsensusPolicy,
        capturePolicy: AnalysisReferenceCapturePolicy,
        manifest: AnalysisRealAudioBenchmarkManifest,
        manifestSHA256: String,
        configuration: MusicAnalysisConfiguration = .productBaseline,
        evaluatedAt: Date = Date(),
        engine: String = "current-iphone-moises-reference"
    ) throws -> AnalysisReferenceReviewedCompilation {
        let consensus = resolve(reviewSet: reviewSet, captureSet: captureSet, policy: reviewPolicy, evaluatedAt: evaluatedAt)
        guard consensus.consensusReady else { throw AnalysisReferenceReviewCompilerError.invalidConsensus(consensus.issues) }
        do {
            let raw = try AnalysisReferenceRawObservationDeriver.validateAndCompileReference(
                rawSet: consensus.consensusRawObservationSet,
                captureSet: captureSet,
                policy: capturePolicy,
                manifest: manifest,
                manifestSHA256: manifestSHA256,
                configuration: configuration,
                evaluatedAt: evaluatedAt,
                engine: engine
            )
            return .init(consensus: consensus, rawCompilation: raw)
        } catch {
            throw AnalysisReferenceReviewCompilerError.downstreamRawCompilationFailed
        }
    }

    private static func validatePolicy(_ policy: AnalysisReferenceReviewConsensusPolicy) -> [AnalysisReferenceReviewConsensusIssue] {
        var issues: [AnalysisReferenceReviewConsensusIssue] = []
        func invalid(_ detail: String) { issues.append(.init(code: .invalidPolicy, detail: detail)) }
        if policy.schemaVersion != 1 { invalid("unsupported review consensus policy schema_version") }
        if trimmed(policy.policyID).isEmpty { invalid("policy_id is required") }
        if policy.authority != requiredAuthority { invalid("authority must be HQ_LATE_INTEGRATION") }
        if trimmed(policy.approvalReference).isEmpty { invalid("approval_reference is required") }
        if policy.minimumIndependentReviewers < 2 { invalid("minimum_independent_reviewers must be at least 2") }
        if policy.rules.isEmpty { invalid("consensus rules cannot be empty") }
        var seen = Set<AnalysisReferenceReviewSpreadClass>()
        for rule in policy.rules {
            if !rule.maximumAbsoluteSpread.isFinite || rule.maximumAbsoluteSpread < 0 { invalid("all maximum_absolute_spread values must be finite and non-negative") }
            if !seen.insert(rule.spreadClass).inserted { invalid("duplicate consensus spread rule") }
        }
        return issues
    }

    private static func validateSubmission(
        _ submission: AnalysisReferenceReviewSubmission,
        key: ReviewObservationKey,
        row: AnalysisReferenceCaptureRow,
        run: AnalysisReferenceCaptureRun,
        policy: AnalysisReferenceReviewConsensusPolicy,
        evaluatedAt: Date,
        issues: inout [AnalysisReferenceReviewConsensusIssue]
    ) {
        let reviewer = trimmed(submission.reviewerID)
        if reviewer.isEmpty || trimmed(submission.reviewSessionID).isEmpty || !isSHA256(submission.reviewRecordSHA256) {
            issues.append(.init(code: .invalidReviewerIdentity, runID: key.runID, fixtureID: key.fixtureID, domain: key.domain, reviewerID: submission.reviewerID, detail: "reviewer_id, review_session_id and review_record_sha256 are required"))
        }
        if policy.reviewersMustDifferFromCaptureOperator && reviewer == trimmed(run.operatorID) {
            issues.append(.init(code: .reviewerMatchesCaptureOperator, runID: key.runID, fixtureID: key.fixtureID, domain: key.domain, reviewerID: reviewer, detail: "HQ policy requires reviewer independent from capture operator"))
        }
        if submission.submittedAt < run.capturedAt || submission.submittedAt > evaluatedAt.addingTimeInterval(1) {
            issues.append(.init(code: .invalidReviewTimestamp, runID: key.runID, fixtureID: key.fixtureID, domain: key.domain, reviewerID: reviewer, detail: "review timestamp must follow capture and not be in the future"))
        }
        let observation = submission.observation
        if observation.runID != key.runID || observation.fixtureID != key.fixtureID || observation.domain != key.domain {
            issues.append(.init(code: .observationIdentityMismatch, runID: key.runID, fixtureID: key.fixtureID, domain: key.domain, reviewerID: reviewer, detail: "submission observation identity differs from indexed W19 row"))
        }
        let rowArtifacts = Set(row.evidenceArtifactIDs)
        let observationArtifacts = Set(observation.evidenceArtifactIDs)
        if observationArtifacts.isEmpty || !observationArtifacts.isSubset(of: rowArtifacts) {
            issues.append(.init(code: .missingEvidenceArtifact, runID: key.runID, fixtureID: key.fixtureID, domain: key.domain, reviewerID: reviewer, detail: "review observation must use W19 row evidence artifacts"))
        }

        let requiredPaths = Set(requiredFieldPaths(observation))
        var anchorIndex: [String: AnalysisReferenceFieldEvidenceAnchor] = [:]
        for anchor in submission.anchors {
            if anchorIndex[anchor.fieldPath] != nil {
                issues.append(.init(code: .duplicateAnchor, runID: key.runID, fixtureID: key.fixtureID, domain: key.domain, fieldPath: anchor.fieldPath, reviewerID: reviewer, detail: "field_path anchor must be unique within submission"))
            } else {
                anchorIndex[anchor.fieldPath] = anchor
            }
            if !rowArtifacts.contains(anchor.artifactID) || !observationArtifacts.contains(anchor.artifactID) {
                issues.append(.init(code: .missingEvidenceArtifact, runID: key.runID, fixtureID: key.fixtureID, domain: key.domain, fieldPath: anchor.fieldPath, reviewerID: reviewer, detail: "anchor artifact must be bound by both W19 row and reviewer observation"))
            }
            if !anchorIsValid(anchor) {
                issues.append(.init(code: .invalidAnchor, runID: key.runID, fixtureID: key.fixtureID, domain: key.domain, fieldPath: anchor.fieldPath, reviewerID: reviewer, detail: "artifact-local anchor payload is invalid for its kind"))
            }
        }
        for path in requiredPaths.subtracting(Set(anchorIndex.keys)).sorted() {
            issues.append(.init(code: .missingAnchor, runID: key.runID, fixtureID: key.fixtureID, domain: key.domain, fieldPath: path, reviewerID: reviewer, detail: "every raw status/scalar/timestamp/label requires an artifact-local anchor"))
        }
        for path in Set(anchorIndex.keys).subtracting(requiredPaths).sorted() {
            issues.append(.init(code: .unexpectedAnchor, runID: key.runID, fixtureID: key.fixtureID, domain: key.domain, fieldPath: path, reviewerID: reviewer, detail: "anchor does not correspond to a raw observation field"))
        }
    }

    private static func consensusObservation(
        key: ReviewObservationKey,
        row: AnalysisReferenceCaptureRow,
        submissions: [AnalysisReferenceReviewSubmission],
        ruleIndex: [AnalysisReferenceReviewSpreadClass: AnalysisReferenceReviewConsensusRule],
        issues: inout [AnalysisReferenceReviewConsensusIssue]
    ) -> ConsensusResult {
        var fieldDiagnostics = anchorConsensusDiagnostics(key: key, submissions: submissions, ruleIndex: ruleIndex, issues: &issues)
        let statuses = Set(submissions.map { $0.observation.status })
        guard statuses.count == 1, let status = statuses.first else {
            issues.append(.init(code: .statusDisagreement, runID: key.runID, fixtureID: key.fixtureID, domain: key.domain, detail: "reviewers disagree on raw observation status"))
            return unresolvedObservation(key: key, row: row, submissions: submissions, reason: "STATUS_DISAGREEMENT", fieldDiagnostics: fieldDiagnostics)
        }
        let evidence = Array(Set(submissions.flatMap { $0.observation.evidenceArtifactIDs })).sorted()
        let limitations = Array(Set(submissions.flatMap { $0.observation.limitations })).sorted()
        if status != .observed {
            guard submissions.allSatisfy({ payloadIsEmpty($0.observation) }) else {
                issues.append(.init(code: .payloadShapeDisagreement, runID: key.runID, fixtureID: key.fixtureID, domain: key.domain, detail: "non-observed status must not carry raw value payload"))
                return unresolvedObservation(key: key, row: row, submissions: submissions, reason: "PAYLOAD_SHAPE_DISAGREEMENT", fieldDiagnostics: fieldDiagnostics)
            }
            return .init(observation: .init(runID: key.runID, fixtureID: key.fixtureID, domain: key.domain, status: status, evidenceArtifactIDs: evidence, limitations: limitations), resolved: true, fieldDiagnostics: fieldDiagnostics)
        }

        switch key.domain {
        case "tempo":
            guard let values = allPresent(submissions.map { $0.observation.observedBPM }), let value = numericConsensus(values, spreadClass: .tempoBPM, key: key, fieldPath: "observed_bpm", ruleIndex: ruleIndex, issues: &issues, diagnostics: &fieldDiagnostics) else {
                return unresolvedObservation(key: key, row: row, submissions: submissions, reason: "TEMPO_VALUE_DISAGREEMENT", fieldDiagnostics: fieldDiagnostics)
            }
            return .init(observation: .init(runID: key.runID, fixtureID: key.fixtureID, domain: key.domain, status: .observed, evidenceArtifactIDs: evidence, observedBPM: value, limitations: limitations), resolved: true, fieldDiagnostics: fieldDiagnostics)
        case "beat":
            let arrays = submissions.compactMap { $0.observation.beatTimesSeconds }
            guard arrays.count == submissions.count, let count = arrays.first?.count, arrays.allSatisfy({ $0.count == count }) else {
                issues.append(.init(code: .payloadShapeDisagreement, runID: key.runID, fixtureID: key.fixtureID, domain: key.domain, detail: "reviewers disagree on beat timestamp cardinality"))
                return unresolvedObservation(key: key, row: row, submissions: submissions, reason: "BEAT_CARDINALITY_DISAGREEMENT", fieldDiagnostics: fieldDiagnostics)
            }
            var output: [Double] = []
            for index in 0..<count {
                let values = arrays.map { $0[index] }
                guard let value = numericConsensus(values, spreadClass: .beatTimestampSeconds, key: key, fieldPath: "beat_times_seconds[\(index)]", ruleIndex: ruleIndex, issues: &issues, diagnostics: &fieldDiagnostics) else {
                    return unresolvedObservation(key: key, row: row, submissions: submissions, reason: "BEAT_VALUE_DISAGREEMENT", fieldDiagnostics: fieldDiagnostics)
                }
                output.append(value)
            }
            return .init(observation: .init(runID: key.runID, fixtureID: key.fixtureID, domain: key.domain, status: .observed, evidenceArtifactIDs: evidence, beatTimesSeconds: output, limitations: limitations), resolved: true, fieldDiagnostics: fieldDiagnostics)
        case "key":
            let keys = submissions.compactMap { $0.observation.key }
            guard keys.count == submissions.count, let first = keys.first, keys.allSatisfy({ $0 == first }) else {
                issues.append(.init(code: .valueDisagreement, runID: key.runID, fixtureID: key.fixtureID, domain: key.domain, detail: "key tonic/mode requires exact reviewer agreement"))
                return unresolvedObservation(key: key, row: row, submissions: submissions, reason: "KEY_VALUE_DISAGREEMENT", fieldDiagnostics: fieldDiagnostics)
            }
            fieldDiagnostics.append(exactFieldDiagnostic(key: key, fieldPath: "key.tonic_pitch_class", reviewerCount: submissions.count))
            fieldDiagnostics.append(exactFieldDiagnostic(key: key, fieldPath: "key.mode", reviewerCount: submissions.count))
            return .init(observation: .init(runID: key.runID, fixtureID: key.fixtureID, domain: key.domain, status: .observed, evidenceArtifactIDs: evidence, key: first, limitations: limitations), resolved: true, fieldDiagnostics: fieldDiagnostics)
        case "chord":
            let arrays = submissions.compactMap { $0.observation.chords }
            guard arrays.count == submissions.count, let count = arrays.first?.count, arrays.allSatisfy({ $0.count == count }) else {
                issues.append(.init(code: .payloadShapeDisagreement, runID: key.runID, fixtureID: key.fixtureID, domain: key.domain, detail: "reviewers disagree on chord event cardinality"))
                return unresolvedObservation(key: key, row: row, submissions: submissions, reason: "CHORD_CARDINALITY_DISAGREEMENT", fieldDiagnostics: fieldDiagnostics)
            }
            var output: [AnalysisReferenceObservedChord] = []
            for index in 0..<count {
                let events = arrays.map { $0[index] }
                guard let label = exactStringConsensus(events.map(\.normalizedLabel)) else {
                    issues.append(.init(code: .valueDisagreement, runID: key.runID, fixtureID: key.fixtureID, domain: key.domain, fieldPath: "chords[\(index)].normalized_label", detail: "chord labels require exact reviewer agreement"))
                    return unresolvedObservation(key: key, row: row, submissions: submissions, reason: "CHORD_LABEL_DISAGREEMENT", fieldDiagnostics: fieldDiagnostics)
                }
                guard let start = numericConsensus(events.map(\.startSeconds), spreadClass: .chordBoundarySeconds, key: key, fieldPath: "chords[\(index)].start_seconds", ruleIndex: ruleIndex, issues: &issues, diagnostics: &fieldDiagnostics),
                      let end = numericConsensus(events.map(\.endSeconds), spreadClass: .chordBoundarySeconds, key: key, fieldPath: "chords[\(index)].end_seconds", ruleIndex: ruleIndex, issues: &issues, diagnostics: &fieldDiagnostics) else {
                    return unresolvedObservation(key: key, row: row, submissions: submissions, reason: "CHORD_BOUNDARY_DISAGREEMENT", fieldDiagnostics: fieldDiagnostics)
                }
                fieldDiagnostics.append(exactFieldDiagnostic(key: key, fieldPath: "chords[\(index)].normalized_label", reviewerCount: submissions.count))
                output.append(.init(startSeconds: start, endSeconds: end, normalizedLabel: label))
            }
            return .init(observation: .init(runID: key.runID, fixtureID: key.fixtureID, domain: key.domain, status: .observed, evidenceArtifactIDs: evidence, chords: output, limitations: limitations), resolved: true, fieldDiagnostics: fieldDiagnostics)
        case "structure":
            let arrays = submissions.compactMap { $0.observation.sections }
            guard arrays.count == submissions.count, let count = arrays.first?.count, arrays.allSatisfy({ $0.count == count }) else {
                issues.append(.init(code: .payloadShapeDisagreement, runID: key.runID, fixtureID: key.fixtureID, domain: key.domain, detail: "reviewers disagree on section cardinality"))
                return unresolvedObservation(key: key, row: row, submissions: submissions, reason: "SECTION_CARDINALITY_DISAGREEMENT", fieldDiagnostics: fieldDiagnostics)
            }
            var output: [AnalysisReferenceObservedSection] = []
            for index in 0..<count {
                let sections = arrays.map { $0[index] }
                guard let structural = exactStringConsensus(sections.map(\.structuralLabel)), let functional = exactOptionalStringConsensus(sections.map(\.functionalLabel)) else {
                    issues.append(.init(code: .valueDisagreement, runID: key.runID, fixtureID: key.fixtureID, domain: key.domain, detail: "section labels require exact reviewer agreement"))
                    return unresolvedObservation(key: key, row: row, submissions: submissions, reason: "SECTION_LABEL_DISAGREEMENT", fieldDiagnostics: fieldDiagnostics)
                }
                guard let start = numericConsensus(sections.map(\.startSeconds), spreadClass: .sectionBoundarySeconds, key: key, fieldPath: "sections[\(index)].start_seconds", ruleIndex: ruleIndex, issues: &issues, diagnostics: &fieldDiagnostics),
                      let end = numericConsensus(sections.map(\.endSeconds), spreadClass: .sectionBoundarySeconds, key: key, fieldPath: "sections[\(index)].end_seconds", ruleIndex: ruleIndex, issues: &issues, diagnostics: &fieldDiagnostics) else {
                    return unresolvedObservation(key: key, row: row, submissions: submissions, reason: "SECTION_BOUNDARY_DISAGREEMENT", fieldDiagnostics: fieldDiagnostics)
                }
                fieldDiagnostics.append(exactFieldDiagnostic(key: key, fieldPath: "sections[\(index)].structural_label", reviewerCount: submissions.count))
                if functional != nil { fieldDiagnostics.append(exactFieldDiagnostic(key: key, fieldPath: "sections[\(index)].functional_label", reviewerCount: submissions.count)) }
                output.append(.init(startSeconds: start, endSeconds: end, structuralLabel: structural, functionalLabel: functional))
            }
            return .init(observation: .init(runID: key.runID, fixtureID: key.fixtureID, domain: key.domain, status: .observed, evidenceArtifactIDs: evidence, sections: output, limitations: limitations), resolved: true, fieldDiagnostics: fieldDiagnostics)
        default:
            issues.append(.init(code: .payloadShapeDisagreement, runID: key.runID, fixtureID: key.fixtureID, domain: key.domain, detail: "unsupported review consensus domain"))
            return unresolvedObservation(key: key, row: row, submissions: submissions, reason: "UNSUPPORTED_DOMAIN", fieldDiagnostics: fieldDiagnostics)
        }
    }

    private static func numericConsensus(
        _ values: [Double],
        spreadClass: AnalysisReferenceReviewSpreadClass,
        key: ReviewObservationKey,
        fieldPath: String,
        ruleIndex: [AnalysisReferenceReviewSpreadClass: AnalysisReferenceReviewConsensusRule],
        issues: inout [AnalysisReferenceReviewConsensusIssue],
        diagnostics: inout [AnalysisReferenceReviewFieldConsensusDiagnostic]
    ) -> Double? {
        guard !values.isEmpty, values.allSatisfy(\.isFinite) else {
            issues.append(.init(code: .valueDisagreement, runID: key.runID, fixtureID: key.fixtureID, domain: key.domain, fieldPath: fieldPath, detail: "reviewed numeric values must all be finite"))
            return nil
        }
        guard let rule = ruleIndex[spreadClass] else {
            issues.append(.init(code: .missingConsensusRule, runID: key.runID, fixtureID: key.fixtureID, domain: key.domain, fieldPath: fieldPath, detail: "HQ review policy has no spread rule for this numeric field class"))
            return nil
        }
        let sorted = values.sorted()
        let minimum = sorted.first!
        let maximum = sorted.last!
        let spread = maximum - minimum
        let within = spread <= rule.maximumAbsoluteSpread + 1e-12
        diagnostics.append(.init(runID: key.runID, fixtureID: key.fixtureID, domain: key.domain, fieldPath: fieldPath, reviewerCount: values.count, exactAgreement: spread <= 1e-12, observedMinimum: minimum, observedMaximum: maximum, observedSpread: spread, maximumAllowedSpread: rule.maximumAbsoluteSpread, anchorAgreement: true))
        guard within else {
            issues.append(.init(code: .valueDisagreement, runID: key.runID, fixtureID: key.fixtureID, domain: key.domain, fieldPath: fieldPath, detail: "reviewer value spread exceeds HQ-supplied tolerance"))
            return nil
        }
        return median(sorted)
    }

    private static func anchorConsensusDiagnostics(
        key: ReviewObservationKey,
        submissions: [AnalysisReferenceReviewSubmission],
        ruleIndex: [AnalysisReferenceReviewSpreadClass: AnalysisReferenceReviewConsensusRule],
        issues: inout [AnalysisReferenceReviewConsensusIssue]
    ) -> [AnalysisReferenceReviewFieldConsensusDiagnostic] {
        guard let first = submissions.first else { return [] }
        let paths = Set(requiredFieldPaths(first.observation))
        var diagnostics: [AnalysisReferenceReviewFieldConsensusDiagnostic] = []
        for path in paths.sorted() {
            let anchors = submissions.compactMap { submission in submission.anchors.first { $0.fieldPath == path } }
            guard anchors.count == submissions.count, let anchor = anchors.first else { continue }
            var agreed = true
            if !anchors.allSatisfy({ $0.artifactID == anchor.artifactID && $0.kind == anchor.kind }) {
                agreed = false
            } else {
                switch anchor.kind {
                case .timeRangeSeconds:
                    agreed = anchorNumericAgreement(anchors.compactMap(\.startSeconds), spreadClass: .anchorTimeSeconds, ruleIndex: ruleIndex, key: key, path: path, issues: &issues)
                        && anchorNumericAgreement(anchors.compactMap(\.endSeconds), spreadClass: .anchorTimeSeconds, ruleIndex: ruleIndex, key: key, path: path, issues: &issues)
                case .frameRange:
                    agreed = anchorNumericAgreement(anchors.compactMap { $0.startFrame.map(Double.init) }, spreadClass: .anchorFrameIndex, ruleIndex: ruleIndex, key: key, path: path, issues: &issues)
                        && anchorNumericAgreement(anchors.compactMap { $0.endFrame.map(Double.init) }, spreadClass: .anchorFrameIndex, ruleIndex: ruleIndex, key: key, path: path, issues: &issues)
                case .imageRegion, .pageRegion:
                    if anchor.kind == .pageRegion && !anchors.allSatisfy({ $0.pageIndex == anchor.pageIndex }) { agreed = false }
                    let regions = anchors.compactMap(\.region)
                    if regions.count != anchors.count { agreed = false }
                    if agreed {
                        let coordinateSeries = [regions.map(\.x), regions.map(\.y), regions.map(\.width), regions.map(\.height)]
                        for values in coordinateSeries {
                            if !anchorNumericAgreement(values, spreadClass: .anchorRegionCoordinate, ruleIndex: ruleIndex, key: key, path: path, issues: &issues) { agreed = false; break }
                        }
                    }
                }
            }
            if !agreed {
                issues.append(.init(code: .anchorDisagreement, runID: key.runID, fixtureID: key.fixtureID, domain: key.domain, fieldPath: path, detail: "reviewers did not independently anchor the field to the same artifact location within HQ tolerance"))
            }
            diagnostics.append(.init(runID: key.runID, fixtureID: key.fixtureID, domain: key.domain, fieldPath: "anchor:\(path)", reviewerCount: anchors.count, exactAgreement: agreed, observedMinimum: nil, observedMaximum: nil, observedSpread: nil, maximumAllowedSpread: nil, anchorAgreement: agreed))
        }
        return diagnostics
    }

    private static func anchorNumericAgreement(
        _ values: [Double],
        spreadClass: AnalysisReferenceReviewSpreadClass,
        ruleIndex: [AnalysisReferenceReviewSpreadClass: AnalysisReferenceReviewConsensusRule],
        key: ReviewObservationKey,
        path: String,
        issues: inout [AnalysisReferenceReviewConsensusIssue]
    ) -> Bool {
        guard !values.isEmpty, values.allSatisfy(\.isFinite) else { return false }
        guard let rule = ruleIndex[spreadClass] else {
            issues.append(.init(code: .missingConsensusRule, runID: key.runID, fixtureID: key.fixtureID, domain: key.domain, fieldPath: path, detail: "HQ review policy has no anchor spread rule"))
            return false
        }
        let spread = values.max()! - values.min()!
        return spread <= rule.maximumAbsoluteSpread + 1e-12
    }

    private static func unresolvedObservation(
        key: ReviewObservationKey,
        row: AnalysisReferenceCaptureRow,
        submissions: [AnalysisReferenceReviewSubmission],
        reason: String,
        fieldDiagnostics: [AnalysisReferenceReviewFieldConsensusDiagnostic] = []
    ) -> ConsensusResult {
        let evidence = Array(Set(submissions.flatMap { $0.observation.evidenceArtifactIDs })).sorted()
        let fallbackEvidence = evidence.isEmpty ? row.evidenceArtifactIDs.sorted() : evidence
        let limitations = Array(Set(submissions.flatMap { $0.observation.limitations } + [reason, "UNRESOLVED_REVIEW_CONSENSUS_NOT_W20_ADMISSIBLE"])).sorted()
        return .init(observation: .init(runID: key.runID, fixtureID: key.fixtureID, domain: key.domain, status: .unscorable, evidenceArtifactIDs: fallbackEvidence, limitations: limitations), resolved: false, fieldDiagnostics: fieldDiagnostics)
    }

    private static func requiredFieldPaths(_ observation: AnalysisReferenceRawObservation) -> [String] {
        var paths = ["status"]
        guard observation.status == .observed else { return paths }
        switch observation.domain {
        case "tempo": if observation.observedBPM != nil { paths.append("observed_bpm") }
        case "beat": for index in 0..<(observation.beatTimesSeconds?.count ?? 0) { paths.append("beat_times_seconds[\(index)]") }
        case "key":
            if observation.key != nil { paths.append("key.tonic_pitch_class"); paths.append("key.mode") }
        case "chord":
            for index in 0..<(observation.chords?.count ?? 0) {
                paths.append("chords[\(index)].start_seconds")
                paths.append("chords[\(index)].end_seconds")
                paths.append("chords[\(index)].normalized_label")
            }
        case "structure":
            for index in 0..<(observation.sections?.count ?? 0) {
                paths.append("sections[\(index)].start_seconds")
                paths.append("sections[\(index)].end_seconds")
                paths.append("sections[\(index)].structural_label")
                if observation.sections?[index].functionalLabel != nil { paths.append("sections[\(index)].functional_label") }
            }
        default: break
        }
        return paths
    }

    private static func anchorIsValid(_ anchor: AnalysisReferenceFieldEvidenceAnchor) -> Bool {
        if trimmed(anchor.fieldPath).isEmpty || trimmed(anchor.artifactID).isEmpty { return false }
        switch anchor.kind {
        case .timeRangeSeconds:
            guard let start = anchor.startSeconds, let end = anchor.endSeconds else { return false }
            return start.isFinite && end.isFinite && start >= 0 && end >= start && anchor.startFrame == nil && anchor.endFrame == nil && anchor.pageIndex == nil && anchor.region == nil
        case .frameRange:
            guard let start = anchor.startFrame, let end = anchor.endFrame else { return false }
            return start >= 0 && end >= start && anchor.startSeconds == nil && anchor.endSeconds == nil && anchor.pageIndex == nil && anchor.region == nil
        case .imageRegion:
            return anchor.startSeconds == nil && anchor.endSeconds == nil && anchor.startFrame == nil && anchor.endFrame == nil && anchor.pageIndex == nil && validRegion(anchor.region)
        case .pageRegion:
            guard let page = anchor.pageIndex, page >= 0 else { return false }
            return anchor.startSeconds == nil && anchor.endSeconds == nil && anchor.startFrame == nil && anchor.endFrame == nil && validRegion(anchor.region)
        }
    }

    private static func validRegion(_ region: AnalysisReferenceNormalizedRegion?) -> Bool {
        guard let region else { return false }
        let values = [region.x, region.y, region.width, region.height]
        guard values.allSatisfy(\.isFinite), region.x >= 0, region.y >= 0, region.width > 0, region.height > 0 else { return false }
        return region.x + region.width <= 1 + 1e-12 && region.y + region.height <= 1 + 1e-12
    }

    private static func payloadIsEmpty(_ observation: AnalysisReferenceRawObservation) -> Bool {
        observation.observedBPM == nil && observation.beatTimesSeconds == nil && observation.key == nil && observation.chords == nil && observation.sections == nil
    }

    private static func exactStringConsensus(_ values: [String]) -> String? {
        guard let first = values.first, !trimmed(first).isEmpty, values.allSatisfy({ $0 == first }) else { return nil }
        return first
    }

    private static func exactOptionalStringConsensus(_ values: [String?]) -> String?? {
        guard let first = values.first, values.allSatisfy({ $0 == first }) else { return nil }
        return .some(first)
    }

    private static func allPresent<T>(_ values: [T?]) -> [T]? {
        let output = values.compactMap { $0 }
        return output.count == values.count ? output : nil
    }

    private static func median(_ sorted: [Double]) -> Double {
        let middle = sorted.count / 2
        if sorted.count.isMultiple(of: 2) { return (sorted[middle - 1] + sorted[middle]) / 2 }
        return sorted[middle]
    }

    private static func exactFieldDiagnostic(key: ReviewObservationKey, fieldPath: String, reviewerCount: Int) -> AnalysisReferenceReviewFieldConsensusDiagnostic {
        .init(runID: key.runID, fixtureID: key.fixtureID, domain: key.domain, fieldPath: fieldPath, reviewerCount: reviewerCount, exactAgreement: true, observedMinimum: nil, observedMaximum: nil, observedSpread: 0, maximumAllowedSpread: 0, anchorAgreement: true)
    }

    private static func trimmed(_ value: String) -> String { value.trimmingCharacters(in: .whitespacesAndNewlines) }

    private static func isSHA256(_ value: String) -> Bool {
        guard value.count == 64 else { return false }
        return value.unicodeScalars.allSatisfy { scalar in (48...57).contains(scalar.value) || (97...102).contains(scalar.value) || (65...70).contains(scalar.value) }
    }

    private static func submissionOrder(_ lhs: AnalysisReferenceReviewSubmission, _ rhs: AnalysisReferenceReviewSubmission) -> Bool {
        if lhs.reviewerID != rhs.reviewerID { return lhs.reviewerID < rhs.reviewerID }
        return lhs.submissionID < rhs.submissionID
    }

    private static func fieldDiagnosticOrder(_ lhs: AnalysisReferenceReviewFieldConsensusDiagnostic, _ rhs: AnalysisReferenceReviewFieldConsensusDiagnostic) -> Bool {
        lhs.fieldPath < rhs.fieldPath
    }

    private static func observationDiagnosticOrder(_ lhs: AnalysisReferenceReviewObservationDiagnostic, _ rhs: AnalysisReferenceReviewObservationDiagnostic) -> Bool {
        if lhs.runID != rhs.runID { return lhs.runID < rhs.runID }
        if lhs.fixtureID != rhs.fixtureID { return lhs.fixtureID < rhs.fixtureID }
        return lhs.domain < rhs.domain
    }

    private static func rawObservationOrder(_ lhs: AnalysisReferenceRawObservation, _ rhs: AnalysisReferenceRawObservation) -> Bool {
        if lhs.runID != rhs.runID { return lhs.runID < rhs.runID }
        if lhs.fixtureID != rhs.fixtureID { return lhs.fixtureID < rhs.fixtureID }
        return lhs.domain < rhs.domain
    }

    private static func issueOrder(_ lhs: AnalysisReferenceReviewConsensusIssue, _ rhs: AnalysisReferenceReviewConsensusIssue) -> Bool {
        let left = "\(lhs.code.rawValue)|\(lhs.runID ?? "")|\(lhs.fixtureID ?? "")|\(lhs.domain ?? "")|\(lhs.fieldPath ?? "")|\(lhs.reviewerID ?? "")|\(lhs.detail)"
        let right = "\(rhs.code.rawValue)|\(rhs.runID ?? "")|\(rhs.fixtureID ?? "")|\(rhs.domain ?? "")|\(rhs.fieldPath ?? "")|\(rhs.reviewerID ?? "")|\(rhs.detail)"
        return left < right
    }
}

public enum AnalysisReferenceReviewConsensusCodec {
    public static func encodeReviewSet(_ value: AnalysisReferenceReviewSet) throws -> Data { try makeEncoder().encode(value) }
    public static func decodeReviewSet(_ data: Data) throws -> AnalysisReferenceReviewSet { try makeDecoder().decode(AnalysisReferenceReviewSet.self, from: data) }
    public static func encodePolicy(_ value: AnalysisReferenceReviewConsensusPolicy) throws -> Data { try makeEncoder().encode(value) }
    public static func decodePolicy(_ data: Data) throws -> AnalysisReferenceReviewConsensusPolicy { try makeDecoder().decode(AnalysisReferenceReviewConsensusPolicy.self, from: data) }
    public static func encodeReport(_ value: AnalysisReferenceReviewConsensusReport) throws -> Data { try makeEncoder().encode(value) }
    public static func decodeReport(_ data: Data) throws -> AnalysisReferenceReviewConsensusReport { try makeDecoder().decode(AnalysisReferenceReviewConsensusReport.self, from: data) }

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

private struct ReviewObservationKey: Hashable, Comparable {
    let runID: String
    let fixtureID: String
    let domain: String

    static func < (lhs: ReviewObservationKey, rhs: ReviewObservationKey) -> Bool {
        if lhs.runID != rhs.runID { return lhs.runID < rhs.runID }
        if lhs.fixtureID != rhs.fixtureID { return lhs.fixtureID < rhs.fixtureID }
        return lhs.domain < rhs.domain
    }
}

private struct ConsensusResult {
    let observation: AnalysisReferenceRawObservation
    let resolved: Bool
    let fieldDiagnostics: [AnalysisReferenceReviewFieldConsensusDiagnostic]
}

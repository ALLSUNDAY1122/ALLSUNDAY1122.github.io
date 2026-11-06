import Foundation

public enum AnalysisDifferentialGateStatus: String, Codable, Sendable {
    case invalidProfile = "INVALID_PROFILE"
    case incompletePairing = "INCOMPLETE_PAIRING"
    case outsideSuppliedTolerance = "OUTSIDE_SUPPLIED_TOLERANCE"
    case withinToleranceNonParityEvidence = "WITHIN_TOLERANCE_NON_PARITY_EVIDENCE"
    case withinSuppliedTolerancePendingHQ = "WITHIN_SUPPLIED_TOLERANCE_PENDING_HQ"
}

public enum AnalysisDifferentialIssueCode: String, Codable, Sendable {
    case invalidProfile = "INVALID_PROFILE"
    case manifestMismatch = "MANIFEST_MISMATCH"
    case engineMismatch = "ENGINE_MISMATCH"
    case reportValidationIssue = "REPORT_VALIDATION_ISSUE"
    case duplicateProjectRow = "DUPLICATE_PROJECT_ROW"
    case duplicateReferenceRow = "DUPLICATE_REFERENCE_ROW"
    case projectOnlyRow = "PROJECT_ONLY_ROW"
    case referenceOnlyRow = "REFERENCE_ONLY_ROW"
    case rowMetadataMismatch = "ROW_METADATA_MISMATCH"
    case projectEvaluatorRejected = "PROJECT_EVALUATOR_REJECTED"
    case referenceEvaluatorRejected = "REFERENCE_EVALUATOR_REJECTED"
    case projectOnlyMetric = "PROJECT_ONLY_METRIC"
    case referenceOnlyMetric = "REFERENCE_ONLY_METRIC"
    case missingToleranceRule = "MISSING_TOLERANCE_RULE"
    case requiredMetricAbsent = "REQUIRED_METRIC_ABSENT"
}

public struct AnalysisDifferentialToleranceRule: Codable, Equatable, Sendable {
    public let domain: String
    public let metric: String
    public let maximumRegression: Double
    public let required: Bool

    public init(domain: String, metric: String, maximumRegression: Double, required: Bool = true) {
        self.domain = domain
        self.metric = metric
        self.maximumRegression = maximumRegression
        self.required = required
    }
}

public struct AnalysisDifferentialToleranceProfile: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let profileID: String
    public let authority: String
    public let approvalReference: String
    public let approvedAt: Date
    public let expectedProjectEngine: String
    public let expectedReferenceEngine: String
    public let rules: [AnalysisDifferentialToleranceRule]

    public init(
        schemaVersion: Int = 1,
        profileID: String,
        authority: String,
        approvalReference: String,
        approvedAt: Date,
        expectedProjectEngine: String,
        expectedReferenceEngine: String,
        rules: [AnalysisDifferentialToleranceRule]
    ) {
        self.schemaVersion = schemaVersion
        self.profileID = profileID
        self.authority = authority
        self.approvalReference = approvalReference
        self.approvedAt = approvedAt
        self.expectedProjectEngine = expectedProjectEngine
        self.expectedReferenceEngine = expectedReferenceEngine
        self.rules = rules
    }
}

public struct AnalysisDifferentialProvenance: Codable, Equatable, Sendable {
    public let engine: String
    public let engineVersion: String
    public let manifestID: String
    public let generatedAt: Date
}

public struct AnalysisDifferentialIssue: Codable, Equatable, Sendable {
    public let code: AnalysisDifferentialIssueCode
    public let fixtureID: String?
    public let domain: String?
    public let metric: String?
    public let detail: String

    public init(
        code: AnalysisDifferentialIssueCode,
        fixtureID: String? = nil,
        domain: String? = nil,
        metric: String? = nil,
        detail: String
    ) {
        self.code = code
        self.fixtureID = fixtureID
        self.domain = domain
        self.metric = metric
        self.detail = detail
    }
}

public struct AnalysisDifferentialMetricPair: Codable, Equatable, Sendable {
    public let fixtureID: String
    public let domain: String
    public let genre: String
    public let metric: String
    public let direction: AnalysisBenchmarkMetricDirection
    public let projectValue: Double
    public let referenceValue: Double
    public let signedQualityDelta: Double
    public let regression: Double
    public let maximumRegression: Double?
    public let withinTolerance: Bool?
    public let parityCandidateEvidence: Bool
}

public struct AnalysisDifferentialWorstRegression: Codable, Equatable, Sendable {
    public let fixtureID: String
    public let genre: String
    public let regression: Double
    public let signedQualityDelta: Double
}

public struct AnalysisDifferentialMetricSummary: Codable, Equatable, Sendable {
    public let domain: String
    public let metric: String
    public let direction: AnalysisBenchmarkMetricDirection
    public let pairCount: Int
    public let parityCandidatePairCount: Int
    public let failedPairCount: Int
    public let maximumRegression: Double?
    public let worstRegression: AnalysisDifferentialWorstRegression?
}

public struct AnalysisPairedDifferentialReport: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let generatedAt: Date
    public let status: AnalysisDifferentialGateStatus
    public let comparisonComplete: Bool
    public let sameCorpusComplete: Bool
    public let metricPairingComplete: Bool
    public let allPairedEvidenceParityCandidate: Bool
    public let allWithinSuppliedTolerance: Bool
    public let finalParityAuthority: String
    public let toleranceProfile: AnalysisDifferentialToleranceProfile
    public let project: AnalysisDifferentialProvenance
    public let reference: AnalysisDifferentialProvenance
    public let pairs: [AnalysisDifferentialMetricPair]
    public let metricSummaries: [AnalysisDifferentialMetricSummary]
    public let issues: [AnalysisDifferentialIssue]

    public init(
        schemaVersion: Int = 1,
        generatedAt: Date,
        status: AnalysisDifferentialGateStatus,
        comparisonComplete: Bool,
        sameCorpusComplete: Bool,
        metricPairingComplete: Bool,
        allPairedEvidenceParityCandidate: Bool,
        allWithinSuppliedTolerance: Bool,
        finalParityAuthority: String = "HQ_LATE_INTEGRATION",
        toleranceProfile: AnalysisDifferentialToleranceProfile,
        project: AnalysisDifferentialProvenance,
        reference: AnalysisDifferentialProvenance,
        pairs: [AnalysisDifferentialMetricPair],
        metricSummaries: [AnalysisDifferentialMetricSummary],
        issues: [AnalysisDifferentialIssue]
    ) {
        self.schemaVersion = schemaVersion
        self.generatedAt = generatedAt
        self.status = status
        self.comparisonComplete = comparisonComplete
        self.sameCorpusComplete = sameCorpusComplete
        self.metricPairingComplete = metricPairingComplete
        self.allPairedEvidenceParityCandidate = allPairedEvidenceParityCandidate
        self.allWithinSuppliedTolerance = allWithinSuppliedTolerance
        self.finalParityAuthority = finalParityAuthority
        self.toleranceProfile = toleranceProfile
        self.project = project
        self.reference = reference
        self.pairs = pairs
        self.metricSummaries = metricSummaries
        self.issues = issues
    }
}

public enum AnalysisPairedDifferentialComparator {
    public static let requiredAuthority = "HQ_LATE_INTEGRATION"

    public static func compare(
        project: AnalysisAuditedRealAudioBenchmarkReport,
        reference: AnalysisAuditedRealAudioBenchmarkReport,
        profile: AnalysisDifferentialToleranceProfile,
        generatedAt: Date = Date()
    ) -> AnalysisPairedDifferentialReport {
        var issues = validateProfile(profile)
        if project.manifestID != reference.manifestID {
            issues.append(.init(
                code: .manifestMismatch,
                detail: "project and reference manifest_id must match exactly"
            ))
        }
        if project.engine != profile.expectedProjectEngine {
            issues.append(.init(
                code: .engineMismatch,
                detail: "project engine does not match tolerance profile"
            ))
        }
        if reference.engine != profile.expectedReferenceEngine {
            issues.append(.init(
                code: .engineMismatch,
                detail: "reference engine does not match tolerance profile"
            ))
        }
        if !project.validationIssues.isEmpty {
            issues.append(.init(
                code: .reportValidationIssue,
                detail: "project audited report contains validation issues"
            ))
        }
        if !reference.validationIssues.isEmpty {
            issues.append(.init(
                code: .reportValidationIssue,
                detail: "reference audited report contains validation issues"
            ))
        }

        let projectIndex = indexRows(project.rows, duplicateCode: .duplicateProjectRow, issues: &issues)
        let referenceIndex = indexRows(reference.rows, duplicateCode: .duplicateReferenceRow, issues: &issues)
        let projectKeys = Set(projectIndex.keys)
        let referenceKeys = Set(referenceIndex.keys)

        for key in projectKeys.subtracting(referenceKeys).sorted() {
            issues.append(.init(
                code: .projectOnlyRow,
                fixtureID: key.fixtureID,
                domain: key.domain,
                detail: "row exists only in project report"
            ))
        }
        for key in referenceKeys.subtracting(projectKeys).sorted() {
            issues.append(.init(
                code: .referenceOnlyRow,
                fixtureID: key.fixtureID,
                domain: key.domain,
                detail: "row exists only in reference report"
            ))
        }

        let ruleIndex = makeRuleIndex(profile.rules)
        var observedRuleKeys = Set<RuleKey>()
        var pairs: [AnalysisDifferentialMetricPair] = []
        let commonKeys = projectKeys.intersection(referenceKeys).sorted()

        for key in commonKeys {
            guard let projectRow = projectIndex[key], let referenceRow = referenceIndex[key] else { continue }
            let metadataMatches = projectRow.genre == referenceRow.genre
                && abs(projectRow.durationSeconds - referenceRow.durationSeconds) <= 0.001
                && projectRow.rightsClass == referenceRow.rightsClass
                && projectRow.syntheticOnly == referenceRow.syntheticOnly
            if !metadataMatches {
                issues.append(.init(
                    code: .rowMetadataMismatch,
                    fixtureID: key.fixtureID,
                    domain: key.domain,
                    detail: "genre/duration/rights/synthetic provenance differs across paired row"
                ))
            }

            let projectRejected = evaluatorRejected(projectRow)
            let referenceRejected = evaluatorRejected(referenceRow)
            if projectRejected {
                issues.append(.init(
                    code: .projectEvaluatorRejected,
                    fixtureID: key.fixtureID,
                    domain: key.domain,
                    detail: "project evaluator rejected this row"
                ))
            }
            if referenceRejected {
                issues.append(.init(
                    code: .referenceEvaluatorRejected,
                    fixtureID: key.fixtureID,
                    domain: key.domain,
                    detail: "reference evaluator rejected this row"
                ))
            }

            for metric in AnalysisBenchmarkAggregation.metricDirections.keys.sorted() {
                guard let direction = AnalysisBenchmarkAggregation.metricDirections[metric] else { continue }
                let projectValue = qualityValue(metric: metric, row: projectRow)
                let referenceValue = qualityValue(metric: metric, row: referenceRow)
                if projectValue == nil, referenceValue == nil { continue }

                let ruleKey = RuleKey(domain: key.domain, metric: metric)
                if projectValue != nil || referenceValue != nil {
                    observedRuleKeys.insert(ruleKey)
                }

                guard let projectValue else {
                    issues.append(.init(
                        code: .referenceOnlyMetric,
                        fixtureID: key.fixtureID,
                        domain: key.domain,
                        metric: metric,
                        detail: "quality metric exists only in reference row"
                    ))
                    continue
                }
                guard let referenceValue else {
                    issues.append(.init(
                        code: .projectOnlyMetric,
                        fixtureID: key.fixtureID,
                        domain: key.domain,
                        metric: metric,
                        detail: "quality metric exists only in project row"
                    ))
                    continue
                }

                let rule = ruleIndex[ruleKey]
                if rule == nil {
                    issues.append(.init(
                        code: .missingToleranceRule,
                        fixtureID: key.fixtureID,
                        domain: key.domain,
                        metric: metric,
                        detail: "paired quality metric has no externally supplied tolerance rule"
                    ))
                }

                let signedDelta: Double
                switch direction {
                case .higherIsBetter:
                    signedDelta = projectValue - referenceValue
                case .lowerIsBetter:
                    signedDelta = referenceValue - projectValue
                }
                let regression = max(0, -signedDelta)
                let maximumRegression = rule?.maximumRegression
                let withinTolerance = maximumRegression.map { regression <= $0 + 1e-12 }
                let parityCandidateEvidence = metadataMatches
                    && !projectRejected
                    && !referenceRejected
                    && projectRow.parityEligible
                    && referenceRow.parityEligible
                    && !projectRow.syntheticOnly
                    && !referenceRow.syntheticOnly

                pairs.append(.init(
                    fixtureID: key.fixtureID,
                    domain: key.domain,
                    genre: projectRow.genre,
                    metric: metric,
                    direction: direction,
                    projectValue: projectValue,
                    referenceValue: referenceValue,
                    signedQualityDelta: signedDelta,
                    regression: regression,
                    maximumRegression: maximumRegression,
                    withinTolerance: withinTolerance,
                    parityCandidateEvidence: parityCandidateEvidence
                ))
            }
        }

        for rule in profile.rules where rule.required {
            let key = RuleKey(domain: rule.domain, metric: rule.metric)
            if !observedRuleKeys.contains(key) {
                issues.append(.init(
                    code: .requiredMetricAbsent,
                    domain: rule.domain,
                    metric: rule.metric,
                    detail: "required tolerance-profile metric was absent from paired corpus"
                ))
            }
        }

        pairs.sort {
            if $0.fixtureID != $1.fixtureID { return $0.fixtureID < $1.fixtureID }
            if $0.domain != $1.domain { return $0.domain < $1.domain }
            return $0.metric < $1.metric
        }
        issues.sort(by: issueOrder)

        let profileInvalid = issues.contains { $0.code == .invalidProfile || $0.code == .engineMismatch }
        let sameCorpusIssueCodes: Set<AnalysisDifferentialIssueCode> = [
            .manifestMismatch, .duplicateProjectRow, .duplicateReferenceRow,
            .projectOnlyRow, .referenceOnlyRow, .rowMetadataMismatch,
            .reportValidationIssue, .projectEvaluatorRejected, .referenceEvaluatorRejected
        ]
        let metricIssueCodes: Set<AnalysisDifferentialIssueCode> = [
            .projectOnlyMetric, .referenceOnlyMetric, .missingToleranceRule, .requiredMetricAbsent
        ]
        let sameCorpusComplete = !issues.contains { sameCorpusIssueCodes.contains($0.code) }
        let metricPairingComplete = !issues.contains { metricIssueCodes.contains($0.code) }
        let comparisonComplete = !profileInvalid && sameCorpusComplete && metricPairingComplete && !pairs.isEmpty
        let allPairedEvidenceParityCandidate = !pairs.isEmpty && pairs.allSatisfy(\.parityCandidateEvidence)
        let toleranceEvaluatedPairs = pairs.filter { $0.withinTolerance != nil }
        let allWithinSuppliedTolerance = !toleranceEvaluatedPairs.isEmpty
            && toleranceEvaluatedPairs.count == pairs.count
            && toleranceEvaluatedPairs.allSatisfy { $0.withinTolerance == true }

        let status: AnalysisDifferentialGateStatus
        if profileInvalid {
            status = .invalidProfile
        } else if !comparisonComplete {
            status = .incompletePairing
        } else if !allWithinSuppliedTolerance {
            status = .outsideSuppliedTolerance
        } else if !allPairedEvidenceParityCandidate {
            status = .withinToleranceNonParityEvidence
        } else {
            status = .withinSuppliedTolerancePendingHQ
        }

        return AnalysisPairedDifferentialReport(
            generatedAt: generatedAt,
            status: status,
            comparisonComplete: comparisonComplete,
            sameCorpusComplete: sameCorpusComplete,
            metricPairingComplete: metricPairingComplete,
            allPairedEvidenceParityCandidate: allPairedEvidenceParityCandidate,
            allWithinSuppliedTolerance: allWithinSuppliedTolerance,
            toleranceProfile: profile,
            project: .init(
                engine: project.engine,
                engineVersion: project.engineVersion,
                manifestID: project.manifestID,
                generatedAt: project.generatedAt
            ),
            reference: .init(
                engine: reference.engine,
                engineVersion: reference.engineVersion,
                manifestID: reference.manifestID,
                generatedAt: reference.generatedAt
            ),
            pairs: pairs,
            metricSummaries: summarize(pairs),
            issues: issues
        )
    }

    private static func validateProfile(_ profile: AnalysisDifferentialToleranceProfile) -> [AnalysisDifferentialIssue] {
        var issues: [AnalysisDifferentialIssue] = []
        func invalid(_ detail: String, domain: String? = nil, metric: String? = nil) {
            issues.append(.init(code: .invalidProfile, domain: domain, metric: metric, detail: detail))
        }

        if profile.schemaVersion != 1 { invalid("schema_version must equal 1") }
        if profile.profileID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { invalid("profile_id is required") }
        if profile.authority != requiredAuthority { invalid("authority must be HQ_LATE_INTEGRATION") }
        if profile.approvalReference.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { invalid("approval_reference is required") }
        if profile.expectedProjectEngine.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { invalid("expected_project_engine is required") }
        if profile.expectedReferenceEngine.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { invalid("expected_reference_engine is required") }
        if profile.expectedProjectEngine == profile.expectedReferenceEngine { invalid("project and reference engine identifiers must differ") }
        if profile.rules.isEmpty { invalid("at least one tolerance rule is required") }

        var seen = Set<RuleKey>()
        for rule in profile.rules {
            let key = RuleKey(domain: rule.domain, metric: rule.metric)
            if rule.domain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                invalid("rule domain is required", metric: rule.metric)
            }
            guard AnalysisBenchmarkAggregation.metricDirections[rule.metric] != nil else {
                invalid("rule metric is not in W17 quality registry", domain: rule.domain, metric: rule.metric)
                continue
            }
            if !rule.maximumRegression.isFinite || rule.maximumRegression < 0 {
                invalid("maximum_regression must be finite and >= 0", domain: rule.domain, metric: rule.metric)
            }
            if !seen.insert(key).inserted {
                invalid("duplicate tolerance rule", domain: rule.domain, metric: rule.metric)
            }
        }
        return issues
    }

    private static func indexRows(
        _ rows: [AnalysisBenchmarkRow],
        duplicateCode: AnalysisDifferentialIssueCode,
        issues: inout [AnalysisDifferentialIssue]
    ) -> [RowKey: AnalysisBenchmarkRow] {
        var index: [RowKey: AnalysisBenchmarkRow] = [:]
        for row in rows {
            let key = RowKey(fixtureID: row.fixtureID, domain: row.domain)
            if index[key] != nil {
                issues.append(.init(
                    code: duplicateCode,
                    fixtureID: row.fixtureID,
                    domain: row.domain,
                    detail: "duplicate fixture/domain row prevents unambiguous pairing"
                ))
            } else {
                index[key] = row
            }
        }
        return index
    }

    private static func makeRuleIndex(_ rules: [AnalysisDifferentialToleranceRule]) -> [RuleKey: AnalysisDifferentialToleranceRule] {
        var index: [RuleKey: AnalysisDifferentialToleranceRule] = [:]
        for rule in rules where index[RuleKey(domain: rule.domain, metric: rule.metric)] == nil {
            index[RuleKey(domain: rule.domain, metric: rule.metric)] = rule
        }
        return index
    }

    private static func qualityValue(metric: String, row: AnalysisBenchmarkRow) -> Double? {
        if metric == "decision_emitted" {
            if let explicit = row.metrics[metric], explicit.isFinite { return explicit }
            if row.domain == "tempo", let value = row.metrics["predicted_bpm"], value.isFinite { return 1 }
            if row.domain == "key", let value = row.metrics["exact_key_accuracy"], value.isFinite { return 1 }
            return nil
        }
        guard let value = row.metrics[metric], value.isFinite else { return nil }
        return value
    }

    private static func evaluatorRejected(_ row: AnalysisBenchmarkRow) -> Bool {
        if let accepted = row.metrics["evaluator_input_accepted"], accepted.isFinite {
            return accepted < 0.5
        }
        return false
    }

    private static func summarize(_ pairs: [AnalysisDifferentialMetricPair]) -> [AnalysisDifferentialMetricSummary] {
        let groups = Dictionary(grouping: pairs) { RuleKey(domain: $0.domain, metric: $0.metric) }
        return groups.keys.sorted().compactMap { key in
            guard let values = groups[key], let first = values.first else { return nil }
            let evaluated = values.filter { $0.withinTolerance != nil }
            let failed = evaluated.filter { $0.withinTolerance == false }
            let worst = values.max {
                if $0.regression == $1.regression {
                    if $0.fixtureID == $1.fixtureID { return $0.genre > $1.genre }
                    return $0.fixtureID > $1.fixtureID
                }
                return $0.regression < $1.regression
            }
            return AnalysisDifferentialMetricSummary(
                domain: key.domain,
                metric: key.metric,
                direction: first.direction,
                pairCount: values.count,
                parityCandidatePairCount: values.filter(\.parityCandidateEvidence).count,
                failedPairCount: failed.count,
                maximumRegression: first.maximumRegression,
                worstRegression: worst.map {
                    AnalysisDifferentialWorstRegression(
                        fixtureID: $0.fixtureID,
                        genre: $0.genre,
                        regression: $0.regression,
                        signedQualityDelta: $0.signedQualityDelta
                    )
                }
            )
        }
    }

    private static func issueOrder(_ lhs: AnalysisDifferentialIssue, _ rhs: AnalysisDifferentialIssue) -> Bool {
        if lhs.code.rawValue != rhs.code.rawValue { return lhs.code.rawValue < rhs.code.rawValue }
        if lhs.fixtureID != rhs.fixtureID { return (lhs.fixtureID ?? "") < (rhs.fixtureID ?? "") }
        if lhs.domain != rhs.domain { return (lhs.domain ?? "") < (rhs.domain ?? "") }
        return (lhs.metric ?? "") < (rhs.metric ?? "")
    }

    private struct RowKey: Hashable, Comparable {
        let fixtureID: String
        let domain: String

        static func < (lhs: RowKey, rhs: RowKey) -> Bool {
            if lhs.fixtureID == rhs.fixtureID { return lhs.domain < rhs.domain }
            return lhs.fixtureID < rhs.fixtureID
        }
    }

    private struct RuleKey: Hashable, Comparable {
        let domain: String
        let metric: String

        static func < (lhs: RuleKey, rhs: RuleKey) -> Bool {
            if lhs.domain == rhs.domain { return lhs.metric < rhs.metric }
            return lhs.domain < rhs.domain
        }
    }
}

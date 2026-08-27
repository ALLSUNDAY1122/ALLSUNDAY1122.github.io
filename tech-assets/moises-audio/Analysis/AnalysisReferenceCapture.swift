import Foundation

public enum AnalysisReferenceCaptureObservationMethod: String, Codable, Sendable {
    case directUIObservation = "DIRECT_UI_OBSERVATION"
    case screenRecordingReview = "SCREEN_RECORDING_REVIEW"
    case exportedArtifactMeasurement = "EXPORTED_ARTIFACT_MEASUREMENT"
    case instrumentedMeasurement = "INSTRUMENTED_MEASUREMENT"
}

public struct AnalysisReferenceCaptureEnvironment: Codable, Equatable, Sendable {
    public let productName: String
    public let appVersion: String
    public let buildVersion: String
    public let deviceModel: String
    public let osVersion: String
    public let locale: String
    public let accountTier: String

    public init(productName: String, appVersion: String, buildVersion: String, deviceModel: String, osVersion: String, locale: String, accountTier: String) {
        self.productName = productName
        self.appVersion = appVersion
        self.buildVersion = buildVersion
        self.deviceModel = deviceModel
        self.osVersion = osVersion
        self.locale = locale
        self.accountTier = accountTier
    }
}

public struct AnalysisReferenceCaptureSourceBinding: Codable, Equatable, Sendable {
    public let manifestID: String
    public let manifestSHA256: String

    public init(manifestID: String, manifestSHA256: String) {
        self.manifestID = manifestID
        self.manifestSHA256 = manifestSHA256.lowercased()
    }
}

public struct AnalysisReferenceCaptureArtifact: Codable, Equatable, Sendable {
    public let artifactID: String
    public let sha256: String
    public let mediaType: String

    public init(artifactID: String, sha256: String, mediaType: String) {
        self.artifactID = artifactID
        self.sha256 = sha256.lowercased()
        self.mediaType = mediaType
    }
}

public struct AnalysisReferenceCaptureRow: Codable, Equatable, Sendable {
    public let fixtureID: String
    public let rightsClass: AnalysisRightsClass
    public let genre: String
    public let durationSeconds: Double
    public let syntheticOnly: Bool
    public let domain: String
    public let qualityMetrics: [String: Double]
    public let evidenceArtifactIDs: [String]

    public init(fixtureID: String, rightsClass: AnalysisRightsClass, genre: String, durationSeconds: Double, syntheticOnly: Bool, domain: String, qualityMetrics: [String: Double], evidenceArtifactIDs: [String]) {
        self.fixtureID = fixtureID
        self.rightsClass = rightsClass
        self.genre = genre
        self.durationSeconds = durationSeconds
        self.syntheticOnly = syntheticOnly
        self.domain = domain
        self.qualityMetrics = qualityMetrics
        self.evidenceArtifactIDs = evidenceArtifactIDs
    }
}

public struct AnalysisReferenceCaptureRun: Codable, Equatable, Sendable {
    public let runID: String
    public let operatorID: String
    public let capturedAt: Date
    public let environment: AnalysisReferenceCaptureEnvironment
    public let sourceBinding: AnalysisReferenceCaptureSourceBinding
    public let observationMethod: AnalysisReferenceCaptureObservationMethod
    public let artifacts: [AnalysisReferenceCaptureArtifact]
    public let rows: [AnalysisReferenceCaptureRow]

    public init(runID: String, operatorID: String, capturedAt: Date, environment: AnalysisReferenceCaptureEnvironment, sourceBinding: AnalysisReferenceCaptureSourceBinding, observationMethod: AnalysisReferenceCaptureObservationMethod, artifacts: [AnalysisReferenceCaptureArtifact], rows: [AnalysisReferenceCaptureRow]) {
        self.runID = runID
        self.operatorID = operatorID
        self.capturedAt = capturedAt
        self.environment = environment
        self.sourceBinding = sourceBinding
        self.observationMethod = observationMethod
        self.artifacts = artifacts
        self.rows = rows
    }
}

public struct AnalysisReferenceCaptureSet: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let captureSetID: String
    public let createdAt: Date
    public let runs: [AnalysisReferenceCaptureRun]

    public init(schemaVersion: Int = 1, captureSetID: String, createdAt: Date, runs: [AnalysisReferenceCaptureRun]) {
        self.schemaVersion = schemaVersion
        self.captureSetID = captureSetID
        self.createdAt = createdAt
        self.runs = runs
    }
}

public struct AnalysisReferenceRepeatabilityRule: Codable, Equatable, Sendable {
    public let domain: String
    public let metric: String
    public let maximumAbsoluteSpread: Double
    public let required: Bool

    public init(domain: String, metric: String, maximumAbsoluteSpread: Double, required: Bool = true) {
        self.domain = domain
        self.metric = metric
        self.maximumAbsoluteSpread = maximumAbsoluteSpread
        self.required = required
    }
}

public struct AnalysisReferenceCapturePolicy: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let policyID: String
    public let authority: String
    public let approvalReference: String
    public let referenceEpochNotBefore: Date
    public let expectedProductName: String
    public let expectedAppVersion: String
    public let expectedBuildVersion: String
    public let expectedDeviceModel: String
    public let expectedOSVersion: String
    public let expectedLocale: String
    public let expectedAccountTier: String
    public let expectedSourceManifestID: String
    public let expectedSourceManifestSHA256: String
    public let minimumRepeatRuns: Int
    public let repeatabilityRules: [AnalysisReferenceRepeatabilityRule]

    public init(schemaVersion: Int = 1, policyID: String, authority: String, approvalReference: String, referenceEpochNotBefore: Date, expectedProductName: String, expectedAppVersion: String, expectedBuildVersion: String, expectedDeviceModel: String, expectedOSVersion: String, expectedLocale: String, expectedAccountTier: String, expectedSourceManifestID: String, expectedSourceManifestSHA256: String, minimumRepeatRuns: Int, repeatabilityRules: [AnalysisReferenceRepeatabilityRule]) {
        self.schemaVersion = schemaVersion
        self.policyID = policyID
        self.authority = authority
        self.approvalReference = approvalReference
        self.referenceEpochNotBefore = referenceEpochNotBefore
        self.expectedProductName = expectedProductName
        self.expectedAppVersion = expectedAppVersion
        self.expectedBuildVersion = expectedBuildVersion
        self.expectedDeviceModel = expectedDeviceModel
        self.expectedOSVersion = expectedOSVersion
        self.expectedLocale = expectedLocale
        self.expectedAccountTier = expectedAccountTier
        self.expectedSourceManifestID = expectedSourceManifestID
        self.expectedSourceManifestSHA256 = expectedSourceManifestSHA256.lowercased()
        self.minimumRepeatRuns = minimumRepeatRuns
        self.repeatabilityRules = repeatabilityRules
    }
}

public enum AnalysisReferenceCaptureIssueCode: String, Codable, Hashable, Sendable {
    case invalidPolicy = "INVALID_POLICY"
    case invalidCaptureSet = "INVALID_CAPTURE_SET"
    case staleCapture = "STALE_CAPTURE"
    case futureCapture = "FUTURE_CAPTURE"
    case environmentMismatch = "ENVIRONMENT_MISMATCH"
    case sourceBindingMismatch = "SOURCE_BINDING_MISMATCH"
    case duplicateRunID = "DUPLICATE_RUN_ID"
    case missingOperatorID = "MISSING_OPERATOR_ID"
    case duplicateArtifactID = "DUPLICATE_ARTIFACT_ID"
    case invalidArtifact = "INVALID_ARTIFACT"
    case duplicateRow = "DUPLICATE_ROW"
    case rowSetMismatch = "ROW_SET_MISMATCH"
    case rowMetadataMismatch = "ROW_METADATA_MISMATCH"
    case metricSetMismatch = "METRIC_SET_MISMATCH"
    case nonFiniteMetric = "NON_FINITE_METRIC"
    case unknownQualityMetric = "UNKNOWN_QUALITY_METRIC"
    case missingRepeatabilityRule = "MISSING_REPEATABILITY_RULE"
    case requiredMetricAbsent = "REQUIRED_METRIC_ABSENT"
    case repeatabilityExceeded = "REPEATABILITY_EXCEEDED"
    case syntheticCaptureNotReferenceEvidence = "SYNTHETIC_CAPTURE_NOT_REFERENCE_EVIDENCE"
    case missingEvidenceArtifact = "MISSING_EVIDENCE_ARTIFACT"
}

public struct AnalysisReferenceCaptureIssue: Codable, Equatable, Sendable {
    public let code: AnalysisReferenceCaptureIssueCode
    public let runID: String?
    public let fixtureID: String?
    public let domain: String?
    public let metric: String?
    public let detail: String

    public init(code: AnalysisReferenceCaptureIssueCode, runID: String? = nil, fixtureID: String? = nil, domain: String? = nil, metric: String? = nil, detail: String) {
        self.code = code
        self.runID = runID
        self.fixtureID = fixtureID
        self.domain = domain
        self.metric = metric
        self.detail = detail
    }
}

public struct AnalysisReferenceMetricRepeatabilityDiagnostic: Codable, Equatable, Sendable {
    public let fixtureID: String
    public let domain: String
    public let metric: String
    public let runCount: Int
    public let minimum: Double
    public let maximum: Double
    public let mean: Double
    public let median: Double
    public let absoluteSpread: Double
    public let maximumAllowedSpread: Double?
    public let exactAgreement: Bool
    public let withinSuppliedRepeatabilityTolerance: Bool?
}

public enum AnalysisReferenceCaptureValidationStatus: String, Codable, Sendable {
    case invalid = "INVALID"
    case stablePendingHQ = "STABLE_REFERENCE_CAPTURE_PENDING_HQ"
}

public struct AnalysisReferenceCaptureValidationReport: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let generatedAt: Date
    public let captureSetID: String
    public let policyID: String
    public let status: AnalysisReferenceCaptureValidationStatus
    public let comparisonReady: Bool
    public let runCount: Int
    public let diagnostics: [AnalysisReferenceMetricRepeatabilityDiagnostic]
    public let issues: [AnalysisReferenceCaptureIssue]

    public init(schemaVersion: Int = 1, generatedAt: Date, captureSetID: String, policyID: String, status: AnalysisReferenceCaptureValidationStatus, comparisonReady: Bool, runCount: Int, diagnostics: [AnalysisReferenceMetricRepeatabilityDiagnostic], issues: [AnalysisReferenceCaptureIssue]) {
        self.schemaVersion = schemaVersion
        self.generatedAt = generatedAt
        self.captureSetID = captureSetID
        self.policyID = policyID
        self.status = status
        self.comparisonReady = comparisonReady
        self.runCount = runCount
        self.diagnostics = diagnostics
        self.issues = issues
    }
}

public enum AnalysisReferenceCaptureCompilerError: Error, Equatable, Sendable {
    case invalidCapture([AnalysisReferenceCaptureIssue])
}

public enum AnalysisReferenceCaptureValidator {
    public static let requiredAuthority = "HQ_LATE_INTEGRATION"

    public static func validate(captureSet: AnalysisReferenceCaptureSet, policy: AnalysisReferenceCapturePolicy, evaluatedAt: Date = Date()) -> AnalysisReferenceCaptureValidationReport {
        var issues = validatePolicy(policy)
        if captureSet.schemaVersion != 1 || trimmed(captureSet.captureSetID).isEmpty {
            issues.append(.init(code: .invalidCaptureSet, detail: "capture set schema/version/id is invalid"))
        }
        if captureSet.runs.count < policy.minimumRepeatRuns {
            issues.append(.init(code: .invalidCaptureSet, detail: "capture set does not satisfy minimum_repeat_runs"))
        }

        var runIDs = Set<String>()
        var baselineRows: [RowKey: AnalysisReferenceCaptureRow]?
        var observedRuleKeys = Set<RuleKey>()
        var valuesByMetricKey: [MetricKey: [Double]] = [:]
        let ruleIndex = makeRuleIndex(policy.repeatabilityRules)

        for run in captureSet.runs {
            let runID = trimmed(run.runID)
            if runID.isEmpty || !runIDs.insert(runID).inserted {
                issues.append(.init(code: .duplicateRunID, runID: run.runID, detail: "run_id must be non-empty and unique"))
            }
            if trimmed(run.operatorID).isEmpty {
                issues.append(.init(code: .missingOperatorID, runID: run.runID, detail: "operator_id is required"))
            }
            if run.capturedAt < policy.referenceEpochNotBefore {
                issues.append(.init(code: .staleCapture, runID: run.runID, detail: "capture predates HQ reference epoch"))
            }
            if run.capturedAt > evaluatedAt.addingTimeInterval(1) {
                issues.append(.init(code: .futureCapture, runID: run.runID, detail: "capture timestamp is in the future"))
            }
            if !environmentMatches(run.environment, policy: policy) {
                issues.append(.init(code: .environmentMismatch, runID: run.runID, detail: "product/app build/device/OS/locale/tier does not match HQ capture policy"))
            }
            if run.sourceBinding.manifestID != policy.expectedSourceManifestID || run.sourceBinding.manifestSHA256.caseInsensitiveCompare(policy.expectedSourceManifestSHA256) != .orderedSame || !isSHA256(run.sourceBinding.manifestSHA256) {
                issues.append(.init(code: .sourceBindingMismatch, runID: run.runID, detail: "source manifest identity/hash does not match HQ capture policy"))
            }

            var artifactIDs = Set<String>()
            for artifact in run.artifacts {
                let artifactID = trimmed(artifact.artifactID)
                if artifactID.isEmpty || !artifactIDs.insert(artifactID).inserted {
                    issues.append(.init(code: .duplicateArtifactID, runID: run.runID, detail: "artifact_id must be non-empty and unique within run"))
                }
                if !isSHA256(artifact.sha256) || trimmed(artifact.mediaType).isEmpty {
                    issues.append(.init(code: .invalidArtifact, runID: run.runID, detail: "artifact sha256/media_type is invalid"))
                }
            }
            if run.artifacts.isEmpty {
                issues.append(.init(code: .invalidArtifact, runID: run.runID, detail: "at least one evidence artifact is required per run"))
            }

            var rowIndex: [RowKey: AnalysisReferenceCaptureRow] = [:]
            for row in run.rows {
                let key = RowKey(fixtureID: row.fixtureID, domain: row.domain)
                if rowIndex[key] != nil {
                    issues.append(.init(code: .duplicateRow, runID: run.runID, fixtureID: row.fixtureID, domain: row.domain, detail: "fixture/domain row must be unique within run"))
                    continue
                }
                rowIndex[key] = row
                if trimmed(row.fixtureID).isEmpty || trimmed(row.genre).isEmpty || trimmed(row.domain).isEmpty || !row.durationSeconds.isFinite || row.durationSeconds <= 0 {
                    issues.append(.init(code: .rowMetadataMismatch, runID: run.runID, fixtureID: row.fixtureID, domain: row.domain, detail: "row identity/genre/duration/domain is invalid"))
                }
                if row.syntheticOnly {
                    issues.append(.init(code: .syntheticCaptureNotReferenceEvidence, runID: run.runID, fixtureID: row.fixtureID, domain: row.domain, detail: "synthetic capture cannot become current-iPhone Reference evidence"))
                }
                if row.qualityMetrics.isEmpty {
                    issues.append(.init(code: .metricSetMismatch, runID: run.runID, fixtureID: row.fixtureID, domain: row.domain, detail: "quality_metrics cannot be empty"))
                }
                for (metric, value) in row.qualityMetrics {
                    if !value.isFinite {
                        issues.append(.init(code: .nonFiniteMetric, runID: run.runID, fixtureID: row.fixtureID, domain: row.domain, metric: metric, detail: "quality metric must be finite"))
                    }
                    if AnalysisBenchmarkAggregation.metricDirections[metric] == nil {
                        issues.append(.init(code: .unknownQualityMetric, runID: run.runID, fixtureID: row.fixtureID, domain: row.domain, metric: metric, detail: "metric is not in W17 quality registry"))
                    }
                    let ruleKey = RuleKey(domain: row.domain, metric: metric)
                    observedRuleKeys.insert(ruleKey)
                    if ruleIndex[ruleKey] == nil {
                        issues.append(.init(code: .missingRepeatabilityRule, runID: run.runID, fixtureID: row.fixtureID, domain: row.domain, metric: metric, detail: "observed metric has no HQ-supplied repeatability rule"))
                    }
                    valuesByMetricKey[MetricKey(row: key, metric: metric), default: []].append(value)
                }
                let referencedArtifacts = Set(row.evidenceArtifactIDs)
                if referencedArtifacts.isEmpty || !referencedArtifacts.isSubset(of: artifactIDs) {
                    issues.append(.init(code: .missingEvidenceArtifact, runID: run.runID, fixtureID: row.fixtureID, domain: row.domain, detail: "row must reference evidence artifacts present in the same run"))
                }
            }
            if run.rows.isEmpty {
                issues.append(.init(code: .invalidCaptureSet, runID: run.runID, detail: "capture run must contain rows"))
            }

            if let baselineRows {
                let baselineKeys = Set(baselineRows.keys)
                let currentKeys = Set(rowIndex.keys)
                if baselineKeys != currentKeys {
                    issues.append(.init(code: .rowSetMismatch, runID: run.runID, detail: "all repeat runs must contain the exact same fixture/domain row set"))
                }
                for key in baselineKeys.intersection(currentKeys).sorted() {
                    guard let baseline = baselineRows[key], let current = rowIndex[key] else { continue }
                    if !sameMetadata(baseline, current) {
                        issues.append(.init(code: .rowMetadataMismatch, runID: run.runID, fixtureID: key.fixtureID, domain: key.domain, detail: "row metadata differs across repeat runs"))
                    }
                    if Set(baseline.qualityMetrics.keys) != Set(current.qualityMetrics.keys) {
                        issues.append(.init(code: .metricSetMismatch, runID: run.runID, fixtureID: key.fixtureID, domain: key.domain, detail: "quality metric set differs across repeat runs"))
                    }
                }
            } else {
                baselineRows = rowIndex
            }
        }

        for rule in policy.repeatabilityRules where rule.required {
            let key = RuleKey(domain: rule.domain, metric: rule.metric)
            if !observedRuleKeys.contains(key) {
                issues.append(.init(code: .requiredMetricAbsent, domain: rule.domain, metric: rule.metric, detail: "required repeatability metric is absent from capture set"))
            }
        }

        var diagnostics: [AnalysisReferenceMetricRepeatabilityDiagnostic] = []
        for metricKey in valuesByMetricKey.keys.sorted() {
            let values = (valuesByMetricKey[metricKey] ?? []).filter(\.isFinite)
            guard !values.isEmpty else { continue }
            let sortedValues = values.sorted()
            let minValue = sortedValues.first!
            let maxValue = sortedValues.last!
            let spread = maxValue - minValue
            let mean = sortedValues.reduce(0, +) / Double(sortedValues.count)
            let median = medianOfSorted(sortedValues)
            let rule = ruleIndex[RuleKey(domain: metricKey.row.domain, metric: metricKey.metric)]
            let within = rule.map { spread <= $0.maximumAbsoluteSpread + 1e-12 }
            diagnostics.append(.init(fixtureID: metricKey.row.fixtureID, domain: metricKey.row.domain, metric: metricKey.metric, runCount: sortedValues.count, minimum: minValue, maximum: maxValue, mean: mean, median: median, absoluteSpread: spread, maximumAllowedSpread: rule?.maximumAbsoluteSpread, exactAgreement: spread <= 1e-12, withinSuppliedRepeatabilityTolerance: within))
            if sortedValues.count != captureSet.runs.count {
                issues.append(.init(code: .metricSetMismatch, fixtureID: metricKey.row.fixtureID, domain: metricKey.row.domain, metric: metricKey.metric, detail: "metric is not present exactly once in every repeat run"))
            }
            if within == false {
                issues.append(.init(code: .repeatabilityExceeded, fixtureID: metricKey.row.fixtureID, domain: metricKey.row.domain, metric: metricKey.metric, detail: "observed repeat-run spread exceeds HQ-supplied tolerance"))
            }
        }

        issues.sort(by: issueOrder)
        diagnostics.sort {
            if $0.fixtureID != $1.fixtureID { return $0.fixtureID < $1.fixtureID }
            if $0.domain != $1.domain { return $0.domain < $1.domain }
            return $0.metric < $1.metric
        }
        let comparisonReady = issues.isEmpty && !diagnostics.isEmpty
        return AnalysisReferenceCaptureValidationReport(generatedAt: evaluatedAt, captureSetID: captureSet.captureSetID, policyID: policy.policyID, status: comparisonReady ? .stablePendingHQ : .invalid, comparisonReady: comparisonReady, runCount: captureSet.runs.count, diagnostics: diagnostics, issues: issues)
    }

    public static func compileAuditedReferenceReport(captureSet: AnalysisReferenceCaptureSet, policy: AnalysisReferenceCapturePolicy, evaluatedAt: Date = Date(), engine: String = "current-iphone-moises-reference") throws -> AnalysisAuditedRealAudioBenchmarkReport {
        let validation = validate(captureSet: captureSet, policy: policy, evaluatedAt: evaluatedAt)
        guard validation.comparisonReady, let firstRun = captureSet.runs.first else {
            throw AnalysisReferenceCaptureCompilerError.invalidCapture(validation.issues)
        }
        let rowsByKey = Dictionary(uniqueKeysWithValues: firstRun.rows.map { (RowKey(fixtureID: $0.fixtureID, domain: $0.domain), $0) })
        var outputRows: [AnalysisBenchmarkRow] = []
        for key in rowsByKey.keys.sorted() {
            guard let template = rowsByKey[key] else { continue }
            var metrics: [String: Double] = [:]
            for metric in template.qualityMetrics.keys.sorted() {
                let values = captureSet.runs.compactMap { run in
                    run.rows.first { $0.fixtureID == key.fixtureID && $0.domain == key.domain }?.qualityMetrics[metric]
                }.sorted()
                guard !values.isEmpty else { continue }
                metrics[metric] = medianOfSorted(values)
            }
            outputRows.append(AnalysisBenchmarkRow(fixtureID: template.fixtureID, rightsClass: template.rightsClass, genre: template.genre, durationSeconds: template.durationSeconds, syntheticOnly: template.syntheticOnly, parityEligible: !template.syntheticOnly, engine: engine, engineVersion: referenceEngineVersion(captureSet: captureSet, policy: policy), domain: template.domain, metrics: metrics, wallSeconds: 0, rtf: nil, peakRSSMB: nil, thermal: nil, knownLimitations: ["REFERENCE_CAPTURE_CONSENSUS_MEDIAN_\(captureSet.runs.count)_RUNS", "REFERENCE_CAPTURE_WALL_TIME_NOT_MEASURED", "FINAL_PARITY_HQ_ONLY"]))
        }
        let generatedAt = captureSet.runs.map(\.capturedAt).max() ?? evaluatedAt
        return AnalysisAuditedRealAudioBenchmarkReport(manifestID: policy.expectedSourceManifestID, generatedAt: generatedAt, engine: engine, engineVersion: referenceEngineVersion(captureSet: captureSet, policy: policy), parityEligible: outputRows.allSatisfy(\.parityEligible), rows: outputRows, domainQualitySummaries: AnalysisBenchmarkAggregation.domainSummaries(rows: outputRows), genreQualitySummaries: AnalysisBenchmarkAggregation.genreSummaries(rows: outputRows), evaluatorRejectedRows: [], nonParityRows: AnalysisBenchmarkAggregation.nonParityRows(rows: outputRows), excludedContextMetricNames: [], validationIssues: [])
    }

    private static func validatePolicy(_ policy: AnalysisReferenceCapturePolicy) -> [AnalysisReferenceCaptureIssue] {
        var issues: [AnalysisReferenceCaptureIssue] = []
        func invalid(_ detail: String, domain: String? = nil, metric: String? = nil) { issues.append(.init(code: .invalidPolicy, domain: domain, metric: metric, detail: detail)) }
        if policy.schemaVersion != 1 { invalid("unsupported policy schema_version") }
        if trimmed(policy.policyID).isEmpty { invalid("policy_id is required") }
        if policy.authority != requiredAuthority { invalid("authority must be HQ_LATE_INTEGRATION") }
        if trimmed(policy.approvalReference).isEmpty { invalid("approval_reference is required") }
        let requiredStrings = [policy.expectedProductName, policy.expectedAppVersion, policy.expectedBuildVersion, policy.expectedDeviceModel, policy.expectedOSVersion, policy.expectedLocale, policy.expectedAccountTier, policy.expectedSourceManifestID]
        if requiredStrings.contains(where: { trimmed($0).isEmpty }) { invalid("all expected environment/source fields are required") }
        if !isSHA256(policy.expectedSourceManifestSHA256) { invalid("expected_source_manifest_sha256 must be a SHA-256 hex digest") }
        if policy.minimumRepeatRuns < 2 { invalid("minimum_repeat_runs must be at least 2") }
        if policy.repeatabilityRules.isEmpty { invalid("repeatability_rules cannot be empty") }
        var seen = Set<RuleKey>()
        for rule in policy.repeatabilityRules {
            let key = RuleKey(domain: rule.domain, metric: rule.metric)
            if trimmed(rule.domain).isEmpty || AnalysisBenchmarkAggregation.metricDirections[rule.metric] == nil { invalid("repeatability rule domain/metric is invalid", domain: rule.domain, metric: rule.metric) }
            if !rule.maximumAbsoluteSpread.isFinite || rule.maximumAbsoluteSpread < 0 { invalid("maximum_absolute_spread must be finite and non-negative", domain: rule.domain, metric: rule.metric) }
            if !seen.insert(key).inserted { invalid("duplicate repeatability rule", domain: rule.domain, metric: rule.metric) }
        }
        return issues
    }

    private static func environmentMatches(_ environment: AnalysisReferenceCaptureEnvironment, policy: AnalysisReferenceCapturePolicy) -> Bool {
        environment.productName == policy.expectedProductName && environment.appVersion == policy.expectedAppVersion && environment.buildVersion == policy.expectedBuildVersion && environment.deviceModel == policy.expectedDeviceModel && environment.osVersion == policy.expectedOSVersion && environment.locale == policy.expectedLocale && environment.accountTier == policy.expectedAccountTier
    }

    private static func sameMetadata(_ lhs: AnalysisReferenceCaptureRow, _ rhs: AnalysisReferenceCaptureRow) -> Bool {
        lhs.rightsClass == rhs.rightsClass && lhs.genre == rhs.genre && abs(lhs.durationSeconds - rhs.durationSeconds) <= 0.001 && lhs.syntheticOnly == rhs.syntheticOnly
    }

    private static func makeRuleIndex(_ rules: [AnalysisReferenceRepeatabilityRule]) -> [RuleKey: AnalysisReferenceRepeatabilityRule] {
        var result: [RuleKey: AnalysisReferenceRepeatabilityRule] = [:]
        for rule in rules { let key = RuleKey(domain: rule.domain, metric: rule.metric); if result[key] == nil { result[key] = rule } }
        return result
    }

    private static func referenceEngineVersion(captureSet: AnalysisReferenceCaptureSet, policy: AnalysisReferenceCapturePolicy) -> String {
        "\(policy.expectedAppVersion)(\(policy.expectedBuildVersion))|\(policy.expectedDeviceModel)|iOS \(policy.expectedOSVersion)|capture=\(captureSet.captureSetID)"
    }

    private static func medianOfSorted(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        let middle = values.count / 2
        if values.count % 2 == 1 { return values[middle] }
        return (values[middle - 1] + values[middle]) / 2
    }

    private static func trimmed(_ value: String) -> String { value.trimmingCharacters(in: .whitespacesAndNewlines) }

    private static func isSHA256(_ value: String) -> Bool {
        guard value.count == 64 else { return false }
        return value.unicodeScalars.allSatisfy { scalar in (48...57).contains(scalar.value) || (97...102).contains(scalar.value) || (65...70).contains(scalar.value) }
    }

    private static func issueOrder(_ lhs: AnalysisReferenceCaptureIssue, _ rhs: AnalysisReferenceCaptureIssue) -> Bool {
        let left = "\(lhs.code.rawValue)|\(lhs.runID ?? "")|\(lhs.fixtureID ?? "")|\(lhs.domain ?? "")|\(lhs.metric ?? "")|\(lhs.detail)"
        let right = "\(rhs.code.rawValue)|\(rhs.runID ?? "")|\(rhs.fixtureID ?? "")|\(rhs.domain ?? "")|\(rhs.metric ?? "")|\(rhs.detail)"
        return left < right
    }

    private struct RowKey: Hashable, Comparable {
        let fixtureID: String
        let domain: String
        static func < (lhs: RowKey, rhs: RowKey) -> Bool { lhs.fixtureID == rhs.fixtureID ? lhs.domain < rhs.domain : lhs.fixtureID < rhs.fixtureID }
    }
    private struct RuleKey: Hashable { let domain: String; let metric: String }
    private struct MetricKey: Hashable, Comparable {
        let row: RowKey
        let metric: String
        static func < (lhs: MetricKey, rhs: MetricKey) -> Bool { lhs.row == rhs.row ? lhs.metric < rhs.metric : lhs.row < rhs.row }
    }
}

public enum AnalysisReferenceCaptureCodec {
    public static func encodeCaptureSet(_ captureSet: AnalysisReferenceCaptureSet) throws -> Data { try makeEncoder().encode(captureSet) }
    public static func decodeCaptureSet(_ data: Data) throws -> AnalysisReferenceCaptureSet { try makeDecoder().decode(AnalysisReferenceCaptureSet.self, from: data) }
    public static func encodePolicy(_ policy: AnalysisReferenceCapturePolicy) throws -> Data { try makeEncoder().encode(policy) }
    public static func decodePolicy(_ data: Data) throws -> AnalysisReferenceCapturePolicy { try makeDecoder().decode(AnalysisReferenceCapturePolicy.self, from: data) }
    public static func encodeValidationReport(_ report: AnalysisReferenceCaptureValidationReport) throws -> Data { try makeEncoder().encode(report) }
    public static func decodeValidationReport(_ data: Data) throws -> AnalysisReferenceCaptureValidationReport { try makeDecoder().decode(AnalysisReferenceCaptureValidationReport.self, from: data) }

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

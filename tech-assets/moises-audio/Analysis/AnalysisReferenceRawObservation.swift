import Foundation

public enum AnalysisReferenceRawObservationStatus: String, Codable, Sendable {
    case observed = "OBSERVED"
    case noDecision = "NO_DECISION"
    case unsupported = "UNSUPPORTED"
    case unscorable = "UNSCORABLE"
}

public struct AnalysisReferenceObservedKey: Codable, Equatable, Sendable {
    public let tonicPitchClass: Int
    public let mode: String
    public init(tonicPitchClass: Int, mode: String) {
        self.tonicPitchClass = tonicPitchClass
        self.mode = mode
    }
}

public struct AnalysisReferenceObservedChord: Codable, Equatable, Sendable {
    public let startSeconds: Double
    public let endSeconds: Double
    public let normalizedLabel: String
    public init(startSeconds: Double, endSeconds: Double, normalizedLabel: String) {
        self.startSeconds = startSeconds
        self.endSeconds = endSeconds
        self.normalizedLabel = normalizedLabel
    }
}

public struct AnalysisReferenceObservedSection: Codable, Equatable, Sendable {
    public let startSeconds: Double
    public let endSeconds: Double
    public let structuralLabel: String
    public let functionalLabel: String?
    public init(startSeconds: Double, endSeconds: Double, structuralLabel: String, functionalLabel: String? = nil) {
        self.startSeconds = startSeconds
        self.endSeconds = endSeconds
        self.structuralLabel = structuralLabel
        self.functionalLabel = functionalLabel
    }
}

public struct AnalysisReferenceRawObservation: Codable, Equatable, Sendable {
    public let runID: String
    public let fixtureID: String
    public let domain: String
    public let status: AnalysisReferenceRawObservationStatus
    public let evidenceArtifactIDs: [String]
    public let observedBPM: Double?
    public let beatTimesSeconds: [Double]?
    public let key: AnalysisReferenceObservedKey?
    public let chords: [AnalysisReferenceObservedChord]?
    public let sections: [AnalysisReferenceObservedSection]?
    public let limitations: [String]

    public init(runID: String, fixtureID: String, domain: String, status: AnalysisReferenceRawObservationStatus, evidenceArtifactIDs: [String], observedBPM: Double? = nil, beatTimesSeconds: [Double]? = nil, key: AnalysisReferenceObservedKey? = nil, chords: [AnalysisReferenceObservedChord]? = nil, sections: [AnalysisReferenceObservedSection]? = nil, limitations: [String] = []) {
        self.runID = runID
        self.fixtureID = fixtureID
        self.domain = domain
        self.status = status
        self.evidenceArtifactIDs = evidenceArtifactIDs
        self.observedBPM = observedBPM
        self.beatTimesSeconds = beatTimesSeconds
        self.key = key
        self.chords = chords
        self.sections = sections
        self.limitations = limitations
    }
}

public struct AnalysisReferenceRawObservationSet: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let rawSetID: String
    public let captureSetID: String
    public let sourceManifestID: String
    public let sourceManifestSHA256: String
    public let observations: [AnalysisReferenceRawObservation]

    public init(schemaVersion: Int = 1, rawSetID: String, captureSetID: String, sourceManifestID: String, sourceManifestSHA256: String, observations: [AnalysisReferenceRawObservation]) {
        self.schemaVersion = schemaVersion
        self.rawSetID = rawSetID
        self.captureSetID = captureSetID
        self.sourceManifestID = sourceManifestID
        self.sourceManifestSHA256 = sourceManifestSHA256.lowercased()
        self.observations = observations
    }
}

public enum AnalysisReferenceRawDerivationIssueCode: String, Codable, Hashable, Sendable {
    case invalidRawSet = "INVALID_RAW_SET"
    case invalidManifest = "INVALID_MANIFEST"
    case sourceBindingMismatch = "SOURCE_BINDING_MISMATCH"
    case duplicateRawObservation = "DUPLICATE_RAW_OBSERVATION"
    case missingRawObservation = "MISSING_RAW_OBSERVATION"
    case unexpectedRawObservation = "UNEXPECTED_RAW_OBSERVATION"
    case missingEvidenceArtifact = "MISSING_EVIDENCE_ARTIFACT"
    case rowMetadataMismatch = "ROW_METADATA_MISMATCH"
    case groundTruthUnavailable = "GROUND_TRUTH_UNAVAILABLE"
    case unsupportedObservation = "UNSUPPORTED_OBSERVATION"
    case unscorableObservation = "UNSCORABLE_OBSERVATION"
    case rawPayloadMismatch = "RAW_PAYLOAD_MISMATCH"
    case invalidRawValue = "INVALID_RAW_VALUE"
    case evaluatorRejected = "EVALUATOR_REJECTED"
    case derivedMetricSetMismatch = "DERIVED_METRIC_SET_MISMATCH"
    case derivedMetricValueMismatch = "DERIVED_METRIC_VALUE_MISMATCH"
    case nonFiniteDerivedMetric = "NON_FINITE_DERIVED_METRIC"
}

public struct AnalysisReferenceRawDerivationIssue: Codable, Equatable, Sendable {
    public let code: AnalysisReferenceRawDerivationIssueCode
    public let runID: String?
    public let fixtureID: String?
    public let domain: String?
    public let metric: String?
    public let detail: String
    public init(code: AnalysisReferenceRawDerivationIssueCode, runID: String? = nil, fixtureID: String? = nil, domain: String? = nil, metric: String? = nil, detail: String) {
        self.code = code
        self.runID = runID
        self.fixtureID = fixtureID
        self.domain = domain
        self.metric = metric
        self.detail = detail
    }
}

public struct AnalysisReferenceRawMetricDiagnostic: Codable, Equatable, Sendable {
    public let runID: String
    public let fixtureID: String
    public let domain: String
    public let observationStatus: AnalysisReferenceRawObservationStatus
    public let declaredMetrics: [String: Double]
    public let derivedMetrics: [String: Double]
    public let limitations: [String]
    public let metricsIdentityMatched: Bool
}

public enum AnalysisReferenceRawDerivationStatus: String, Codable, Sendable {
    case invalid = "INVALID"
    case derivedPendingW19 = "DERIVED_REFERENCE_PENDING_W19"
}

public struct AnalysisReferenceRawDerivationReport: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let generatedAt: Date
    public let rawSetID: String
    public let captureSetID: String
    public let status: AnalysisReferenceRawDerivationStatus
    public let derivationReady: Bool
    public let diagnostics: [AnalysisReferenceRawMetricDiagnostic]
    public let issues: [AnalysisReferenceRawDerivationIssue]
    public let derivedCaptureSet: AnalysisReferenceCaptureSet?

    public init(schemaVersion: Int = 1, generatedAt: Date, rawSetID: String, captureSetID: String, status: AnalysisReferenceRawDerivationStatus, derivationReady: Bool, diagnostics: [AnalysisReferenceRawMetricDiagnostic], issues: [AnalysisReferenceRawDerivationIssue], derivedCaptureSet: AnalysisReferenceCaptureSet?) {
        self.schemaVersion = schemaVersion
        self.generatedAt = generatedAt
        self.rawSetID = rawSetID
        self.captureSetID = captureSetID
        self.status = status
        self.derivationReady = derivationReady
        self.diagnostics = diagnostics
        self.issues = issues
        self.derivedCaptureSet = derivedCaptureSet
    }
}

public struct AnalysisReferenceRawCompilation: Codable, Equatable, Sendable {
    public let derivation: AnalysisReferenceRawDerivationReport
    public let captureValidation: AnalysisReferenceCaptureValidationReport
    public let auditedReference: AnalysisAuditedRealAudioBenchmarkReport
}

public enum AnalysisReferenceRawCompilerError: Error, Equatable, Sendable {
    case invalidRawObservations([AnalysisReferenceRawDerivationIssue])
    case invalidCapture([AnalysisReferenceCaptureIssue])
}

public enum AnalysisReferenceRawObservationDeriver {
    private static let supportedDomains: Set<String> = ["tempo", "beat", "key", "chord", "structure"]
    private static let numericIdentityRelativeTolerance = 1e-9

    public static func derive(rawSet: AnalysisReferenceRawObservationSet, captureSet: AnalysisReferenceCaptureSet, policy: AnalysisReferenceCapturePolicy, manifest: AnalysisRealAudioBenchmarkManifest, manifestSHA256: String, configuration: MusicAnalysisConfiguration = .productBaseline, evaluatedAt: Date = Date()) -> AnalysisReferenceRawDerivationReport {
        var issues: [AnalysisReferenceRawDerivationIssue] = []
        var diagnostics: [AnalysisReferenceRawMetricDiagnostic] = []

        if rawSet.schemaVersion != 1 || trimmed(rawSet.rawSetID).isEmpty || rawSet.observations.isEmpty {
            issues.append(.init(code: .invalidRawSet, detail: "raw observation set schema/id/observations are invalid"))
        }
        if rawSet.captureSetID != captureSet.captureSetID {
            issues.append(.init(code: .sourceBindingMismatch, detail: "raw capture_set_id does not match W19 capture set"))
        }
        let normalizedManifestSHA = manifestSHA256.lowercased()
        if rawSet.sourceManifestID != manifest.manifestID || rawSet.sourceManifestID != policy.expectedSourceManifestID || rawSet.sourceManifestSHA256 != normalizedManifestSHA || rawSet.sourceManifestSHA256 != policy.expectedSourceManifestSHA256.lowercased() || !isSHA256(normalizedManifestSHA) {
            issues.append(.init(code: .sourceBindingMismatch, detail: "raw/manifest/W19 policy source identity or SHA-256 does not match"))
        }
        let manifestIssues = AnalysisRealAudioManifestValidator.validate(manifest, at: evaluatedAt)
        if !manifestIssues.isEmpty {
            issues.append(.init(code: .invalidManifest, detail: "benchmark manifest failed canonical validation"))
        }

        var manifestIndex: [String: AnalysisRealAudioBenchmarkCase] = [:]
        for item in manifest.cases where manifestIndex[item.fixtureID] == nil { manifestIndex[item.fixtureID] = item }
        var rawIndex: [ObservationKey: AnalysisReferenceRawObservation] = [:]
        for observation in rawSet.observations {
            let key = ObservationKey(runID: observation.runID, fixtureID: observation.fixtureID, domain: observation.domain)
            if rawIndex[key] != nil {
                issues.append(.init(code: .duplicateRawObservation, runID: observation.runID, fixtureID: observation.fixtureID, domain: observation.domain, detail: "raw observation key must be unique"))
            } else {
                rawIndex[key] = observation
            }
        }

        var expectedKeys = Set<ObservationKey>()
        for run in captureSet.runs {
            for row in run.rows { expectedKeys.insert(.init(runID: run.runID, fixtureID: row.fixtureID, domain: row.domain)) }
        }
        let rawKeys = Set(rawIndex.keys)
        for key in expectedKeys.subtracting(rawKeys).sorted() {
            issues.append(.init(code: .missingRawObservation, runID: key.runID, fixtureID: key.fixtureID, domain: key.domain, detail: "W19 declared row has no raw observation"))
        }
        for key in rawKeys.subtracting(expectedKeys).sorted() {
            issues.append(.init(code: .unexpectedRawObservation, runID: key.runID, fixtureID: key.fixtureID, domain: key.domain, detail: "raw observation has no corresponding W19 declared row"))
        }

        var derivedRuns: [AnalysisReferenceCaptureRun] = []
        for run in captureSet.runs {
            var derivedRows: [AnalysisReferenceCaptureRow] = []
            for row in run.rows {
                let key = ObservationKey(runID: run.runID, fixtureID: row.fixtureID, domain: row.domain)
                guard let raw = rawIndex[key] else { continue }
                guard let benchmarkCase = manifestIndex[row.fixtureID] else {
                    issues.append(.init(code: .groundTruthUnavailable, runID: run.runID, fixtureID: row.fixtureID, domain: row.domain, detail: "fixture does not exist in benchmark manifest"))
                    continue
                }
                if !supportedDomains.contains(row.domain) || !benchmarkCase.reference.coveredDomains.contains(row.domain) {
                    issues.append(.init(code: .groundTruthUnavailable, runID: run.runID, fixtureID: row.fixtureID, domain: row.domain, detail: "domain has no canonical ground-truth annotation"))
                    continue
                }
                let expectedSynthetic = benchmarkCase.sourceKind == .syntheticTest
                if row.genre != benchmarkCase.genre || abs(row.durationSeconds - benchmarkCase.expectedDurationSeconds) > 0.001 || row.rightsClass != benchmarkCase.rights.rightsClass || row.syntheticOnly != expectedSynthetic {
                    issues.append(.init(code: .rowMetadataMismatch, runID: run.runID, fixtureID: row.fixtureID, domain: row.domain, detail: "W19 row metadata differs from canonical manifest case"))
                }
                let evidence = Set(raw.evidenceArtifactIDs)
                if evidence.isEmpty || !evidence.isSubset(of: Set(row.evidenceArtifactIDs)) {
                    issues.append(.init(code: .missingEvidenceArtifact, runID: run.runID, fixtureID: row.fixtureID, domain: row.domain, detail: "raw observation must bind to W19 row evidence artifacts"))
                }
                if raw.status == .unsupported {
                    issues.append(.init(code: .unsupportedObservation, runID: run.runID, fixtureID: row.fixtureID, domain: row.domain, detail: "unsupported Reference state cannot be converted into a quality score"))
                    continue
                }
                if raw.status == .unscorable {
                    issues.append(.init(code: .unscorableObservation, runID: run.runID, fixtureID: row.fixtureID, domain: row.domain, detail: "unscorable Reference state cannot be converted into a quality score"))
                    continue
                }
                guard let derived = deriveMetrics(raw: raw, benchmarkCase: benchmarkCase, configuration: configuration, issues: &issues) else { continue }
                let identityMatched = compareDeclared(row.qualityMetrics, derived: derived, key: key, issues: &issues)
                diagnostics.append(.init(runID: run.runID, fixtureID: row.fixtureID, domain: row.domain, observationStatus: raw.status, declaredMetrics: row.qualityMetrics, derivedMetrics: derived, limitations: raw.limitations.sorted(), metricsIdentityMatched: identityMatched))
                derivedRows.append(.init(fixtureID: row.fixtureID, rightsClass: row.rightsClass, genre: row.genre, durationSeconds: row.durationSeconds, syntheticOnly: row.syntheticOnly, domain: row.domain, qualityMetrics: derived, evidenceArtifactIDs: row.evidenceArtifactIDs))
            }
            derivedRuns.append(.init(runID: run.runID, operatorID: run.operatorID, capturedAt: run.capturedAt, environment: run.environment, sourceBinding: run.sourceBinding, observationMethod: run.observationMethod, artifacts: run.artifacts, rows: derivedRows))
        }

        issues.sort(by: issueOrder)
        diagnostics.sort {
            if $0.runID != $1.runID { return $0.runID < $1.runID }
            if $0.fixtureID != $1.fixtureID { return $0.fixtureID < $1.fixtureID }
            return $0.domain < $1.domain
        }
        let ready = issues.isEmpty && diagnostics.count == expectedKeys.count
        let derivedCaptureSet = ready ? AnalysisReferenceCaptureSet(schemaVersion: captureSet.schemaVersion, captureSetID: captureSet.captureSetID, createdAt: captureSet.createdAt, runs: derivedRuns) : nil
        return .init(generatedAt: evaluatedAt, rawSetID: rawSet.rawSetID, captureSetID: captureSet.captureSetID, status: ready ? .derivedPendingW19 : .invalid, derivationReady: ready, diagnostics: diagnostics, issues: issues, derivedCaptureSet: derivedCaptureSet)
    }

    public static func validateAndCompileReference(rawSet: AnalysisReferenceRawObservationSet, captureSet: AnalysisReferenceCaptureSet, policy: AnalysisReferenceCapturePolicy, manifest: AnalysisRealAudioBenchmarkManifest, manifestSHA256: String, configuration: MusicAnalysisConfiguration = .productBaseline, evaluatedAt: Date = Date(), engine: String = "current-iphone-moises-reference") throws -> AnalysisReferenceRawCompilation {
        let derivation = derive(rawSet: rawSet, captureSet: captureSet, policy: policy, manifest: manifest, manifestSHA256: manifestSHA256, configuration: configuration, evaluatedAt: evaluatedAt)
        guard derivation.derivationReady, let derivedCaptureSet = derivation.derivedCaptureSet else {
            throw AnalysisReferenceRawCompilerError.invalidRawObservations(derivation.issues)
        }
        let validation = AnalysisReferenceCaptureValidator.validate(captureSet: derivedCaptureSet, policy: policy, evaluatedAt: evaluatedAt)
        guard validation.comparisonReady else { throw AnalysisReferenceRawCompilerError.invalidCapture(validation.issues) }
        let audited = try AnalysisReferenceCaptureValidator.compileAuditedReferenceReport(captureSet: derivedCaptureSet, policy: policy, evaluatedAt: evaluatedAt, engine: engine)
        return .init(derivation: derivation, captureValidation: validation, auditedReference: audited)
    }

    private static func deriveMetrics(raw: AnalysisReferenceRawObservation, benchmarkCase: AnalysisRealAudioBenchmarkCase, configuration: MusicAnalysisConfiguration, issues: inout [AnalysisReferenceRawDerivationIssue]) -> [String: Double]? {
        let duration = benchmarkCase.expectedDurationSeconds
        let reference = benchmarkCase.reference
        let key = ObservationKey(runID: raw.runID, fixtureID: raw.fixtureID, domain: raw.domain)
        if !payloadMatchesDomain(raw) {
            issues.append(.init(code: .rawPayloadMismatch, runID: key.runID, fixtureID: key.fixtureID, domain: key.domain, detail: "raw payload fields do not match domain/status"))
            return nil
        }
        var metrics: [String: Double]
        switch raw.domain {
        case "tempo":
            guard let referenceBPM = reference.bpm, referenceBPM.isFinite, referenceBPM > 0 else { return nil }
            if raw.status == .noDecision {
                metrics = ["decision_emitted": 0]
            } else if let predicted = raw.observedBPM, predicted.isFinite, predicted > 0 {
                let error = abs(predicted - referenceBPM) / referenceBPM
                let ratios = [predicted / referenceBPM, predicted / (referenceBPM * 0.5), predicted / (referenceBPM * 2)]
                metrics = ["decision_emitted": 1, "tempo_rel_error": error, "exact_within_4pct": error <= 0.04 ? 1 : 0, "octave_aware_within_4pct": ratios.contains { abs($0 - 1) <= 0.04 } ? 1 : 0]
            } else {
                issues.append(.init(code: .invalidRawValue, runID: key.runID, fixtureID: key.fixtureID, domain: key.domain, detail: "observed tempo BPM must be finite and > 0"))
                return nil
            }
        case "beat":
            let estimated = raw.status == .noDecision ? [] : (raw.beatTimesSeconds ?? [])
            guard validateTimeline(estimated, duration: duration) else {
                issues.append(.init(code: .invalidRawValue, runID: key.runID, fixtureID: key.fixtureID, domain: key.domain, detail: "beat timestamps must be finite, ordered, and within duration"))
                return nil
            }
            let evaluator = AnalysisBenchmarkEvaluatorPolicy.diagnostics(referenceBeatCount: reference.beatTimesSeconds.count, estimatedBeatCount: estimated.count, referenceChordCount: 0, estimatedChordCount: 0, referenceSectionCount: 0, estimatedSectionCount: 0, duration: duration, configuration: configuration)
            guard evaluator.beatInputsAccepted else {
                issues.append(.init(code: .evaluatorRejected, runID: key.runID, fixtureID: key.fixtureID, domain: key.domain, detail: "raw beat cardinality exceeds evaluator input policy"))
                return nil
            }
            metrics = ["beat_f_70ms": AnalysisBenchmarkRunner.beatFMeasure(reference: reference.beatTimesSeconds, estimated: estimated, tolerance: 0.070)]
            if let errors = BenchmarkTimelineMatcher.nearestAbsoluteErrors(source: reference.beatTimesSeconds, target: estimated), let median = median(errors.sorted()) { metrics["median_abs_error_seconds"] = median }
        case "key":
            guard let referenceKey = reference.key else { return nil }
            if raw.status == .noDecision {
                metrics = ["decision_emitted": 0]
            } else if let observed = raw.key, (0...11).contains(observed.tonicPitchClass), !trimmed(observed.mode).isEmpty {
                let estimated = MusicalKey(tonicPitchClass: observed.tonicPitchClass, mode: observed.mode, confidence: nil)
                metrics = ["decision_emitted": 1, "exact_key_accuracy": (estimated.tonicPitchClass == referenceKey.tonicPitchClass && estimated.mode == referenceKey.mode) ? 1 : 0, "tonic_accuracy": estimated.tonicPitchClass == referenceKey.tonicPitchClass ? 1 : 0, "mode_accuracy": estimated.mode == referenceKey.mode ? 1 : 0, "weighted_key_score": AnalysisBenchmarkRunner.weightedKeyScore(reference: referenceKey, estimated: estimated)]
            } else {
                issues.append(.init(code: .invalidRawValue, runID: key.runID, fixtureID: key.fixtureID, domain: key.domain, detail: "observed key tonic/mode is invalid"))
                return nil
            }
        case "chord":
            let rawChords = raw.status == .noDecision ? [] : (raw.chords ?? [])
            guard validateChords(rawChords, duration: duration) else {
                issues.append(.init(code: .invalidRawValue, runID: key.runID, fixtureID: key.fixtureID, domain: key.domain, detail: "chord timeline is invalid, overlapping, or outside duration"))
                return nil
            }
            let estimated = rawChords.map { ChordEvent(startSeconds: $0.startSeconds, endSeconds: $0.endSeconds, normalizedLabel: $0.normalizedLabel, confidence: nil) }
            let evaluator = AnalysisBenchmarkEvaluatorPolicy.diagnostics(referenceBeatCount: 0, estimatedBeatCount: 0, referenceChordCount: reference.chords.count, estimatedChordCount: estimated.count, referenceSectionCount: 0, estimatedSectionCount: 0, duration: duration, configuration: configuration)
            guard evaluator.chordInputsAccepted else {
                issues.append(.init(code: .evaluatorRejected, runID: key.runID, fixtureID: key.fixtureID, domain: key.domain, detail: "raw chord cardinality exceeds evaluator input policy"))
                return nil
            }
            metrics = qualityOnly(AnalysisBenchmarkRunner.chordMetrics(reference: reference.chords, estimated: estimated, duration: duration))
        case "structure":
            let rawSections = raw.status == .noDecision ? [] : (raw.sections ?? [])
            guard validateSections(rawSections, duration: duration) else {
                issues.append(.init(code: .invalidRawValue, runID: key.runID, fixtureID: key.fixtureID, domain: key.domain, detail: "section timeline is invalid, overlapping, or outside duration"))
                return nil
            }
            let estimated = rawSections.map { SongSection(startSeconds: $0.startSeconds, endSeconds: $0.endSeconds, structuralLabel: $0.structuralLabel, functionalLabel: $0.functionalLabel, confidence: nil) }
            let evaluator = AnalysisBenchmarkEvaluatorPolicy.diagnostics(referenceBeatCount: 0, estimatedBeatCount: 0, referenceChordCount: 0, estimatedChordCount: 0, referenceSectionCount: reference.sections.count, estimatedSectionCount: estimated.count, duration: duration, configuration: configuration)
            guard evaluator.sectionInputsAccepted else {
                issues.append(.init(code: .evaluatorRejected, runID: key.runID, fixtureID: key.fixtureID, domain: key.domain, detail: "raw section cardinality exceeds evaluator input policy"))
                return nil
            }
            metrics = qualityOnly(SectionBenchmarkEvaluator.metrics(reference: reference.sections, estimated: estimated, duration: duration, configuration: configuration))
        default:
            issues.append(.init(code: .groundTruthUnavailable, runID: key.runID, fixtureID: key.fixtureID, domain: key.domain, detail: "unsupported analysis domain"))
            return nil
        }
        if metrics.isEmpty || metrics.values.contains(where: { !$0.isFinite }) {
            issues.append(.init(code: .nonFiniteDerivedMetric, runID: key.runID, fixtureID: key.fixtureID, domain: key.domain, detail: "derived quality metrics are empty or non-finite"))
            return nil
        }
        return metrics
    }

    private static func payloadMatchesDomain(_ raw: AnalysisReferenceRawObservation) -> Bool {
        if raw.status == .noDecision { return raw.observedBPM == nil && raw.beatTimesSeconds == nil && raw.key == nil && raw.chords == nil && raw.sections == nil }
        guard raw.status == .observed else { return true }
        switch raw.domain {
        case "tempo": return raw.observedBPM != nil && raw.beatTimesSeconds == nil && raw.key == nil && raw.chords == nil && raw.sections == nil
        case "beat": return raw.observedBPM == nil && raw.beatTimesSeconds != nil && raw.key == nil && raw.chords == nil && raw.sections == nil
        case "key": return raw.observedBPM == nil && raw.beatTimesSeconds == nil && raw.key != nil && raw.chords == nil && raw.sections == nil
        case "chord": return raw.observedBPM == nil && raw.beatTimesSeconds == nil && raw.key == nil && raw.chords != nil && raw.sections == nil
        case "structure": return raw.observedBPM == nil && raw.beatTimesSeconds == nil && raw.key == nil && raw.chords == nil && raw.sections != nil
        default: return false
        }
    }

    private static func compareDeclared(_ declared: [String: Double], derived: [String: Double], key: ObservationKey, issues: inout [AnalysisReferenceRawDerivationIssue]) -> Bool {
        let declaredKeys = Set(declared.keys)
        let derivedKeys = Set(derived.keys)
        var matched = true
        if declaredKeys != derivedKeys {
            matched = false
            issues.append(.init(code: .derivedMetricSetMismatch, runID: key.runID, fixtureID: key.fixtureID, domain: key.domain, detail: "declared W19 metric set differs from raw-derived canonical metric set"))
        }
        for metric in declaredKeys.intersection(derivedKeys).sorted() {
            guard let lhs = declared[metric], let rhs = derived[metric], lhs.isFinite, rhs.isFinite else { matched = false; continue }
            let scale = max(1, max(abs(lhs), abs(rhs)))
            if abs(lhs - rhs) > numericIdentityRelativeTolerance * scale {
                matched = false
                issues.append(.init(code: .derivedMetricValueMismatch, runID: key.runID, fixtureID: key.fixtureID, domain: key.domain, metric: metric, detail: "declared W19 metric differs from deterministic raw-derived value"))
            }
        }
        return matched
    }

    private static func qualityOnly(_ metrics: [String: Double]) -> [String: Double] {
        Dictionary(uniqueKeysWithValues: metrics.compactMap { metric, value in
            guard AnalysisBenchmarkAggregation.metricDirections[metric] != nil else { return nil }
            return (metric, value)
        })
    }

    private static func validateTimeline(_ values: [Double], duration: Double) -> Bool {
        var previous = -Double.infinity
        for value in values {
            if !value.isFinite || value < 0 || value > duration || value < previous { return false }
            previous = value
        }
        return true
    }

    private static func validateChords(_ chords: [AnalysisReferenceObservedChord], duration: Double) -> Bool {
        var previousEnd = 0.0
        for chord in chords {
            if !chord.startSeconds.isFinite || !chord.endSeconds.isFinite || chord.startSeconds < 0 || chord.endSeconds <= chord.startSeconds || chord.endSeconds > duration || chord.startSeconds < previousEnd - 1e-9 || trimmed(chord.normalizedLabel).isEmpty { return false }
            previousEnd = chord.endSeconds
        }
        return true
    }

    private static func validateSections(_ sections: [AnalysisReferenceObservedSection], duration: Double) -> Bool {
        var previousEnd = 0.0
        for section in sections {
            if !section.startSeconds.isFinite || !section.endSeconds.isFinite || section.startSeconds < 0 || section.endSeconds <= section.startSeconds || section.endSeconds > duration || section.startSeconds < previousEnd - 1e-9 || trimmed(section.structuralLabel).isEmpty { return false }
            previousEnd = section.endSeconds
        }
        return true
    }

    private static func median(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let middle = values.count / 2
        if values.count.isMultiple(of: 2) { return (values[middle - 1] + values[middle]) / 2 }
        return values[middle]
    }

    private static func trimmed(_ value: String) -> String { value.trimmingCharacters(in: .whitespacesAndNewlines) }
    private static func isSHA256(_ value: String) -> Bool {
        guard value.count == 64 else { return false }
        return value.unicodeScalars.allSatisfy { scalar in (48...57).contains(scalar.value) || (97...102).contains(scalar.value) || (65...70).contains(scalar.value) }
    }
    private static func issueOrder(_ lhs: AnalysisReferenceRawDerivationIssue, _ rhs: AnalysisReferenceRawDerivationIssue) -> Bool {
        let left = "\(lhs.code.rawValue)|\(lhs.runID ?? "")|\(lhs.fixtureID ?? "")|\(lhs.domain ?? "")|\(lhs.metric ?? "")|\(lhs.detail)"
        let right = "\(rhs.code.rawValue)|\(rhs.runID ?? "")|\(rhs.fixtureID ?? "")|\(rhs.domain ?? "")|\(rhs.metric ?? "")|\(rhs.detail)"
        return left < right
    }
    private struct ObservationKey: Hashable, Comparable {
        let runID: String
        let fixtureID: String
        let domain: String
        static func < (lhs: ObservationKey, rhs: ObservationKey) -> Bool {
            if lhs.runID != rhs.runID { return lhs.runID < rhs.runID }
            if lhs.fixtureID != rhs.fixtureID { return lhs.fixtureID < rhs.fixtureID }
            return lhs.domain < rhs.domain
        }
    }
}

public enum AnalysisReferenceRawObservationCodec {
    public static func encodeRawSet(_ value: AnalysisReferenceRawObservationSet) throws -> Data { try makeEncoder().encode(value) }
    public static func decodeRawSet(_ data: Data) throws -> AnalysisReferenceRawObservationSet { try makeDecoder().decode(AnalysisReferenceRawObservationSet.self, from: data) }
    public static func encodeDerivationReport(_ value: AnalysisReferenceRawDerivationReport) throws -> Data { try makeEncoder().encode(value) }
    public static func decodeDerivationReport(_ data: Data) throws -> AnalysisReferenceRawDerivationReport { try makeDecoder().decode(AnalysisReferenceRawDerivationReport.self, from: data) }
    public static func encodeCompilation(_ value: AnalysisReferenceRawCompilation) throws -> Data { try makeEncoder().encode(value) }
    public static func decodeCompilation(_ data: Data) throws -> AnalysisReferenceRawCompilation { try makeDecoder().decode(AnalysisReferenceRawCompilation.self, from: data) }
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

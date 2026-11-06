import Foundation

public struct AnalysisCorpusCoverageDomainMinimum: Codable, Equatable, Sendable {
    public let domain: String
    public let minimumFixtureCount: Int
    public let minimumTotalDurationSeconds: Double

    public init(domain: String, minimumFixtureCount: Int, minimumTotalDurationSeconds: Double) {
        self.domain = domain
        self.minimumFixtureCount = minimumFixtureCount
        self.minimumTotalDurationSeconds = minimumTotalDurationSeconds
    }
}

public struct AnalysisCorpusCoveragePredicate: Codable, Equatable, Sendable {
    public let genreExact: String?
    public let minimumBPMInclusive: Double?
    public let maximumBPMExclusive: Double?
    public let keyModeExact: String?
    public let chordQualitiesAnyOf: [String]
    public let requiresChordInversion: Bool?
    public let requiresNoChord: Bool?
    public let minimumDistinctChordLabels: Int?
    public let minimumSectionCount: Int?
    public let minimumDistinctStructuralLabels: Int?
    public let requiredFunctionalLabels: [String]
    public let requiresRepeatedStructuralLabel: Bool?

    public init(
        genreExact: String? = nil,
        minimumBPMInclusive: Double? = nil,
        maximumBPMExclusive: Double? = nil,
        keyModeExact: String? = nil,
        chordQualitiesAnyOf: [String] = [],
        requiresChordInversion: Bool? = nil,
        requiresNoChord: Bool? = nil,
        minimumDistinctChordLabels: Int? = nil,
        minimumSectionCount: Int? = nil,
        minimumDistinctStructuralLabels: Int? = nil,
        requiredFunctionalLabels: [String] = [],
        requiresRepeatedStructuralLabel: Bool? = nil
    ) {
        self.genreExact = genreExact
        self.minimumBPMInclusive = minimumBPMInclusive
        self.maximumBPMExclusive = maximumBPMExclusive
        self.keyModeExact = keyModeExact
        self.chordQualitiesAnyOf = chordQualitiesAnyOf
        self.requiresChordInversion = requiresChordInversion
        self.requiresNoChord = requiresNoChord
        self.minimumDistinctChordLabels = minimumDistinctChordLabels
        self.minimumSectionCount = minimumSectionCount
        self.minimumDistinctStructuralLabels = minimumDistinctStructuralLabels
        self.requiredFunctionalLabels = requiredFunctionalLabels
        self.requiresRepeatedStructuralLabel = requiresRepeatedStructuralLabel
    }
}

public struct AnalysisCorpusCoverageStratum: Codable, Equatable, Sendable {
    public let stratumID: String
    public let domain: String
    public let minimumFixtureCount: Int
    public let minimumTotalDurationSeconds: Double
    public let predicate: AnalysisCorpusCoveragePredicate

    public init(stratumID: String, domain: String, minimumFixtureCount: Int, minimumTotalDurationSeconds: Double, predicate: AnalysisCorpusCoveragePredicate) {
        self.stratumID = stratumID
        self.domain = domain
        self.minimumFixtureCount = minimumFixtureCount
        self.minimumTotalDurationSeconds = minimumTotalDurationSeconds
        self.predicate = predicate
    }
}

public struct AnalysisCorpusCoveragePolicy: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let policyID: String
    public let authority: String
    public let approvalReference: String
    public let expectedManifestID: String
    public let expectedManifestSHA256: String
    public let minimumUniqueFixtureCount: Int
    public let minimumTotalDurationSeconds: Double
    public let domainMinimums: [AnalysisCorpusCoverageDomainMinimum]
    public let strata: [AnalysisCorpusCoverageStratum]

    public init(
        schemaVersion: Int = 1,
        policyID: String,
        authority: String,
        approvalReference: String,
        expectedManifestID: String,
        expectedManifestSHA256: String,
        minimumUniqueFixtureCount: Int,
        minimumTotalDurationSeconds: Double,
        domainMinimums: [AnalysisCorpusCoverageDomainMinimum],
        strata: [AnalysisCorpusCoverageStratum]
    ) {
        self.schemaVersion = schemaVersion
        self.policyID = policyID
        self.authority = authority
        self.approvalReference = approvalReference
        self.expectedManifestID = expectedManifestID
        self.expectedManifestSHA256 = expectedManifestSHA256.lowercased()
        self.minimumUniqueFixtureCount = minimumUniqueFixtureCount
        self.minimumTotalDurationSeconds = minimumTotalDurationSeconds
        self.domainMinimums = domainMinimums
        self.strata = strata
    }
}

public enum AnalysisCorpusCoverageIssueCode: String, Codable, Hashable, Sendable {
    case invalidPolicy = "INVALID_POLICY"
    case invalidManifest = "INVALID_MANIFEST"
    case manifestBindingMismatch = "MANIFEST_BINDING_MISMATCH"
    case duplicateDomainMinimum = "DUPLICATE_DOMAIN_MINIMUM"
    case requiredDomainMissing = "REQUIRED_DOMAIN_MISSING"
    case duplicateStratumID = "DUPLICATE_STRATUM_ID"
    case ineligibleFixture = "INELIGIBLE_FIXTURE"
    case globalFixtureDeficit = "GLOBAL_FIXTURE_DEFICIT"
    case globalDurationDeficit = "GLOBAL_DURATION_DEFICIT"
    case domainFixtureDeficit = "DOMAIN_FIXTURE_DEFICIT"
    case domainDurationDeficit = "DOMAIN_DURATION_DEFICIT"
    case stratumFixtureDeficit = "STRATUM_FIXTURE_DEFICIT"
    case stratumDurationDeficit = "STRATUM_DURATION_DEFICIT"
}

public struct AnalysisCorpusCoverageIssue: Codable, Equatable, Sendable {
    public let code: AnalysisCorpusCoverageIssueCode
    public let domain: String?
    public let stratumID: String?
    public let fixtureID: String?
    public let detail: String

    public init(code: AnalysisCorpusCoverageIssueCode, domain: String? = nil, stratumID: String? = nil, fixtureID: String? = nil, detail: String) {
        self.code = code
        self.domain = domain
        self.stratumID = stratumID
        self.fixtureID = fixtureID
        self.detail = detail
    }
}

public struct AnalysisCorpusCoverageDiagnostic: Codable, Equatable, Sendable {
    public let stratumID: String
    public let domain: String
    public let matchedFixtureCount: Int
    public let matchedTotalDurationSeconds: Double
    public let minimumFixtureCount: Int
    public let minimumTotalDurationSeconds: Double
    public let matchedFixtureIDs: [String]
    public let satisfied: Bool
}

public struct AnalysisCorpusDomainCoverageDiagnostic: Codable, Equatable, Sendable {
    public let domain: String
    public let eligibleFixtureCount: Int
    public let eligibleTotalDurationSeconds: Double
    public let minimumFixtureCount: Int
    public let minimumTotalDurationSeconds: Double
    public let satisfied: Bool
}

public enum AnalysisCorpusCoverageStatus: String, Codable, Sendable {
    case insufficient = "INSUFFICIENT_CORPUS"
    case sufficientPendingHQ = "SUFFICIENT_CORPUS_PENDING_HQ"
}

public struct AnalysisCorpusCoverageReport: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let generatedAt: Date
    public let policyID: String
    public let manifestID: String
    public let manifestSHA256: String
    public let status: AnalysisCorpusCoverageStatus
    public let comparisonCorpusReady: Bool
    public let eligibleFixtureCount: Int
    public let eligibleTotalDurationSeconds: Double
    public let eligibleFixtureIDs: [String]
    public let domainDiagnostics: [AnalysisCorpusDomainCoverageDiagnostic]
    public let stratumDiagnostics: [AnalysisCorpusCoverageDiagnostic]
    public let issues: [AnalysisCorpusCoverageIssue]
}

public enum AnalysisCorpusCoverageValidator {
    public static let requiredAuthority = "HQ_LATE_INTEGRATION"
    public static let requiredAnalysisDomains: Set<String> = ["tempo", "beat", "key", "chord", "structure"]

    public static func validate(
        manifest: AnalysisRealAudioBenchmarkManifest,
        manifestSHA256: String,
        policy: AnalysisCorpusCoveragePolicy,
        evaluatedAt: Date = Date()
    ) -> AnalysisCorpusCoverageReport {
        let normalizedSHA = manifestSHA256.lowercased()
        var issues = validatePolicy(policy)
        let manifestIssues = AnalysisRealAudioManifestValidator.validate(manifest, at: evaluatedAt)
        if !manifestIssues.isEmpty {
            issues.append(.init(code: .invalidManifest, detail: "benchmark manifest failed canonical validation with \(manifestIssues.count) issue(s)"))
        }
        if manifest.manifestID != policy.expectedManifestID || normalizedSHA != policy.expectedManifestSHA256 || !isSHA256(normalizedSHA) {
            issues.append(.init(code: .manifestBindingMismatch, detail: "manifest id/SHA-256 does not match HQ-approved coverage policy"))
        }

        let features = manifest.cases.map { fixtureFeatures($0, at: evaluatedAt) }
        let eligible = features.filter(\.eligible)
        for feature in features where !feature.eligible {
            issues.append(.init(code: .ineligibleFixture, fixtureID: feature.fixtureID, detail: feature.ineligibilityReason ?? "fixture is not rights/parity eligible"))
        }

        let eligibleFixtureIDs = eligible.map(\.fixtureID).sorted()
        let eligibleDuration = eligible.reduce(0.0) { $0 + $1.durationSeconds }
        if eligibleFixtureIDs.count < policy.minimumUniqueFixtureCount {
            issues.append(.init(code: .globalFixtureDeficit, detail: "eligible unique fixture count \(eligibleFixtureIDs.count) is below HQ minimum \(policy.minimumUniqueFixtureCount)"))
        }
        if eligibleDuration + 1e-9 < policy.minimumTotalDurationSeconds {
            issues.append(.init(code: .globalDurationDeficit, detail: "eligible duration \(eligibleDuration) is below HQ minimum \(policy.minimumTotalDurationSeconds)"))
        }

        var domainDiagnostics: [AnalysisCorpusDomainCoverageDiagnostic] = []
        for minimum in policy.domainMinimums.sorted(by: { $0.domain < $1.domain }) {
            let candidates = eligible.filter { $0.domains.contains(minimum.domain) }
            let duration = candidates.reduce(0.0) { $0 + $1.durationSeconds }
            let countOK = candidates.count >= minimum.minimumFixtureCount
            let durationOK = duration + 1e-9 >= minimum.minimumTotalDurationSeconds
            domainDiagnostics.append(.init(domain: minimum.domain, eligibleFixtureCount: candidates.count, eligibleTotalDurationSeconds: duration, minimumFixtureCount: minimum.minimumFixtureCount, minimumTotalDurationSeconds: minimum.minimumTotalDurationSeconds, satisfied: countOK && durationOK))
            if !countOK {
                issues.append(.init(code: .domainFixtureDeficit, domain: minimum.domain, detail: "domain fixture count \(candidates.count) is below HQ minimum \(minimum.minimumFixtureCount)"))
            }
            if !durationOK {
                issues.append(.init(code: .domainDurationDeficit, domain: minimum.domain, detail: "domain duration \(duration) is below HQ minimum \(minimum.minimumTotalDurationSeconds)"))
            }
        }

        var stratumDiagnostics: [AnalysisCorpusCoverageDiagnostic] = []
        for stratum in policy.strata.sorted(by: { $0.stratumID < $1.stratumID }) {
            let candidates = eligible.filter { feature in
                feature.domains.contains(stratum.domain) && predicateMatches(stratum.predicate, feature: feature)
            }
            let ids = candidates.map(\.fixtureID).sorted()
            let duration = candidates.reduce(0.0) { $0 + $1.durationSeconds }
            let countOK = ids.count >= stratum.minimumFixtureCount
            let durationOK = duration + 1e-9 >= stratum.minimumTotalDurationSeconds
            let satisfied = countOK && durationOK
            stratumDiagnostics.append(.init(stratumID: stratum.stratumID, domain: stratum.domain, matchedFixtureCount: ids.count, matchedTotalDurationSeconds: duration, minimumFixtureCount: stratum.minimumFixtureCount, minimumTotalDurationSeconds: stratum.minimumTotalDurationSeconds, matchedFixtureIDs: ids, satisfied: satisfied))
            if !countOK {
                issues.append(.init(code: .stratumFixtureDeficit, domain: stratum.domain, stratumID: stratum.stratumID, detail: "stratum fixture count \(ids.count) is below HQ minimum \(stratum.minimumFixtureCount)"))
            }
            if !durationOK {
                issues.append(.init(code: .stratumDurationDeficit, domain: stratum.domain, stratumID: stratum.stratumID, detail: "stratum duration \(duration) is below HQ minimum \(stratum.minimumTotalDurationSeconds)"))
            }
        }

        issues.sort(by: issueOrder)
        let ready = issues.isEmpty && !eligibleFixtureIDs.isEmpty && domainDiagnostics.allSatisfy(\.satisfied) && stratumDiagnostics.allSatisfy(\.satisfied)
        return .init(
            schemaVersion: 1,
            generatedAt: evaluatedAt,
            policyID: policy.policyID,
            manifestID: manifest.manifestID,
            manifestSHA256: normalizedSHA,
            status: ready ? .sufficientPendingHQ : .insufficient,
            comparisonCorpusReady: ready,
            eligibleFixtureCount: eligibleFixtureIDs.count,
            eligibleTotalDurationSeconds: eligibleDuration,
            eligibleFixtureIDs: eligibleFixtureIDs,
            domainDiagnostics: domainDiagnostics,
            stratumDiagnostics: stratumDiagnostics,
            issues: issues
        )
    }

    private static func validatePolicy(_ policy: AnalysisCorpusCoveragePolicy) -> [AnalysisCorpusCoverageIssue] {
        var issues: [AnalysisCorpusCoverageIssue] = []
        func invalid(_ detail: String, domain: String? = nil, stratumID: String? = nil) {
            issues.append(.init(code: .invalidPolicy, domain: domain, stratumID: stratumID, detail: detail))
        }
        if policy.schemaVersion != 1 { invalid("unsupported policy schema_version") }
        if trimmed(policy.policyID).isEmpty { invalid("policy_id is required") }
        if policy.authority != requiredAuthority { invalid("authority must be HQ_LATE_INTEGRATION") }
        if trimmed(policy.approvalReference).isEmpty { invalid("approval_reference is required") }
        if trimmed(policy.expectedManifestID).isEmpty || !isSHA256(policy.expectedManifestSHA256) { invalid("expected manifest id/SHA-256 is invalid") }
        if policy.minimumUniqueFixtureCount < 1 { invalid("minimum_unique_fixture_count must be at least 1") }
        if !policy.minimumTotalDurationSeconds.isFinite || policy.minimumTotalDurationSeconds <= 0 { invalid("minimum_total_duration_seconds must be finite and > 0") }

        var domains = Set<String>()
        for minimum in policy.domainMinimums {
            if !requiredAnalysisDomains.contains(minimum.domain) {
                invalid("domain minimum uses unsupported Analysis domain", domain: minimum.domain)
            }
            if !domains.insert(minimum.domain).inserted {
                issues.append(.init(code: .duplicateDomainMinimum, domain: minimum.domain, detail: "domain minimum must be unique"))
            }
            if minimum.minimumFixtureCount < 1 || !minimum.minimumTotalDurationSeconds.isFinite || minimum.minimumTotalDurationSeconds <= 0 {
                invalid("domain minimum counts/duration must be positive", domain: minimum.domain)
            }
        }
        for domain in requiredAnalysisDomains.subtracting(domains).sorted() {
            issues.append(.init(code: .requiredDomainMissing, domain: domain, detail: "coverage policy must define a minimum for every Analysis domain"))
        }

        if policy.strata.isEmpty { invalid("at least one semantic coverage stratum is required") }
        var stratumIDs = Set<String>()
        for stratum in policy.strata {
            if trimmed(stratum.stratumID).isEmpty {
                invalid("stratum_id is required", domain: stratum.domain)
            } else if !stratumIDs.insert(stratum.stratumID).inserted {
                issues.append(.init(code: .duplicateStratumID, domain: stratum.domain, stratumID: stratum.stratumID, detail: "stratum_id must be unique"))
            }
            if !requiredAnalysisDomains.contains(stratum.domain) {
                invalid("stratum domain is unsupported", domain: stratum.domain, stratumID: stratum.stratumID)
            }
            if stratum.minimumFixtureCount < 1 || !stratum.minimumTotalDurationSeconds.isFinite || stratum.minimumTotalDurationSeconds <= 0 {
                invalid("stratum counts/duration must be positive", domain: stratum.domain, stratumID: stratum.stratumID)
            }
            validatePredicate(stratum.predicate, domain: stratum.domain, stratumID: stratum.stratumID, invalid: invalid)
        }
        return issues
    }

    private static func validatePredicate(
        _ predicate: AnalysisCorpusCoveragePredicate,
        domain: String,
        stratumID: String,
        invalid: (String, String?, String?) -> Void
    ) {
        let hasConstraint = predicate.genreExact != nil || predicate.minimumBPMInclusive != nil || predicate.maximumBPMExclusive != nil || predicate.keyModeExact != nil || !predicate.chordQualitiesAnyOf.isEmpty || predicate.requiresChordInversion != nil || predicate.requiresNoChord != nil || predicate.minimumDistinctChordLabels != nil || predicate.minimumSectionCount != nil || predicate.minimumDistinctStructuralLabels != nil || !predicate.requiredFunctionalLabels.isEmpty || predicate.requiresRepeatedStructuralLabel != nil
        if !hasConstraint { invalid("semantic stratum predicate must contain at least one constraint", domain, stratumID) }
        if let genre = predicate.genreExact, trimmed(genre).isEmpty { invalid("genre_exact cannot be blank", domain, stratumID) }
        if let lower = predicate.minimumBPMInclusive, (!lower.isFinite || lower <= 0) { invalid("minimum_bpm_inclusive must be finite and > 0", domain, stratumID) }
        if let upper = predicate.maximumBPMExclusive, (!upper.isFinite || upper <= 0) { invalid("maximum_bpm_exclusive must be finite and > 0", domain, stratumID) }
        if let lower = predicate.minimumBPMInclusive, let upper = predicate.maximumBPMExclusive, lower >= upper { invalid("tempo band lower bound must be < upper bound", domain, stratumID) }
        if let mode = predicate.keyModeExact, trimmed(mode).isEmpty { invalid("key_mode_exact cannot be blank", domain, stratumID) }

        let allowedQualities = Set(ChordQuality.allCases.map(\.rawValue))
        let qualities = predicate.chordQualitiesAnyOf.map { trimmed($0).lowercased() }
        if Set(qualities).count != qualities.count || qualities.contains(where: { !allowedQualities.contains($0) }) {
            invalid("chord_qualities_any_of contains duplicate or unsupported canonical quality", domain, stratumID)
        }
        if let value = predicate.minimumDistinctChordLabels, value < 1 { invalid("minimum_distinct_chord_labels must be >= 1", domain, stratumID) }
        if let value = predicate.minimumSectionCount, value < 1 { invalid("minimum_section_count must be >= 1", domain, stratumID) }
        if let value = predicate.minimumDistinctStructuralLabels, value < 1 { invalid("minimum_distinct_structural_labels must be >= 1", domain, stratumID) }
        let functional = predicate.requiredFunctionalLabels.map { trimmed($0).lowercased() }
        if functional.contains(where: \.isEmpty) || Set(functional).count != functional.count { invalid("required_functional_labels must be non-empty and unique", domain, stratumID) }
    }

    private struct FixtureFeatures {
        let fixtureID: String
        let genre: String
        let durationSeconds: Double
        let domains: Set<String>
        let bpm: Double?
        let keyMode: String?
        let chordQualities: Set<String>
        let hasChordInversion: Bool
        let hasNoChord: Bool
        let distinctChordLabels: Int
        let sectionCount: Int
        let distinctStructuralLabels: Int
        let functionalLabels: Set<String>
        let hasRepeatedStructuralLabel: Bool
        let eligible: Bool
        let ineligibilityReason: String?
    }

    private static func fixtureFeatures(_ item: AnalysisRealAudioBenchmarkCase, at evaluatedAt: Date) -> FixtureFeatures {
        var qualities = Set<String>()
        var hasInversion = false
        var hasNoChord = false
        var labels = Set<String>()
        for event in item.reference.chords {
            let label = trimmed(event.normalizedLabel)
            if label == "N" { hasNoChord = true; continue }
            if label == "X" || label.isEmpty { continue }
            labels.insert(label)
            if let parsed = ChordLabelNormalizer.parse(label) {
                qualities.insert(parsed.quality.rawValue)
                if let bass = parsed.bass, bass != parsed.root { hasInversion = true }
            }
        }
        let structural = item.reference.sections.map { trimmed($0.structuralLabel).lowercased() }.filter { !$0.isEmpty }
        var structuralCounts: [String: Int] = [:]
        for label in structural { structuralCounts[label, default: 0] += 1 }
        let functional = Set(item.reference.sections.compactMap { section -> String? in
            guard let value = section.functionalLabel else { return nil }
            let normalized = trimmed(value).lowercased()
            return normalized.isEmpty ? nil : normalized
        })
        let canonicalEligible = AnalysisRealAudioManifestValidator.isParityEligible(item, at: evaluatedAt)
        let differentialPermitted = item.rights.permittedUses.contains(.differentialReference)
        let eligible = canonicalEligible && differentialPermitted && item.sourceKind == .realAudio
        let reason: String? = eligible ? nil : (!differentialPermitted ? "rights grant does not permit DIFFERENTIAL_REFERENCE" : "fixture is synthetic or fails canonical rights/manifest eligibility")
        return .init(
            fixtureID: item.fixtureID,
            genre: trimmed(item.genre).lowercased(),
            durationSeconds: item.expectedDurationSeconds,
            domains: item.reference.coveredDomains,
            bpm: item.reference.bpm,
            keyMode: item.reference.key.map { trimmed($0.mode).lowercased() },
            chordQualities: qualities,
            hasChordInversion: hasInversion,
            hasNoChord: hasNoChord,
            distinctChordLabels: labels.count,
            sectionCount: item.reference.sections.count,
            distinctStructuralLabels: Set(structural).count,
            functionalLabels: functional,
            hasRepeatedStructuralLabel: structuralCounts.values.contains(where: { $0 >= 2 }),
            eligible: eligible,
            ineligibilityReason: reason
        )
    }

    private static func predicateMatches(_ predicate: AnalysisCorpusCoveragePredicate, feature: FixtureFeatures) -> Bool {
        if let genre = predicate.genreExact, feature.genre != trimmed(genre).lowercased() { return false }
        if predicate.minimumBPMInclusive != nil || predicate.maximumBPMExclusive != nil {
            guard let bpm = feature.bpm else { return false }
            if let lower = predicate.minimumBPMInclusive, bpm < lower { return false }
            if let upper = predicate.maximumBPMExclusive, bpm >= upper { return false }
        }
        if let mode = predicate.keyModeExact, feature.keyMode != trimmed(mode).lowercased() { return false }
        if !predicate.chordQualitiesAnyOf.isEmpty {
            let required = Set(predicate.chordQualitiesAnyOf.map { trimmed($0).lowercased() })
            if feature.chordQualities.isDisjoint(with: required) { return false }
        }
        if let required = predicate.requiresChordInversion, feature.hasChordInversion != required { return false }
        if let required = predicate.requiresNoChord, feature.hasNoChord != required { return false }
        if let minimum = predicate.minimumDistinctChordLabels, feature.distinctChordLabels < minimum { return false }
        if let minimum = predicate.minimumSectionCount, feature.sectionCount < minimum { return false }
        if let minimum = predicate.minimumDistinctStructuralLabels, feature.distinctStructuralLabels < minimum { return false }
        if !predicate.requiredFunctionalLabels.isEmpty {
            let required = Set(predicate.requiredFunctionalLabels.map { trimmed($0).lowercased() })
            if !required.isSubset(of: feature.functionalLabels) { return false }
        }
        if let required = predicate.requiresRepeatedStructuralLabel, feature.hasRepeatedStructuralLabel != required { return false }
        return true
    }

    private static func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func isSHA256(_ value: String) -> Bool {
        guard value.count == 64 else { return false }
        return value.unicodeScalars.allSatisfy { scalar in
            (48...57).contains(scalar.value) || (97...102).contains(scalar.value) || (65...70).contains(scalar.value)
        }
    }

    private static func issueOrder(_ lhs: AnalysisCorpusCoverageIssue, _ rhs: AnalysisCorpusCoverageIssue) -> Bool {
        let left = "\(lhs.code.rawValue)|\(lhs.domain ?? "")|\(lhs.stratumID ?? "")|\(lhs.fixtureID ?? "")|\(lhs.detail)"
        let right = "\(rhs.code.rawValue)|\(rhs.domain ?? "")|\(rhs.stratumID ?? "")|\(rhs.fixtureID ?? "")|\(rhs.detail)"
        return left < right
    }
}

public enum AnalysisCorpusCoverageCodec {
    public static func encodePolicy(_ policy: AnalysisCorpusCoveragePolicy) throws -> Data { try makeEncoder().encode(policy) }
    public static func decodePolicy(_ data: Data) throws -> AnalysisCorpusCoveragePolicy { try makeDecoder().decode(AnalysisCorpusCoveragePolicy.self, from: data) }
    public static func encodeReport(_ report: AnalysisCorpusCoverageReport) throws -> Data { try makeEncoder().encode(report) }
    public static func decodeReport(_ data: Data) throws -> AnalysisCorpusCoverageReport { try makeDecoder().decode(AnalysisCorpusCoverageReport.self, from: data) }

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

import Foundation

public enum AnalysisDeviceCorpusSelectionEvaluator {
    public static let requiredAuthority = "HQ_LATE_INTEGRATION"

    public static func evaluate(
        manifest: AnalysisRealAudioBenchmarkManifest,
        manifestSHA256: String,
        coveragePolicy: AnalysisCorpusCoveragePolicy,
        selectionPolicy: AnalysisDeviceCorpusSelectionPolicy,
        performanceProfile: AnalysisDevicePerformanceAcceptanceProfile,
        workloadPolicy: AnalysisDeviceWorkloadPolicy,
        evaluatedAt: Date = Date()
    ) -> AnalysisDeviceCorpusSelectionReport {
        var issues = validatePolicy(selectionPolicy, coveragePolicy: coveragePolicy)
        let normalizedManifestSHA = manifestSHA256.lowercased()

        if selectionPolicy.expectedCoveragePolicyID != coveragePolicy.policyID {
            issues.append(.init(code: .coveragePolicyBindingMismatch, detail: "selection policy must bind the exact HQ-approved W22 coverage policy ID"))
        }
        if selectionPolicy.expectedManifestID != manifest.manifestID ||
            selectionPolicy.expectedManifestID != coveragePolicy.expectedManifestID ||
            selectionPolicy.expectedManifestSHA256 != normalizedManifestSHA ||
            selectionPolicy.expectedManifestSHA256 != coveragePolicy.expectedManifestSHA256 ||
            !isSHA256(normalizedManifestSHA) {
            issues.append(.init(code: .manifestBindingMismatch, detail: "selection, W22 coverage policy and manifest must share exact manifest ID/SHA-256"))
        }

        let w22 = AnalysisCorpusCoverageValidator.validate(
            manifest: manifest,
            manifestSHA256: normalizedManifestSHA,
            policy: coveragePolicy,
            evaluatedAt: evaluatedAt
        )
        if !w22.comparisonCorpusReady || w22.status != .sufficientPendingHQ || !w22.issues.isEmpty {
            issues.append(.init(code: .w22CorpusNotReady, detail: "W22 corpus must be canonical, rights-eligible and sufficient before physical-performance selection"))
        }

        let eligibleIDs = Set(w22.eligibleFixtureIDs)
        let selectedIDs = selectedFixtureIDs(selectionPolicy, eligibleIDs: eligibleIDs, issues: &issues)
        let manifestByID = firstManifestCaseByFixtureID(manifest.cases)

        for id in selectedIDs where !eligibleIDs.contains(id) {
            issues.append(.init(code: .selectedFixtureNotEligible, fixtureID: id, detail: "physical-performance fixture is absent from the W22 eligible corpus"))
        }

        let selectedCases = selectedIDs.compactMap { manifestByID[$0] }
        let selectedTotalDuration = selectedCases.reduce(0.0) { $0 + $1.expectedDurationSeconds }

        let globalMinimumCount: Int
        let globalMinimumDuration: Double
        if selectionPolicy.mode == .fullW22EligibleCorpus {
            globalMinimumCount = coveragePolicy.minimumUniqueFixtureCount
            globalMinimumDuration = coveragePolicy.minimumTotalDurationSeconds
        } else {
            globalMinimumCount = selectionPolicy.minimumSelectedFixtureCount
            globalMinimumDuration = selectionPolicy.minimumSelectedTotalDurationSeconds
        }
        if selectedIDs.count < globalMinimumCount || selectedTotalDuration + 1e-9 < globalMinimumDuration {
            issues.append(.init(code: .globalSelectionDeficit, detail: "selected physical corpus is below the HQ-approved global selection minimum"))
        }

        let domainMinimums = effectiveDomainMinimums(selectionPolicy, coveragePolicy: coveragePolicy)
        var domainDiagnostics: [AnalysisDeviceCorpusDomainDiagnostic] = []
        for requirement in domainMinimums.sorted(by: { $0.domain < $1.domain }) {
            let matches = selectedCases.filter { $0.reference.coveredDomains.contains(requirement.domain) }
            let ids = matches.map(\.fixtureID).sorted()
            let duration = matches.reduce(0.0) { $0 + $1.expectedDurationSeconds }
            let satisfied = ids.count >= requirement.minimumSelectedFixtureCount && duration + 1e-9 >= requirement.minimumSelectedDurationSeconds
            domainDiagnostics.append(.init(
                domain: requirement.domain,
                selectedFixtureCount: ids.count,
                selectedDurationSeconds: duration,
                minimumFixtureCount: requirement.minimumSelectedFixtureCount,
                minimumDurationSeconds: requirement.minimumSelectedDurationSeconds,
                selectedFixtureIDs: ids,
                satisfied: satisfied
            ))
            if !satisfied {
                issues.append(.init(code: .domainSelectionDeficit, domain: requirement.domain, detail: "selected physical corpus does not meet the HQ-approved domain selection minimum"))
            }
        }

        let w22Strata = firstStratumDiagnosticByID(w22.stratumDiagnostics)
        let stratumMinimums = effectiveStratumMinimums(selectionPolicy, coveragePolicy: coveragePolicy)
        var stratumDiagnostics: [AnalysisDeviceCorpusStratumDiagnostic] = []
        for requirement in stratumMinimums.sorted(by: { $0.stratumID < $1.stratumID }) {
            let eligibleForStratum = Set(w22Strata[requirement.stratumID]?.matchedFixtureIDs ?? [])
            let ids = selectedIDs.filter { eligibleForStratum.contains($0) }.sorted()
            let duration = ids.compactMap { manifestByID[$0]?.expectedDurationSeconds }.reduce(0.0, +)
            let satisfied = ids.count >= requirement.minimumSelectedFixtureCount && duration + 1e-9 >= requirement.minimumSelectedDurationSeconds
            stratumDiagnostics.append(.init(
                stratumID: requirement.stratumID,
                selectedFixtureCount: ids.count,
                selectedDurationSeconds: duration,
                minimumFixtureCount: requirement.minimumSelectedFixtureCount,
                minimumDurationSeconds: requirement.minimumSelectedDurationSeconds,
                selectedFixtureIDs: ids,
                satisfied: satisfied
            ))
            if !satisfied {
                issues.append(.init(code: .stratumSelectionDeficit, stratumID: requirement.stratumID, detail: "selected physical corpus does not meet the HQ-approved W22 stratum selection minimum"))
            }
        }

        validatePerformanceProfile(performanceProfile, selectedIDs: selectedIDs, manifest: manifest, manifestSHA256: normalizedManifestSHA, manifestByID: manifestByID, issues: &issues)
        validateWorkloadPolicy(workloadPolicy, selectedIDs: selectedIDs, manifest: manifest, manifestSHA256: normalizedManifestSHA, manifestByID: manifestByID, issues: &issues)

        let stratumIDsByFixture = makeStratumIDsByFixture(w22.stratumDiagnostics)
        let fixtureDiagnostics = selectedIDs.sorted().compactMap { id -> AnalysisDeviceCorpusSelectedFixtureDiagnostic? in
            guard let item = manifestByID[id] else { return nil }
            return .init(
                fixtureID: id,
                sourceSHA256: item.rights.sourceSHA256.lowercased(),
                durationSeconds: item.expectedDurationSeconds,
                coveredDomains: item.reference.coveredDomains.sorted(),
                matchedStratumIDs: (stratumIDsByFixture[id] ?? []).sorted()
            )
        }

        issues.sort(by: issueOrder)
        let status: AnalysisDeviceCorpusSelectionStatus
        if issues.contains(where: { $0.code == .invalidPolicy || $0.code == .coveragePolicyBindingMismatch || $0.code == .manifestBindingMismatch || $0.code == .duplicateDomainRequirement || $0.code == .missingDomainRequirement || $0.code == .unknownDomainRequirement || $0.code == .duplicateStratumRequirement || $0.code == .missingStratumRequirement || $0.code == .unknownStratumRequirement || $0.code == .duplicateSelectedFixture }) {
            status = .invalidPolicy
        } else if issues.contains(where: { $0.code == .w22CorpusNotReady }) {
            status = .w22CorpusNotReady
        } else if !issues.isEmpty {
            status = .selectionIncomplete
        } else {
            status = .selectionReadyPendingHQ
        }

        return .init(
            schemaVersion: 1,
            generatedAt: evaluatedAt,
            policyID: selectionPolicy.policyID,
            coveragePolicyID: coveragePolicy.policyID,
            manifestID: manifest.manifestID,
            manifestSHA256: normalizedManifestSHA,
            status: status,
            selectedFixtureCount: selectedIDs.count,
            selectedTotalDurationSeconds: selectedTotalDuration,
            selectedFixtureIDs: selectedIDs.sorted(),
            fixtureDiagnostics: fixtureDiagnostics,
            domainDiagnostics: domainDiagnostics,
            stratumDiagnostics: stratumDiagnostics,
            issues: issues
        )
    }

    private static func validatePolicy(
        _ policy: AnalysisDeviceCorpusSelectionPolicy,
        coveragePolicy: AnalysisCorpusCoveragePolicy
    ) -> [AnalysisDeviceCorpusSelectionIssue] {
        var issues: [AnalysisDeviceCorpusSelectionIssue] = []
        func invalid(_ detail: String) { issues.append(.init(code: .invalidPolicy, detail: detail)) }

        if policy.schemaVersion != 1 { invalid("selection policy schema must equal 1") }
        if policy.authority != requiredAuthority { invalid("selection policy authority must be HQ_LATE_INTEGRATION") }
        if trimmed(policy.policyID).isEmpty || trimmed(policy.approvalReference).isEmpty || trimmed(policy.expectedCoveragePolicyID).isEmpty || trimmed(policy.expectedManifestID).isEmpty || !isSHA256(policy.expectedManifestSHA256) {
            invalid("selection policy requires nonempty IDs/approval and a valid manifest SHA-256")
        }

        switch policy.mode {
        case .fullW22EligibleCorpus:
            if !policy.exactSelectedFixtureIDs.isEmpty || policy.minimumSelectedFixtureCount != 0 || policy.minimumSelectedTotalDurationSeconds != 0 || !policy.domainRequirements.isEmpty || !policy.stratumRequirements.isEmpty {
                invalid("FULL_W22_ELIGIBLE_CORPUS derives selection and minima from W22; subset-only fields must be empty/zero")
            }
        case .hqApprovedExactSubset:
            if policy.exactSelectedFixtureIDs.isEmpty || policy.minimumSelectedFixtureCount < 1 || !policy.minimumSelectedTotalDurationSeconds.isFinite || policy.minimumSelectedTotalDurationSeconds <= 0 {
                invalid("HQ_APPROVED_EXACT_SUBSET requires an exact fixture list and positive global selection minima")
            }
            if policy.minimumSelectedFixtureCount < coveragePolicy.minimumUniqueFixtureCount || policy.minimumSelectedTotalDurationSeconds + 1e-9 < coveragePolicy.minimumTotalDurationSeconds {
                invalid("exact-subset global minima must not weaken the bound HQ-approved W22 corpus minima")
            }
            validateDomainRequirements(policy.domainRequirements, coveragePolicy: coveragePolicy, issues: &issues)
            validateStratumRequirements(policy.stratumRequirements, coveragePolicy: coveragePolicy, issues: &issues)
        }
        return issues
    }

    private static func validateDomainRequirements(
        _ requirements: [AnalysisDeviceCorpusDomainRequirement],
        coveragePolicy: AnalysisCorpusCoveragePolicy,
        issues: inout [AnalysisDeviceCorpusSelectionIssue]
    ) {
        let floors = firstDomainMinimumByName(coveragePolicy.domainMinimums)
        var seen = Set<String>()
        for requirement in requirements {
            if !AnalysisCorpusCoverageValidator.requiredAnalysisDomains.contains(requirement.domain) {
                issues.append(.init(code: .unknownDomainRequirement, domain: requirement.domain, detail: "selection domain is not a canonical Analysis domain"))
            }
            if !seen.insert(requirement.domain).inserted {
                issues.append(.init(code: .duplicateDomainRequirement, domain: requirement.domain, detail: "selection domain requirement must be unique"))
            }
            if requirement.minimumSelectedFixtureCount < 1 || !requirement.minimumSelectedDurationSeconds.isFinite || requirement.minimumSelectedDurationSeconds <= 0 {
                issues.append(.init(code: .invalidPolicy, domain: requirement.domain, detail: "selection domain minima must be positive"))
            }
            if let floor = floors[requirement.domain], (requirement.minimumSelectedFixtureCount < floor.minimumFixtureCount || requirement.minimumSelectedDurationSeconds + 1e-9 < floor.minimumTotalDurationSeconds) {
                issues.append(.init(code: .invalidPolicy, domain: requirement.domain, detail: "selection domain minima must not weaken the bound HQ-approved W22 minimum"))
            }
        }
        for domain in AnalysisCorpusCoverageValidator.requiredAnalysisDomains.subtracting(seen).sorted() {
            issues.append(.init(code: .missingDomainRequirement, domain: domain, detail: "exact-subset policy must explicitly cover every canonical Analysis domain"))
        }
    }

    private static func validateStratumRequirements(
        _ requirements: [AnalysisDeviceCorpusStratumRequirement],
        coveragePolicy: AnalysisCorpusCoveragePolicy,
        issues: inout [AnalysisDeviceCorpusSelectionIssue]
    ) {
        let known = Set(coveragePolicy.strata.map(\.stratumID))
        let floors = firstStratumMinimumByID(coveragePolicy.strata)
        var seen = Set<String>()
        for requirement in requirements {
            if !known.contains(requirement.stratumID) {
                issues.append(.init(code: .unknownStratumRequirement, stratumID: requirement.stratumID, detail: "selection stratum does not exist in the bound W22 policy"))
            }
            if !seen.insert(requirement.stratumID).inserted {
                issues.append(.init(code: .duplicateStratumRequirement, stratumID: requirement.stratumID, detail: "selection stratum requirement must be unique"))
            }
            if requirement.minimumSelectedFixtureCount < 1 || !requirement.minimumSelectedDurationSeconds.isFinite || requirement.minimumSelectedDurationSeconds <= 0 {
                issues.append(.init(code: .invalidPolicy, stratumID: requirement.stratumID, detail: "selection stratum minima must be positive"))
            }
            if let floor = floors[requirement.stratumID], (requirement.minimumSelectedFixtureCount < floor.minimumFixtureCount || requirement.minimumSelectedDurationSeconds + 1e-9 < floor.minimumTotalDurationSeconds) {
                issues.append(.init(code: .invalidPolicy, stratumID: requirement.stratumID, detail: "selection stratum minima must not weaken the bound HQ-approved W22 minimum"))
            }
        }
        for id in known.subtracting(seen).sorted() {
            issues.append(.init(code: .missingStratumRequirement, stratumID: id, detail: "exact-subset policy must explicitly cover every W22 stratum"))
        }
    }

    private static func selectedFixtureIDs(
        _ policy: AnalysisDeviceCorpusSelectionPolicy,
        eligibleIDs: Set<String>,
        issues: inout [AnalysisDeviceCorpusSelectionIssue]
    ) -> Set<String> {
        if policy.mode == .fullW22EligibleCorpus { return eligibleIDs }
        var selected = Set<String>()
        for id in policy.exactSelectedFixtureIDs {
            if !selected.insert(id).inserted {
                issues.append(.init(code: .duplicateSelectedFixture, fixtureID: id, detail: "exact physical fixture selection must not contain duplicates"))
            }
        }
        return selected
    }

    private static func effectiveDomainMinimums(
        _ selection: AnalysisDeviceCorpusSelectionPolicy,
        coveragePolicy: AnalysisCorpusCoveragePolicy
    ) -> [AnalysisDeviceCorpusDomainRequirement] {
        if selection.mode == .hqApprovedExactSubset { return selection.domainRequirements }
        return coveragePolicy.domainMinimums.map {
            .init(domain: $0.domain, minimumSelectedFixtureCount: $0.minimumFixtureCount, minimumSelectedDurationSeconds: $0.minimumTotalDurationSeconds)
        }
    }

    private static func effectiveStratumMinimums(
        _ selection: AnalysisDeviceCorpusSelectionPolicy,
        coveragePolicy: AnalysisCorpusCoveragePolicy
    ) -> [AnalysisDeviceCorpusStratumRequirement] {
        if selection.mode == .hqApprovedExactSubset { return selection.stratumRequirements }
        return coveragePolicy.strata.map {
            .init(stratumID: $0.stratumID, minimumSelectedFixtureCount: $0.minimumFixtureCount, minimumSelectedDurationSeconds: $0.minimumTotalDurationSeconds)
        }
    }

    private static func validatePerformanceProfile(
        _ profile: AnalysisDevicePerformanceAcceptanceProfile,
        selectedIDs: Set<String>,
        manifest: AnalysisRealAudioBenchmarkManifest,
        manifestSHA256: String,
        manifestByID: [String: AnalysisRealAudioBenchmarkCase],
        issues: inout [AnalysisDeviceCorpusSelectionIssue]
    ) {
        if profile.expectedManifestID != manifest.manifestID || profile.expectedManifestSHA256.lowercased() != manifestSHA256 {
            issues.append(.init(code: .performanceProfileBindingMismatch, detail: "W24 profile must bind the same manifest as W22/W26"))
        }
        let required = Set(profile.requiredFixtureIDs)
        if required != selectedIDs || required.count != profile.requiredFixtureIDs.count {
            issues.append(.init(code: .performanceProfileBindingMismatch, detail: "W24 required fixtures must exactly equal the W26 physical selection"))
        }
        if Set(profile.expectedFixtureDurationsSeconds.keys) != selectedIDs {
            issues.append(.init(code: .performanceProfileBindingMismatch, detail: "W24 fixture-duration inventory must exactly equal the W26 physical selection"))
        }
        for id in selectedIDs.sorted() {
            guard let expected = manifestByID[id]?.expectedDurationSeconds else { continue }
            guard let actual = profile.expectedFixtureDurationsSeconds[id], approximatelyEqual(actual, expected) else {
                issues.append(.init(code: .durationBindingMismatch, fixtureID: id, detail: "W24 fixture duration does not match the canonical W22 manifest"))
                continue
            }
        }
        if profile.plannedRuns.contains(where: { !selectedIDs.contains($0.fixtureID) }) {
            issues.append(.init(code: .performanceProfileBindingMismatch, detail: "W24 planned run inventory contains a fixture outside W26 selection"))
        }
    }

    private static func validateWorkloadPolicy(
        _ policy: AnalysisDeviceWorkloadPolicy,
        selectedIDs: Set<String>,
        manifest: AnalysisRealAudioBenchmarkManifest,
        manifestSHA256: String,
        manifestByID: [String: AnalysisRealAudioBenchmarkCase],
        issues: inout [AnalysisDeviceCorpusSelectionIssue]
    ) {
        if policy.manifestID != manifest.manifestID || policy.manifestSHA256.lowercased() != manifestSHA256 {
            issues.append(.init(code: .workloadPolicyBindingMismatch, detail: "W25 workload policy must bind the same manifest as W22/W26"))
        }
        if Set(policy.fixtures.keys) != selectedIDs {
            issues.append(.init(code: .workloadPolicyBindingMismatch, detail: "W25 workload fixture inventory must exactly equal the W26 physical selection"))
        }
        for id in selectedIDs.sorted() {
            guard let canonical = manifestByID[id], let workload = policy.fixtures[id] else { continue }
            if workload.fixtureID != id || workload.sourceSHA256.lowercased() != canonical.rights.sourceSHA256.lowercased() {
                issues.append(.init(code: .sourceBindingMismatch, fixtureID: id, detail: "W25 source SHA/fixture binding does not match the canonical W22 manifest"))
            }
            if !approximatelyEqual(workload.sourceDurationSeconds, canonical.expectedDurationSeconds) {
                issues.append(.init(code: .durationBindingMismatch, fixtureID: id, detail: "W25 source duration does not match the canonical W22 manifest"))
            }
        }
    }

    private static func firstDomainMinimumByName(
        _ values: [AnalysisCorpusCoverageDomainMinimum]
    ) -> [String: AnalysisCorpusCoverageDomainMinimum] {
        var output: [String: AnalysisCorpusCoverageDomainMinimum] = [:]
        for item in values where output[item.domain] == nil { output[item.domain] = item }
        return output
    }

    private static func firstStratumMinimumByID(
        _ values: [AnalysisCorpusCoverageStratum]
    ) -> [String: AnalysisCorpusCoverageStratum] {
        var output: [String: AnalysisCorpusCoverageStratum] = [:]
        for item in values where output[item.stratumID] == nil { output[item.stratumID] = item }
        return output
    }

    private static func firstManifestCaseByFixtureID(
        _ cases: [AnalysisRealAudioBenchmarkCase]
    ) -> [String: AnalysisRealAudioBenchmarkCase] {
        var output: [String: AnalysisRealAudioBenchmarkCase] = [:]
        for item in cases where output[item.fixtureID] == nil { output[item.fixtureID] = item }
        return output
    }

    private static func firstStratumDiagnosticByID(
        _ diagnostics: [AnalysisCorpusCoverageDiagnostic]
    ) -> [String: AnalysisCorpusCoverageDiagnostic] {
        var output: [String: AnalysisCorpusCoverageDiagnostic] = [:]
        for item in diagnostics where output[item.stratumID] == nil { output[item.stratumID] = item }
        return output
    }

    private static func makeStratumIDsByFixture(
        _ diagnostics: [AnalysisCorpusCoverageDiagnostic]
    ) -> [String: Set<String>] {
        var output: [String: Set<String>] = [:]
        for diagnostic in diagnostics {
            for id in diagnostic.matchedFixtureIDs {
                output[id, default: []].insert(diagnostic.stratumID)
            }
        }
        return output
    }

    private static func approximatelyEqual(_ lhs: Double, _ rhs: Double) -> Bool {
        guard lhs.isFinite, rhs.isFinite else { return false }
        let scale = max(1.0, abs(lhs), abs(rhs))
        return abs(lhs - rhs) <= 1e-9 * scale
    }

    private static func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func isSHA256(_ value: String) -> Bool {
        value.count == 64 && value.unicodeScalars.allSatisfy { scalar in
            switch scalar.value {
            case 48...57, 65...70, 97...102: return true
            default: return false
            }
        }
    }

    private static func issueOrder(_ lhs: AnalysisDeviceCorpusSelectionIssue, _ rhs: AnalysisDeviceCorpusSelectionIssue) -> Bool {
        let left = "\(lhs.code.rawValue)|\(lhs.fixtureID ?? "")|\(lhs.domain ?? "")|\(lhs.stratumID ?? "")|\(lhs.detail)"
        let right = "\(rhs.code.rawValue)|\(rhs.fixtureID ?? "")|\(rhs.domain ?? "")|\(rhs.stratumID ?? "")|\(rhs.detail)"
        return left < right
    }
}

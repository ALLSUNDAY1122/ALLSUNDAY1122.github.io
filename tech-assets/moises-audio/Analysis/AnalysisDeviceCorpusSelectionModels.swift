import Foundation

public enum AnalysisDeviceCorpusSelectionMode: String, Codable, Sendable {
    case fullW22EligibleCorpus = "FULL_W22_ELIGIBLE_CORPUS"
    case hqApprovedExactSubset = "HQ_APPROVED_EXACT_SUBSET"
}

public struct AnalysisDeviceCorpusDomainRequirement: Codable, Equatable, Sendable {
    public let domain: String
    public let minimumSelectedFixtureCount: Int
    public let minimumSelectedDurationSeconds: Double

    public init(domain: String, minimumSelectedFixtureCount: Int, minimumSelectedDurationSeconds: Double) {
        self.domain = domain
        self.minimumSelectedFixtureCount = minimumSelectedFixtureCount
        self.minimumSelectedDurationSeconds = minimumSelectedDurationSeconds
    }
}

public struct AnalysisDeviceCorpusStratumRequirement: Codable, Equatable, Sendable {
    public let stratumID: String
    public let minimumSelectedFixtureCount: Int
    public let minimumSelectedDurationSeconds: Double

    public init(stratumID: String, minimumSelectedFixtureCount: Int, minimumSelectedDurationSeconds: Double) {
        self.stratumID = stratumID
        self.minimumSelectedFixtureCount = minimumSelectedFixtureCount
        self.minimumSelectedDurationSeconds = minimumSelectedDurationSeconds
    }
}

public struct AnalysisDeviceCorpusSelectionPolicy: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let policyID: String
    public let authority: String
    public let approvalReference: String
    public let expectedCoveragePolicyID: String
    public let expectedManifestID: String
    public let expectedManifestSHA256: String
    public let mode: AnalysisDeviceCorpusSelectionMode
    public let exactSelectedFixtureIDs: [String]
    public let minimumSelectedFixtureCount: Int
    public let minimumSelectedTotalDurationSeconds: Double
    public let domainRequirements: [AnalysisDeviceCorpusDomainRequirement]
    public let stratumRequirements: [AnalysisDeviceCorpusStratumRequirement]

    public init(
        schemaVersion: Int = 1,
        policyID: String,
        authority: String,
        approvalReference: String,
        expectedCoveragePolicyID: String,
        expectedManifestID: String,
        expectedManifestSHA256: String,
        mode: AnalysisDeviceCorpusSelectionMode,
        exactSelectedFixtureIDs: [String],
        minimumSelectedFixtureCount: Int,
        minimumSelectedTotalDurationSeconds: Double,
        domainRequirements: [AnalysisDeviceCorpusDomainRequirement],
        stratumRequirements: [AnalysisDeviceCorpusStratumRequirement]
    ) {
        self.schemaVersion = schemaVersion
        self.policyID = policyID
        self.authority = authority
        self.approvalReference = approvalReference
        self.expectedCoveragePolicyID = expectedCoveragePolicyID
        self.expectedManifestID = expectedManifestID
        self.expectedManifestSHA256 = expectedManifestSHA256.lowercased()
        self.mode = mode
        self.exactSelectedFixtureIDs = exactSelectedFixtureIDs
        self.minimumSelectedFixtureCount = minimumSelectedFixtureCount
        self.minimumSelectedTotalDurationSeconds = minimumSelectedTotalDurationSeconds
        self.domainRequirements = domainRequirements
        self.stratumRequirements = stratumRequirements
    }
}

public enum AnalysisDeviceCorpusSelectionIssueCode: String, Codable, Hashable, Sendable {
    case invalidPolicy = "INVALID_SELECTION_POLICY"
    case coveragePolicyBindingMismatch = "COVERAGE_POLICY_BINDING_MISMATCH"
    case manifestBindingMismatch = "MANIFEST_BINDING_MISMATCH"
    case w22CorpusNotReady = "W22_CORPUS_NOT_READY"
    case duplicateSelectedFixture = "DUPLICATE_SELECTED_FIXTURE"
    case selectedFixtureNotEligible = "SELECTED_FIXTURE_NOT_W22_ELIGIBLE"
    case duplicateDomainRequirement = "DUPLICATE_DOMAIN_REQUIREMENT"
    case missingDomainRequirement = "MISSING_DOMAIN_REQUIREMENT"
    case unknownDomainRequirement = "UNKNOWN_DOMAIN_REQUIREMENT"
    case duplicateStratumRequirement = "DUPLICATE_STRATUM_REQUIREMENT"
    case missingStratumRequirement = "MISSING_STRATUM_REQUIREMENT"
    case unknownStratumRequirement = "UNKNOWN_STRATUM_REQUIREMENT"
    case globalSelectionDeficit = "GLOBAL_SELECTION_DEFICIT"
    case domainSelectionDeficit = "DOMAIN_SELECTION_DEFICIT"
    case stratumSelectionDeficit = "STRATUM_SELECTION_DEFICIT"
    case performanceProfileBindingMismatch = "PERFORMANCE_PROFILE_BINDING_MISMATCH"
    case workloadPolicyBindingMismatch = "WORKLOAD_POLICY_BINDING_MISMATCH"
    case sourceBindingMismatch = "SOURCE_BINDING_MISMATCH"
    case durationBindingMismatch = "DURATION_BINDING_MISMATCH"
}

public struct AnalysisDeviceCorpusSelectionIssue: Codable, Equatable, Sendable {
    public let code: AnalysisDeviceCorpusSelectionIssueCode
    public let fixtureID: String?
    public let domain: String?
    public let stratumID: String?
    public let detail: String

    public init(
        code: AnalysisDeviceCorpusSelectionIssueCode,
        fixtureID: String? = nil,
        domain: String? = nil,
        stratumID: String? = nil,
        detail: String
    ) {
        self.code = code
        self.fixtureID = fixtureID
        self.domain = domain
        self.stratumID = stratumID
        self.detail = detail
    }
}

public struct AnalysisDeviceCorpusSelectedFixtureDiagnostic: Codable, Equatable, Sendable {
    public let fixtureID: String
    public let sourceSHA256: String
    public let durationSeconds: Double
    public let coveredDomains: [String]
    public let matchedStratumIDs: [String]
}

public struct AnalysisDeviceCorpusDomainDiagnostic: Codable, Equatable, Sendable {
    public let domain: String
    public let selectedFixtureCount: Int
    public let selectedDurationSeconds: Double
    public let minimumFixtureCount: Int
    public let minimumDurationSeconds: Double
    public let selectedFixtureIDs: [String]
    public let satisfied: Bool
}

public struct AnalysisDeviceCorpusStratumDiagnostic: Codable, Equatable, Sendable {
    public let stratumID: String
    public let selectedFixtureCount: Int
    public let selectedDurationSeconds: Double
    public let minimumFixtureCount: Int
    public let minimumDurationSeconds: Double
    public let selectedFixtureIDs: [String]
    public let satisfied: Bool
}

public enum AnalysisDeviceCorpusSelectionStatus: String, Codable, Sendable {
    case invalidPolicy = "INVALID_SELECTION_POLICY"
    case w22CorpusNotReady = "W22_CORPUS_NOT_READY"
    case selectionIncomplete = "PHYSICAL_SELECTION_INCOMPLETE"
    case selectionReadyPendingHQ = "PHYSICAL_SELECTION_READY_PENDING_HQ"
}

public struct AnalysisDeviceCorpusSelectionReport: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let generatedAt: Date
    public let policyID: String
    public let coveragePolicyID: String
    public let manifestID: String
    public let manifestSHA256: String
    public let status: AnalysisDeviceCorpusSelectionStatus
    public let selectedFixtureCount: Int
    public let selectedTotalDurationSeconds: Double
    public let selectedFixtureIDs: [String]
    public let fixtureDiagnostics: [AnalysisDeviceCorpusSelectedFixtureDiagnostic]
    public let domainDiagnostics: [AnalysisDeviceCorpusDomainDiagnostic]
    public let stratumDiagnostics: [AnalysisDeviceCorpusStratumDiagnostic]
    public let issues: [AnalysisDeviceCorpusSelectionIssue]
}

public struct AnalysisDeviceCorpusBoundPerformanceGateReport: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let corpusSelection: AnalysisDeviceCorpusSelectionReport
    public let workloadAndPerformance: AnalysisDevicePerformanceWorkloadGateReport?

    public init(
        schemaVersion: Int = 1,
        corpusSelection: AnalysisDeviceCorpusSelectionReport,
        workloadAndPerformance: AnalysisDevicePerformanceWorkloadGateReport?
    ) {
        self.schemaVersion = schemaVersion
        self.corpusSelection = corpusSelection
        self.workloadAndPerformance = workloadAndPerformance
    }
}

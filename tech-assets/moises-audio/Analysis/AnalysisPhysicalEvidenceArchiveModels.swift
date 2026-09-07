import Foundation

public enum AnalysisPhysicalEvidenceArtifactRole: String, Codable, CaseIterable, Sendable {
    case goldenManifest = "GOLDEN_MANIFEST"
    case w22CoveragePolicy = "W22_COVERAGE_POLICY"
    case w22CoverageReport = "W22_COVERAGE_REPORT"
    case w26SelectionPolicy = "W26_SELECTION_POLICY"
    case w26SelectionReport = "W26_SELECTION_REPORT"
    case w24PerformanceProfile = "W24_PERFORMANCE_PROFILE"
    case w24PerformanceBatch = "W24_PERFORMANCE_BATCH"
    case w24AcceptanceReport = "W24_ACCEPTANCE_REPORT"
    case w25WorkloadPolicy = "W25_WORKLOAD_POLICY"
    case buildCorroboration = "BUILD_CORROBORATION"
    case deviceCorroboration = "DEVICE_CORROBORATION"
    case w23RawTelemetry = "W23_RAW_TELEMETRY"
    case w23ValidationReport = "W23_VALIDATION_REPORT"
    case w25WorkloadReceipt = "W25_WORKLOAD_RECEIPT"
    case w25WorkloadValidationReport = "W25_WORKLOAD_VALIDATION_REPORT"

    public var isPerRun: Bool {
        switch self {
        case .w23RawTelemetry, .w23ValidationReport, .w25WorkloadReceipt, .w25WorkloadValidationReport:
            return true
        default:
            return false
        }
    }

    public static let requiredSingletonRoles: Set<Self> = [
        .goldenManifest, .w22CoveragePolicy, .w22CoverageReport,
        .w26SelectionPolicy, .w26SelectionReport,
        .w24PerformanceProfile, .w24PerformanceBatch, .w24AcceptanceReport,
        .w25WorkloadPolicy, .buildCorroboration, .deviceCorroboration
    ]

    public static let requiredPerRunRoles: Set<Self> = [
        .w23RawTelemetry, .w23ValidationReport, .w25WorkloadReceipt, .w25WorkloadValidationReport
    ]
}

public struct AnalysisPhysicalEvidenceArchiveEntry: Codable, Equatable, Sendable {
    public let role: AnalysisPhysicalEvidenceArtifactRole
    public let relativePath: String
    public let sha256: String
    public let byteLength: UInt64
    public let runID: String?

    public init(role: AnalysisPhysicalEvidenceArtifactRole, relativePath: String, sha256: String, byteLength: UInt64, runID: String? = nil) {
        self.role = role
        self.relativePath = relativePath
        self.sha256 = sha256.lowercased()
        self.byteLength = byteLength
        self.runID = runID
    }
}

public struct AnalysisPhysicalEvidenceArchiveBinding: Codable, Equatable, Sendable {
    public let manifestID: String
    public let manifestSHA256: String
    public let coveragePolicyID: String
    public let selectionPolicyID: String
    public let performanceProfileID: String
    public let batchID: String
    public let workloadApprovalReference: String
    public let buildIdentity: String
    public let deviceModel: String
    public let osVersion: String

    public init(
        manifestID: String, manifestSHA256: String, coveragePolicyID: String, selectionPolicyID: String,
        performanceProfileID: String, batchID: String, workloadApprovalReference: String,
        buildIdentity: String, deviceModel: String, osVersion: String
    ) {
        self.manifestID = manifestID
        self.manifestSHA256 = manifestSHA256.lowercased()
        self.coveragePolicyID = coveragePolicyID
        self.selectionPolicyID = selectionPolicyID
        self.performanceProfileID = performanceProfileID
        self.batchID = batchID
        self.workloadApprovalReference = workloadApprovalReference
        self.buildIdentity = buildIdentity
        self.deviceModel = deviceModel
        self.osVersion = osVersion
    }
}

public struct AnalysisPhysicalEvidenceArchivePolicy: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let policyID: String
    public let authority: String
    public let approvalReference: String
    public let expectedArchiveID: String
    public let binding: AnalysisPhysicalEvidenceArchiveBinding
    public let requiredRunIDs: [String]

    public init(
        schemaVersion: Int = 1, policyID: String, authority: String, approvalReference: String,
        expectedArchiveID: String, binding: AnalysisPhysicalEvidenceArchiveBinding, requiredRunIDs: [String]
    ) {
        self.schemaVersion = schemaVersion
        self.policyID = policyID
        self.authority = authority
        self.approvalReference = approvalReference
        self.expectedArchiveID = expectedArchiveID
        self.binding = binding
        self.requiredRunIDs = requiredRunIDs
    }
}

public struct AnalysisPhysicalEvidenceArchiveManifest: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let archiveID: String
    public let policyID: String
    public let binding: AnalysisPhysicalEvidenceArchiveBinding
    public let entries: [AnalysisPhysicalEvidenceArchiveEntry]
    public let declaredRootSHA256: String

    public init(
        schemaVersion: Int = 1, archiveID: String, policyID: String,
        binding: AnalysisPhysicalEvidenceArchiveBinding, entries: [AnalysisPhysicalEvidenceArchiveEntry],
        declaredRootSHA256: String
    ) {
        self.schemaVersion = schemaVersion
        self.archiveID = archiveID
        self.policyID = policyID
        self.binding = binding
        self.entries = entries
        self.declaredRootSHA256 = declaredRootSHA256.lowercased()
    }
}

public struct AnalysisPhysicalEvidenceBuildCorroboration: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let buildIdentity: String
    public let appBundleIdentifier: String
    public let appVersion: String
    public let buildVersion: String
    public let sourceRevision: String
    public let buildArtifactSHA256: String?

    public init(
        schemaVersion: Int = 1, buildIdentity: String, appBundleIdentifier: String, appVersion: String,
        buildVersion: String, sourceRevision: String, buildArtifactSHA256: String? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.buildIdentity = buildIdentity
        self.appBundleIdentifier = appBundleIdentifier
        self.appVersion = appVersion
        self.buildVersion = buildVersion
        self.sourceRevision = sourceRevision
        self.buildArtifactSHA256 = buildArtifactSHA256?.lowercased()
    }
}

public struct AnalysisPhysicalEvidenceDeviceCorroboration: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let captureSessionID: String
    public let runtimeClass: AnalysisDeviceRuntimeClass
    public let deviceModel: String
    public let osVersion: String
    public let evidenceMethod: String
    public let limitations: [String]

    public init(
        schemaVersion: Int = 1, captureSessionID: String, runtimeClass: AnalysisDeviceRuntimeClass,
        deviceModel: String, osVersion: String, evidenceMethod: String, limitations: [String] = []
    ) {
        self.schemaVersion = schemaVersion
        self.captureSessionID = captureSessionID
        self.runtimeClass = runtimeClass
        self.deviceModel = deviceModel
        self.osVersion = osVersion
        self.evidenceMethod = evidenceMethod
        self.limitations = limitations
    }
}

public enum AnalysisPhysicalEvidenceArchiveIssueCode: String, Codable, Hashable, Sendable {
    case invalidPolicy = "INVALID_ARCHIVE_POLICY"
    case invalidManifest = "INVALID_ARCHIVE_MANIFEST"
    case bindingMismatch = "ARCHIVE_BINDING_MISMATCH"
    case unsafePath = "UNSAFE_ARCHIVE_PATH"
    case invalidEntry = "INVALID_ARCHIVE_ENTRY"
    case duplicatePath = "DUPLICATE_ARCHIVE_PATH"
    case duplicateSingletonRole = "DUPLICATE_SINGLETON_ROLE"
    case missingSingletonRole = "MISSING_SINGLETON_ROLE"
    case invalidRunInventory = "INVALID_RUN_INVENTORY"
    case missingRunArtifact = "MISSING_RUN_ARTIFACT"
    case unexpectedRunArtifact = "UNEXPECTED_RUN_ARTIFACT"
    case duplicateRunArtifact = "DUPLICATE_RUN_ARTIFACT"
    case missingArtifactBytes = "MISSING_ARTIFACT_BYTES"
    case unexpectedArtifactBytes = "UNEXPECTED_ARTIFACT_BYTES"
    case artifactLengthMismatch = "ARTIFACT_LENGTH_MISMATCH"
    case artifactHashMismatch = "ARTIFACT_HASH_MISMATCH"
    case artifactContentMismatch = "ARTIFACT_CONTENT_MISMATCH"
    case archiveRootMismatch = "ARCHIVE_ROOT_MISMATCH"
}

public struct AnalysisPhysicalEvidenceArchiveIssue: Codable, Equatable, Sendable {
    public let code: AnalysisPhysicalEvidenceArchiveIssueCode
    public let role: AnalysisPhysicalEvidenceArtifactRole?
    public let relativePath: String?
    public let runID: String?
    public let detail: String

    public init(
        code: AnalysisPhysicalEvidenceArchiveIssueCode, role: AnalysisPhysicalEvidenceArtifactRole? = nil,
        relativePath: String? = nil, runID: String? = nil, detail: String
    ) {
        self.code = code
        self.role = role
        self.relativePath = relativePath
        self.runID = runID
        self.detail = detail
    }
}

public enum AnalysisPhysicalEvidenceArchiveStatus: String, Codable, Sendable {
    case invalidPolicy = "INVALID_ARCHIVE_POLICY"
    case incompleteOrTampered = "ARCHIVE_INCOMPLETE_OR_TAMPERED"
    case rootConsistentPendingHQ = "TAMPER_EVIDENT_ARCHIVE_ROOT_CONSISTENT_PENDING_HQ"
}

public struct AnalysisPhysicalEvidenceArchiveReport: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let archiveID: String
    public let status: AnalysisPhysicalEvidenceArchiveStatus
    public let computedRootSHA256: String?
    public let entryCount: Int
    public let runCount: Int
    public let issues: [AnalysisPhysicalEvidenceArchiveIssue]
    public let limitations: [String]

    public init(
        schemaVersion: Int = 1, archiveID: String, status: AnalysisPhysicalEvidenceArchiveStatus,
        computedRootSHA256: String?, entryCount: Int, runCount: Int,
        issues: [AnalysisPhysicalEvidenceArchiveIssue], limitations: [String]
    ) {
        self.schemaVersion = schemaVersion
        self.archiveID = archiveID
        self.status = status
        self.computedRootSHA256 = computedRootSHA256
        self.entryCount = entryCount
        self.runCount = runCount
        self.issues = issues
        self.limitations = limitations
    }
}

public enum AnalysisPhysicalEvidenceArchiveBuilder {
    public static func entry(
        role: AnalysisPhysicalEvidenceArtifactRole,
        relativePath: String,
        runID: String? = nil,
        bytes: Data
    ) -> AnalysisPhysicalEvidenceArchiveEntry {
        .init(
            role: role,
            relativePath: relativePath,
            sha256: AnalysisDeviceWorkloadSHA256.hexDigest(bytes),
            byteLength: UInt64(bytes.count),
            runID: runID
        )
    }

    public static func manifest(
        archiveID: String,
        policyID: String,
        binding: AnalysisPhysicalEvidenceArchiveBinding,
        entries: [AnalysisPhysicalEvidenceArchiveEntry]
    ) throws -> AnalysisPhysicalEvidenceArchiveManifest {
        let provisional = AnalysisPhysicalEvidenceArchiveManifest(
            archiveID: archiveID, policyID: policyID, binding: binding,
            entries: entries, declaredRootSHA256: String(repeating: "0", count: 64)
        )
        let root = try AnalysisPhysicalEvidenceArchiveRoot.compute(provisional)
        return .init(
            archiveID: archiveID, policyID: policyID, binding: binding,
            entries: entries, declaredRootSHA256: root
        )
    }
}

public enum AnalysisPhysicalEvidenceArchiveRoot {
    private struct RootPayload: Codable {
        let schemaVersion: Int
        let archiveID: String
        let policyID: String
        let binding: AnalysisPhysicalEvidenceArchiveBinding
        let entries: [AnalysisPhysicalEvidenceArchiveEntry]
    }

    public static func compute(_ manifest: AnalysisPhysicalEvidenceArchiveManifest) throws -> String {
        let entries = manifest.entries.sorted(by: entryOrder)
        let payload = RootPayload(
            schemaVersion: manifest.schemaVersion,
            archiveID: manifest.archiveID,
            policyID: manifest.policyID,
            binding: manifest.binding,
            entries: entries
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(payload)
        return AnalysisDeviceWorkloadSHA256.hexDigest(data)
    }

    private static func entryOrder(_ lhs: AnalysisPhysicalEvidenceArchiveEntry, _ rhs: AnalysisPhysicalEvidenceArchiveEntry) -> Bool {
        let l = "\(lhs.role.rawValue)|\(lhs.runID ?? "")|\(lhs.relativePath)|\(lhs.sha256)|\(lhs.byteLength)"
        let r = "\(rhs.role.rawValue)|\(rhs.runID ?? "")|\(rhs.relativePath)|\(rhs.sha256)|\(rhs.byteLength)"
        return l < r
    }
}

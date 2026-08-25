import Foundation

public struct AnalysisPhysicalEvidenceBatchSingletonArtifact: Equatable, Sendable {
    public let role: AnalysisPhysicalEvidenceArtifactRole
    public let bytes: Data

    public init(role: AnalysisPhysicalEvidenceArtifactRole, bytes: Data) {
        self.role = role
        self.bytes = bytes
    }
}

public struct AnalysisPhysicalEvidenceBatchStoredSingleton: Equatable, Sendable {
    public let role: AnalysisPhysicalEvidenceArtifactRole
    public let relativePath: String
    public let bytes: Data
    public let sha256: String
    public let byteLength: UInt64

    public init(role: AnalysisPhysicalEvidenceArtifactRole, relativePath: String, bytes: Data) {
        self.role = role
        self.relativePath = relativePath
        self.bytes = bytes
        self.sha256 = AnalysisDeviceWorkloadSHA256.hexDigest(bytes)
        self.byteLength = UInt64(bytes.count)
    }
}

public struct AnalysisPhysicalEvidenceBatchChainPolicyTemplate: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let policyID: String
    public let authority: String
    public let approvalReference: String
    public let expectedArchiveID: String
    public let legacyW27PolicyID: String
    public let legacyW27ArchiveID: String
    public let binding: AnalysisPhysicalEvidenceArchiveBinding
    public let requiredRunIDs: [String]

    public init(
        schemaVersion: Int = 1,
        policyID: String,
        authority: String,
        approvalReference: String,
        expectedArchiveID: String,
        legacyW27PolicyID: String,
        legacyW27ArchiveID: String,
        binding: AnalysisPhysicalEvidenceArchiveBinding,
        requiredRunIDs: [String]
    ) {
        self.schemaVersion = schemaVersion
        self.policyID = policyID
        self.authority = authority
        self.approvalReference = approvalReference
        self.expectedArchiveID = expectedArchiveID
        self.legacyW27PolicyID = legacyW27PolicyID
        self.legacyW27ArchiveID = legacyW27ArchiveID
        self.binding = binding
        self.requiredRunIDs = requiredRunIDs
    }
}

public struct AnalysisPhysicalEvidenceBatchRunSummary: Codable, Equatable, Sendable {
    public let runID: String
    public let workloadExecutionID: String
    public let w39BundleRootSHA256: String

    public init(runID: String, workloadExecutionID: String, w39BundleRootSHA256: String) {
        self.runID = runID
        self.workloadExecutionID = workloadExecutionID
        self.w39BundleRootSHA256 = w39BundleRootSHA256.lowercased()
    }
}

public struct AnalysisPhysicalEvidenceBatchAssembly: Sendable {
    public let schemaVersion: Int
    public let publicationID: String
    public let batchRootSHA256: String
    public let runSummaries: [AnalysisPhysicalEvidenceBatchRunSummary]
    public let singletons: [AnalysisPhysicalEvidenceBatchStoredSingleton]
    public let w27Policy: AnalysisPhysicalEvidenceArchivePolicy
    public let w27Manifest: AnalysisPhysicalEvidenceArchiveManifest
    public let w27Report: AnalysisPhysicalEvidenceArchiveReport
    public let w38Policy: AnalysisPhysicalEvidenceArchiveChainPolicy
    public let w38Manifest: AnalysisPhysicalEvidenceArchiveChainManifest
    public let w38Report: AnalysisPhysicalEvidenceArchiveChainReport

    public init(
        schemaVersion: Int = 1,
        publicationID: String,
        batchRootSHA256: String,
        runSummaries: [AnalysisPhysicalEvidenceBatchRunSummary],
        singletons: [AnalysisPhysicalEvidenceBatchStoredSingleton],
        w27Policy: AnalysisPhysicalEvidenceArchivePolicy,
        w27Manifest: AnalysisPhysicalEvidenceArchiveManifest,
        w27Report: AnalysisPhysicalEvidenceArchiveReport,
        w38Policy: AnalysisPhysicalEvidenceArchiveChainPolicy,
        w38Manifest: AnalysisPhysicalEvidenceArchiveChainManifest,
        w38Report: AnalysisPhysicalEvidenceArchiveChainReport
    ) {
        self.schemaVersion = schemaVersion
        self.publicationID = publicationID
        self.batchRootSHA256 = batchRootSHA256.lowercased()
        self.runSummaries = runSummaries
        self.singletons = singletons
        self.w27Policy = w27Policy
        self.w27Manifest = w27Manifest
        self.w27Report = w27Report
        self.w38Policy = w38Policy
        self.w38Manifest = w38Manifest
        self.w38Report = w38Report
    }
}

public enum AnalysisPhysicalEvidenceBatchAssemblyError: Error, Equatable, Sendable {
    case unsafePublicationID
    case invalidRunInventory
    case invalidW27Policy
    case invalidW38Template
    case invalidSingletonInventory
    case invalidSingletonArtifact
    case reusedExecutionID
    case w27ValidationFailed
    case w38ValidationFailed
    case batchRootFailure
}

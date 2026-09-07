import Foundation

public enum AnalysisPhysicalEvidenceTransferItemKind: String, Codable, CaseIterable, Sendable {
    case w40Control = "W40_CONTROL"
    case w27Policy = "W27_POLICY"
    case w27Manifest = "W27_MANIFEST"
    case w27Report = "W27_REPORT"
    case w38Policy = "W38_POLICY"
    case w38Manifest = "W38_MANIFEST"
    case w38Report = "W38_REPORT"
    case singleton = "W27_SINGLETON"
    case w39Control = "W39_CONTROL"
    case w39Artifact = "W39_ARTIFACT"
}

public struct AnalysisPhysicalEvidenceReopenedItem: Equatable, Sendable {
    public let kind: AnalysisPhysicalEvidenceTransferItemKind
    public let sourceRelativePath: String
    public let runID: String?
    public let role: String?
    public let bytes: Data
    public let sha256: String
    public let byteLength: UInt64

    public init(
        kind: AnalysisPhysicalEvidenceTransferItemKind,
        sourceRelativePath: String,
        runID: String? = nil,
        role: String? = nil,
        bytes: Data
    ) {
        self.kind = kind
        self.sourceRelativePath = sourceRelativePath
        self.runID = runID
        self.role = role
        self.bytes = bytes
        self.sha256 = AnalysisDeviceWorkloadSHA256.hexDigest(bytes)
        self.byteLength = UInt64(bytes.count)
    }
}

public struct AnalysisPhysicalEvidenceReopenedBatch: Sendable {
    public let publicationID: String
    public let w40RootSHA256: String
    public let w27RootSHA256: String
    public let w38RootSHA256: String
    public let runSummaries: [AnalysisPhysicalEvidenceBatchRunSummary]
    public let items: [AnalysisPhysicalEvidenceReopenedItem]

    public init(
        publicationID: String,
        w40RootSHA256: String,
        w27RootSHA256: String,
        w38RootSHA256: String,
        runSummaries: [AnalysisPhysicalEvidenceBatchRunSummary],
        items: [AnalysisPhysicalEvidenceReopenedItem]
    ) {
        self.publicationID = publicationID
        self.w40RootSHA256 = w40RootSHA256.lowercased()
        self.w27RootSHA256 = w27RootSHA256.lowercased()
        self.w38RootSHA256 = w38RootSHA256.lowercased()
        self.runSummaries = runSummaries.sorted { $0.runID < $1.runID }
        self.items = items.sorted { $0.sourceRelativePath < $1.sourceRelativePath }
    }
}

public struct AnalysisPhysicalEvidenceTransferItem: Codable, Equatable, Sendable {
    public let kind: AnalysisPhysicalEvidenceTransferItemKind
    public let sourceRelativePath: String
    public let payloadRelativePath: String
    public let runID: String?
    public let role: String?
    public let sha256: String
    public let byteLength: UInt64

    public init(
        kind: AnalysisPhysicalEvidenceTransferItemKind,
        sourceRelativePath: String,
        payloadRelativePath: String,
        runID: String? = nil,
        role: String? = nil,
        sha256: String,
        byteLength: UInt64
    ) {
        self.kind = kind
        self.sourceRelativePath = sourceRelativePath
        self.payloadRelativePath = payloadRelativePath
        self.runID = runID
        self.role = role
        self.sha256 = sha256.lowercased()
        self.byteLength = byteLength
    }
}

public struct AnalysisPhysicalEvidenceTransferManifest: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let transferID: String
    public let publicationID: String
    public let w40RootSHA256: String
    public let w27RootSHA256: String
    public let w38RootSHA256: String
    public let runs: [AnalysisPhysicalEvidenceBatchRunSummary]
    public let items: [AnalysisPhysicalEvidenceTransferItem]
    public let declaredTransferRootSHA256: String

    public init(
        schemaVersion: Int = 1,
        transferID: String,
        publicationID: String,
        w40RootSHA256: String,
        w27RootSHA256: String,
        w38RootSHA256: String,
        runs: [AnalysisPhysicalEvidenceBatchRunSummary],
        items: [AnalysisPhysicalEvidenceTransferItem],
        declaredTransferRootSHA256: String
    ) {
        self.schemaVersion = schemaVersion
        self.transferID = transferID
        self.publicationID = publicationID
        self.w40RootSHA256 = w40RootSHA256.lowercased()
        self.w27RootSHA256 = w27RootSHA256.lowercased()
        self.w38RootSHA256 = w38RootSHA256.lowercased()
        self.runs = runs.sorted { $0.runID < $1.runID }
        self.items = items.sorted { $0.payloadRelativePath < $1.payloadRelativePath }
        self.declaredTransferRootSHA256 = declaredTransferRootSHA256.lowercased()
    }
}

public struct AnalysisPhysicalEvidenceTransferSnapshot: Sendable {
    public let manifest: AnalysisPhysicalEvidenceTransferManifest
    public let payloadBytesByPath: [String: Data]

    public init(manifest: AnalysisPhysicalEvidenceTransferManifest, payloadBytesByPath: [String: Data]) {
        self.manifest = manifest
        self.payloadBytesByPath = payloadBytesByPath
    }
}

public enum AnalysisPhysicalEvidencePublishedBatchReopenError: Error, Equatable, Sendable {
    case unsafePublicationID
    case missingBatchDirectory
    case unsafeOrMissingFile(String)
    case invalidW40Control
    case invalidArchiveDocuments
    case invalidSingletonInventory
    case singletonMismatch(String)
    case invalidRunInventory
    case invalidW39Run(String)
    case staleW27Report
    case staleW38Report
    case w27RootDrift
    case w38RootDrift
    case w40RootDrift
    case reopenedAssemblyInvalid
    case duplicateTransferSourcePath
}

public enum AnalysisPhysicalEvidenceTransferError: Error, Equatable, Sendable {
    case unsafeTransferID
    case invalidReopenedBatch
    case invalidTransferManifest
    case transferRootMismatch
    case missingOrInvalidPayload(String)
    case unexpectedPayload(String)
    case payloadInventoryMismatch
    case destinationReopenFailed
    case destinationRootDrift
    case existingTargetCollision
    case stagingPathCollision
    case ambiguousRecoveryState
    case stagingWriteFailed
    case stagedVerificationFailed
    case sourceChangedDuringPublication
    case publicationFailed
    case publishedVerificationFailed
}

public enum AnalysisPhysicalEvidenceTransferPublicationStatus: String, Codable, Sendable {
    case published = "PUBLISHED"
    case recoveredInterruptedStageAndPublished = "RECOVERED_INTERRUPTED_STAGE_AND_PUBLISHED"
}

public struct AnalysisPhysicalEvidenceTransferPublicationReceipt: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let status: AnalysisPhysicalEvidenceTransferPublicationStatus
    public let transferID: String
    public let publicationID: String
    public let transferRootSHA256: String
    public let finalRelativeDirectory: String
    public let itemCount: Int
    public let runCount: Int

    public init(
        schemaVersion: Int = 1,
        status: AnalysisPhysicalEvidenceTransferPublicationStatus,
        transferID: String,
        publicationID: String,
        transferRootSHA256: String,
        finalRelativeDirectory: String,
        itemCount: Int,
        runCount: Int
    ) {
        self.schemaVersion = schemaVersion
        self.status = status
        self.transferID = transferID
        self.publicationID = publicationID
        self.transferRootSHA256 = transferRootSHA256.lowercased()
        self.finalRelativeDirectory = finalRelativeDirectory
        self.itemCount = itemCount
        self.runCount = runCount
    }
}

import Foundation

public struct AnalysisPhysicalEvidenceExternalRootAnchor: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let anchorID: String
    public let anchorSequence: UInt64
    public let authority: String
    public let approvalReference: String
    public let publicationID: String
    public let transferID: String
    public let w27RootSHA256: String
    public let w38RootSHA256: String
    public let w40RootSHA256: String
    public let w41RootSHA256: String
    public let runs: [AnalysisPhysicalEvidenceBatchRunSummary]
    public let predecessorAnchorReceiptRootSHA256: String?

    public init(
        schemaVersion: Int = 1,
        anchorID: String,
        anchorSequence: UInt64,
        authority: String,
        approvalReference: String,
        publicationID: String,
        transferID: String,
        w27RootSHA256: String,
        w38RootSHA256: String,
        w40RootSHA256: String,
        w41RootSHA256: String,
        runs: [AnalysisPhysicalEvidenceBatchRunSummary],
        predecessorAnchorReceiptRootSHA256: String? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.anchorID = anchorID
        self.anchorSequence = anchorSequence
        self.authority = authority
        self.approvalReference = approvalReference
        self.publicationID = publicationID
        self.transferID = transferID
        self.w27RootSHA256 = w27RootSHA256.lowercased()
        self.w38RootSHA256 = w38RootSHA256.lowercased()
        self.w40RootSHA256 = w40RootSHA256.lowercased()
        self.w41RootSHA256 = w41RootSHA256.lowercased()
        self.runs = runs.sorted { $0.runID < $1.runID }
        self.predecessorAnchorReceiptRootSHA256 = predecessorAnchorReceiptRootSHA256?.lowercased()
    }
}

public struct AnalysisPhysicalEvidenceAnchorReceipt: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let anchor: AnalysisPhysicalEvidenceExternalRootAnchor
    public let declaredAnchorReceiptRootSHA256: String

    public init(
        schemaVersion: Int = 1,
        anchor: AnalysisPhysicalEvidenceExternalRootAnchor,
        declaredAnchorReceiptRootSHA256: String
    ) {
        self.schemaVersion = schemaVersion
        self.anchor = anchor
        self.declaredAnchorReceiptRootSHA256 = declaredAnchorReceiptRootSHA256.lowercased()
    }
}

/// This expectation is intentionally supplied separately from the W41 package.
/// Its exact receipt root and minimum sequence are the rollback/replay guard.
public struct AnalysisPhysicalEvidenceAnchorExpectation: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let expectedAnchorID: String
    public let minimumAnchorSequence: UInt64
    public let expectedAnchorReceiptRootSHA256: String
    public let expectedPublicationID: String
    public let expectedTransferID: String
    public let expectedPredecessorAnchorReceiptRootSHA256: String?

    public init(
        schemaVersion: Int = 1,
        expectedAnchorID: String,
        minimumAnchorSequence: UInt64,
        expectedAnchorReceiptRootSHA256: String,
        expectedPublicationID: String,
        expectedTransferID: String,
        expectedPredecessorAnchorReceiptRootSHA256: String? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.expectedAnchorID = expectedAnchorID
        self.minimumAnchorSequence = minimumAnchorSequence
        self.expectedAnchorReceiptRootSHA256 = expectedAnchorReceiptRootSHA256.lowercased()
        self.expectedPublicationID = expectedPublicationID
        self.expectedTransferID = expectedTransferID
        self.expectedPredecessorAnchorReceiptRootSHA256 = expectedPredecessorAnchorReceiptRootSHA256?.lowercased()
    }
}

public enum AnalysisPhysicalEvidenceExternalAnchorError: Error, Equatable, Sendable {
    case invalidAnchor
    case invalidAnchorReceipt
    case anchorReceiptRootMismatch
    case invalidExpectation
    case anchorIdentityMismatch
    case staleAnchorSequence
    case staleAnchorReceipt
    case predecessorAnchorMismatch
    case destinationTransferVerificationFailed
    case publicationIdentityMismatch
    case transferIdentityMismatch
    case runInventoryMismatch
    case rootSetMismatch
    case certificateRootFailure
}

public enum AnalysisPhysicalEvidenceAnchorReceiptRoot {
    private struct Payload: Codable {
        let schemaVersion: Int
        let anchorID: String
        let anchorSequence: UInt64
        let authority: String
        let approvalReference: String
        let publicationID: String
        let transferID: String
        let w27RootSHA256: String
        let w38RootSHA256: String
        let w40RootSHA256: String
        let w41RootSHA256: String
        let runs: [AnalysisPhysicalEvidenceBatchRunSummary]
        let predecessorAnchorReceiptRootSHA256: String?
    }

    public static func compute(_ anchor: AnalysisPhysicalEvidenceExternalRootAnchor) throws -> String {
        let payload = Payload(
            schemaVersion: anchor.schemaVersion,
            anchorID: anchor.anchorID,
            anchorSequence: anchor.anchorSequence,
            authority: anchor.authority,
            approvalReference: anchor.approvalReference,
            publicationID: anchor.publicationID,
            transferID: anchor.transferID,
            w27RootSHA256: anchor.w27RootSHA256.lowercased(),
            w38RootSHA256: anchor.w38RootSHA256.lowercased(),
            w40RootSHA256: anchor.w40RootSHA256.lowercased(),
            w41RootSHA256: anchor.w41RootSHA256.lowercased(),
            runs: anchor.runs.sorted { $0.runID < $1.runID },
            predecessorAnchorReceiptRootSHA256: anchor.predecessorAnchorReceiptRootSHA256?.lowercased()
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return AnalysisDeviceWorkloadSHA256.hexDigest(try encoder.encode(payload))
    }
}

public enum AnalysisPhysicalEvidenceAnchorReceiptIssuer {
    public static let requiredAuthority = "HQ_LATE_INTEGRATION"

    public static func issue(
        anchor: AnalysisPhysicalEvidenceExternalRootAnchor
    ) throws -> AnalysisPhysicalEvidenceAnchorReceipt {
        guard validateAnchor(anchor) else {
            throw AnalysisPhysicalEvidenceExternalAnchorError.invalidAnchor
        }
        return .init(
            anchor: anchor,
            declaredAnchorReceiptRootSHA256: try AnalysisPhysicalEvidenceAnchorReceiptRoot.compute(anchor)
        )
    }

    public static func validateAnchor(_ anchor: AnalysisPhysicalEvidenceExternalRootAnchor) -> Bool {
        let runIDs = anchor.runs.map(\.runID)
        let executionIDs = anchor.runs.map(\.workloadExecutionID)
        let runsAreValid = anchor.runs.allSatisfy { run in
            AnalysisPhysicalEvidenceW39BatchLoader.safeComponent(run.runID)
                && AnalysisPhysicalEvidenceW39BatchLoader.safeComponent(run.workloadExecutionID)
                && AnalysisPhysicalEvidenceW39BatchLoader.isSHA256(run.w39BundleRootSHA256)
        }
        let predecessorIsValid = anchor.predecessorAnchorReceiptRootSHA256.map {
            AnalysisPhysicalEvidenceW39BatchLoader.isSHA256($0)
        } ?? true
        return anchor.schemaVersion == 1
            && AnalysisPhysicalEvidenceW39BatchLoader.safeComponent(anchor.anchorID)
            && anchor.anchorSequence > 0
            && anchor.authority == requiredAuthority
            && !anchor.approvalReference.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && AnalysisPhysicalEvidenceW39BatchLoader.safeComponent(anchor.publicationID)
            && AnalysisPhysicalEvidenceW39BatchLoader.safeComponent(anchor.transferID)
            && AnalysisPhysicalEvidenceW39BatchLoader.isSHA256(anchor.w27RootSHA256)
            && AnalysisPhysicalEvidenceW39BatchLoader.isSHA256(anchor.w38RootSHA256)
            && AnalysisPhysicalEvidenceW39BatchLoader.isSHA256(anchor.w40RootSHA256)
            && AnalysisPhysicalEvidenceW39BatchLoader.isSHA256(anchor.w41RootSHA256)
            && !runIDs.isEmpty
            && Set(runIDs).count == runIDs.count
            && Set(executionIDs).count == executionIDs.count
            && runsAreValid
            && predecessorIsValid
    }
}

public enum AnalysisPhysicalEvidenceAnchorCodec {
    public static func encodeReceipt(_ value: AnalysisPhysicalEvidenceAnchorReceipt) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(value)
    }

    public static func decodeReceipt(_ data: Data) throws -> AnalysisPhysicalEvidenceAnchorReceipt {
        try JSONDecoder().decode(AnalysisPhysicalEvidenceAnchorReceipt.self, from: data)
    }

    public static func encodeExpectation(_ value: AnalysisPhysicalEvidenceAnchorExpectation) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(value)
    }

    public static func decodeExpectation(_ data: Data) throws -> AnalysisPhysicalEvidenceAnchorExpectation {
        try JSONDecoder().decode(AnalysisPhysicalEvidenceAnchorExpectation.self, from: data)
    }
}

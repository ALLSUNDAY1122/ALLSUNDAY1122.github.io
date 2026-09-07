import Foundation

public struct AnalysisPhysicalRealAudioBridgeConsumptionCheckpoint: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let checkpointID: String
    public let checkpointSequence: UInt64
    public let authority: String
    public let approvalReference: String
    public let ledgerID: String
    public let latestLedgerSequence: UInt64
    public let latestRecordRootSHA256: String
    public let ledgerRootSHA256: String
    public let consumedW47PackageRootSHA256s: [String]
    public let predecessorCheckpointRootSHA256: String?
    public let limitations: [String]
    public let declaredCheckpointRootSHA256: String

    public init(
        schemaVersion: Int = 1,
        checkpointID: String,
        checkpointSequence: UInt64,
        authority: String,
        approvalReference: String,
        ledgerID: String,
        latestLedgerSequence: UInt64,
        latestRecordRootSHA256: String,
        ledgerRootSHA256: String,
        consumedW47PackageRootSHA256s: [String],
        predecessorCheckpointRootSHA256: String?,
        limitations: [String],
        declaredCheckpointRootSHA256: String
    ) {
        self.schemaVersion = schemaVersion
        self.checkpointID = checkpointID
        self.checkpointSequence = checkpointSequence
        self.authority = authority
        self.approvalReference = approvalReference
        self.ledgerID = ledgerID
        self.latestLedgerSequence = latestLedgerSequence
        self.latestRecordRootSHA256 = latestRecordRootSHA256.lowercased()
        self.ledgerRootSHA256 = ledgerRootSHA256.lowercased()
        self.consumedW47PackageRootSHA256s = consumedW47PackageRootSHA256s.map { $0.lowercased() }.sorted()
        self.predecessorCheckpointRootSHA256 = predecessorCheckpointRootSHA256?.lowercased()
        self.limitations = limitations
        self.declaredCheckpointRootSHA256 = declaredCheckpointRootSHA256.lowercased()
    }
}

public struct AnalysisPhysicalRealAudioBridgeExternalAnchorHandoff: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let handoffID: String
    public let authority: String
    public let approvalReference: String
    public let ledgerID: String
    public let checkpointID: String
    public let checkpointSequence: UInt64
    public let checkpointRootSHA256: String
    public let ledgerSequence: UInt64
    public let ledgerRootSHA256: String
    public let latestRecordRootSHA256: String
    public let consumedW47InventoryRootSHA256: String
    public let predecessorHandoffRootSHA256: String?
    public let limitations: [String]
    public let declaredHandoffRootSHA256: String

    public init(
        schemaVersion: Int = 1,
        handoffID: String,
        authority: String,
        approvalReference: String,
        ledgerID: String,
        checkpointID: String,
        checkpointSequence: UInt64,
        checkpointRootSHA256: String,
        ledgerSequence: UInt64,
        ledgerRootSHA256: String,
        latestRecordRootSHA256: String,
        consumedW47InventoryRootSHA256: String,
        predecessorHandoffRootSHA256: String?,
        limitations: [String],
        declaredHandoffRootSHA256: String
    ) {
        self.schemaVersion = schemaVersion
        self.handoffID = handoffID
        self.authority = authority
        self.approvalReference = approvalReference
        self.ledgerID = ledgerID
        self.checkpointID = checkpointID
        self.checkpointSequence = checkpointSequence
        self.checkpointRootSHA256 = checkpointRootSHA256.lowercased()
        self.ledgerSequence = ledgerSequence
        self.ledgerRootSHA256 = ledgerRootSHA256.lowercased()
        self.latestRecordRootSHA256 = latestRecordRootSHA256.lowercased()
        self.consumedW47InventoryRootSHA256 = consumedW47InventoryRootSHA256.lowercased()
        self.predecessorHandoffRootSHA256 = predecessorHandoffRootSHA256?.lowercased()
        self.limitations = limitations
        self.declaredHandoffRootSHA256 = declaredHandoffRootSHA256.lowercased()
    }
}

public enum AnalysisPhysicalRealAudioBridgeConsumptionCheckpointError: Error, Equatable, Sendable {
    case invalidCheckpointRequest
    case ledgerMissing
    case invalidCheckpoint
    case staleCheckpointReplay
    case predecessorCheckpointMismatch
    case invalidHandoff
    case predecessorHandoffMismatch
}

public enum AnalysisPhysicalRealAudioBridgeConsumptionCheckpointRoot {
    private struct Payload: Codable {
        let schemaVersion: Int
        let checkpointID: String
        let checkpointSequence: UInt64
        let authority: String
        let approvalReference: String
        let ledgerID: String
        let latestLedgerSequence: UInt64
        let latestRecordRootSHA256: String
        let ledgerRootSHA256: String
        let consumedW47PackageRootSHA256s: [String]
        let predecessorCheckpointRootSHA256: String?
        let limitations: [String]
    }

    public static func compute(_ value: AnalysisPhysicalRealAudioBridgeConsumptionCheckpoint) throws -> String {
        try AnalysisAnalysisParityAdjudicationRoot.stableSHA256(Payload(
            schemaVersion: value.schemaVersion,
            checkpointID: value.checkpointID,
            checkpointSequence: value.checkpointSequence,
            authority: value.authority,
            approvalReference: value.approvalReference,
            ledgerID: value.ledgerID,
            latestLedgerSequence: value.latestLedgerSequence,
            latestRecordRootSHA256: value.latestRecordRootSHA256,
            ledgerRootSHA256: value.ledgerRootSHA256,
            consumedW47PackageRootSHA256s: value.consumedW47PackageRootSHA256s.sorted(),
            predecessorCheckpointRootSHA256: value.predecessorCheckpointRootSHA256,
            limitations: value.limitations
        ))
    }
}

public enum AnalysisPhysicalRealAudioBridgeExternalAnchorHandoffRoot {
    private struct Payload: Codable {
        let schemaVersion: Int
        let handoffID: String
        let authority: String
        let approvalReference: String
        let ledgerID: String
        let checkpointID: String
        let checkpointSequence: UInt64
        let checkpointRootSHA256: String
        let ledgerSequence: UInt64
        let ledgerRootSHA256: String
        let latestRecordRootSHA256: String
        let consumedW47InventoryRootSHA256: String
        let predecessorHandoffRootSHA256: String?
        let limitations: [String]
    }

    public static func compute(_ value: AnalysisPhysicalRealAudioBridgeExternalAnchorHandoff) throws -> String {
        try AnalysisAnalysisParityAdjudicationRoot.stableSHA256(Payload(
            schemaVersion: value.schemaVersion,
            handoffID: value.handoffID,
            authority: value.authority,
            approvalReference: value.approvalReference,
            ledgerID: value.ledgerID,
            checkpointID: value.checkpointID,
            checkpointSequence: value.checkpointSequence,
            checkpointRootSHA256: value.checkpointRootSHA256,
            ledgerSequence: value.ledgerSequence,
            ledgerRootSHA256: value.ledgerRootSHA256,
            latestRecordRootSHA256: value.latestRecordRootSHA256,
            consumedW47InventoryRootSHA256: value.consumedW47InventoryRootSHA256,
            predecessorHandoffRootSHA256: value.predecessorHandoffRootSHA256,
            limitations: value.limitations
        ))
    }
}

public enum AnalysisPhysicalRealAudioBridgeConsumptionCheckpointManager {
    public static let requiredAuthority = "HQ_LATE_INTEGRATION"
    public static let limitations = [
        "NON_PARITY: W49 checkpoints and external-anchor handoffs prove ledger continuity only; they do not establish Moises feature parity.",
        "A checkpoint detects local rollback only when its root or handoff is retained independently outside the mutable ledger directory.",
        "Checkpoint and handoff roots are SHA-256 commitments, not signatures, trusted timestamps, Secure Enclave proofs or Apple attestation.",
        "HQ must preserve predecessor checkpoint/handoff roots and reject chain replacement rather than accepting a newly reset sequence as authoritative."
    ]

    public static func makeCheckpoint(
        ledgerID: String,
        checkpointID: String,
        checkpointSequence: UInt64,
        approvalReference: String,
        previousCheckpoint: AnalysisPhysicalRealAudioBridgeConsumptionCheckpoint? = nil,
        rootURL: URL,
        fileManager: FileManager = .default
    ) throws -> AnalysisPhysicalRealAudioBridgeConsumptionCheckpoint {
        guard AnalysisPhysicalEvidenceW39BatchLoader.safeComponent(checkpointID),
              checkpointSequence > 0,
              !approvalReference.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AnalysisPhysicalRealAudioBridgeConsumptionCheckpointError.invalidCheckpointRequest
        }
        let predecessorRoot: String?
        if checkpointSequence == 1 {
            guard previousCheckpoint == nil else {
                throw AnalysisPhysicalRealAudioBridgeConsumptionCheckpointError.predecessorCheckpointMismatch
            }
            predecessorRoot = nil
        } else {
            guard let previousCheckpoint,
                  validateCheckpointEnvelope(previousCheckpoint),
                  previousCheckpoint.checkpointSequence + 1 == checkpointSequence,
                  previousCheckpoint.ledgerID == ledgerID else {
                throw AnalysisPhysicalRealAudioBridgeConsumptionCheckpointError.predecessorCheckpointMismatch
            }
            predecessorRoot = previousCheckpoint.declaredCheckpointRootSHA256
        }

        guard let head = try AnalysisPhysicalRealAudioBridgeConsumptionLedgerStore.loadValidatedHead(
            ledgerID: ledgerID,
            rootURL: rootURL,
            fileManager: fileManager
        ) else {
            throw AnalysisPhysicalRealAudioBridgeConsumptionCheckpointError.ledgerMissing
        }
        let consumed = head.records.map(\.w47PackageRootSHA256).sorted()
        let provisional = AnalysisPhysicalRealAudioBridgeConsumptionCheckpoint(
            checkpointID: checkpointID,
            checkpointSequence: checkpointSequence,
            authority: requiredAuthority,
            approvalReference: approvalReference,
            ledgerID: ledgerID,
            latestLedgerSequence: head.latestSequence,
            latestRecordRootSHA256: head.latestRecordRootSHA256,
            ledgerRootSHA256: head.declaredLedgerRootSHA256,
            consumedW47PackageRootSHA256s: consumed,
            predecessorCheckpointRootSHA256: predecessorRoot,
            limitations: limitations,
            declaredCheckpointRootSHA256: String(repeating: "0", count: 64)
        )
        let root = try AnalysisPhysicalRealAudioBridgeConsumptionCheckpointRoot.compute(provisional)
        return AnalysisPhysicalRealAudioBridgeConsumptionCheckpoint(
            checkpointID: provisional.checkpointID,
            checkpointSequence: provisional.checkpointSequence,
            authority: provisional.authority,
            approvalReference: provisional.approvalReference,
            ledgerID: provisional.ledgerID,
            latestLedgerSequence: provisional.latestLedgerSequence,
            latestRecordRootSHA256: provisional.latestRecordRootSHA256,
            ledgerRootSHA256: provisional.ledgerRootSHA256,
            consumedW47PackageRootSHA256s: provisional.consumedW47PackageRootSHA256s,
            predecessorCheckpointRootSHA256: provisional.predecessorCheckpointRootSHA256,
            limitations: provisional.limitations,
            declaredCheckpointRootSHA256: root
        )
    }

    public static func verifyCurrentLedger(
        checkpoint: AnalysisPhysicalRealAudioBridgeConsumptionCheckpoint,
        previousCheckpoint: AnalysisPhysicalRealAudioBridgeConsumptionCheckpoint? = nil,
        rootURL: URL,
        fileManager: FileManager = .default
    ) throws {
        guard validateCheckpointEnvelope(checkpoint) else {
            throw AnalysisPhysicalRealAudioBridgeConsumptionCheckpointError.invalidCheckpoint
        }
        if checkpoint.checkpointSequence == 1 {
            guard previousCheckpoint == nil, checkpoint.predecessorCheckpointRootSHA256 == nil else {
                throw AnalysisPhysicalRealAudioBridgeConsumptionCheckpointError.predecessorCheckpointMismatch
            }
        } else {
            guard let previousCheckpoint,
                  validateCheckpointEnvelope(previousCheckpoint),
                  previousCheckpoint.checkpointSequence + 1 == checkpoint.checkpointSequence,
                  previousCheckpoint.ledgerID == checkpoint.ledgerID,
                  checkpoint.predecessorCheckpointRootSHA256 == previousCheckpoint.declaredCheckpointRootSHA256 else {
                throw AnalysisPhysicalRealAudioBridgeConsumptionCheckpointError.predecessorCheckpointMismatch
            }
        }
        guard let head = try AnalysisPhysicalRealAudioBridgeConsumptionLedgerStore.loadValidatedHead(
            ledgerID: checkpoint.ledgerID,
            rootURL: rootURL,
            fileManager: fileManager
        ) else {
            throw AnalysisPhysicalRealAudioBridgeConsumptionCheckpointError.ledgerMissing
        }
        let currentConsumed = head.records.map(\.w47PackageRootSHA256).sorted()
        guard checkpoint.latestLedgerSequence == head.latestSequence,
              checkpoint.latestRecordRootSHA256 == head.latestRecordRootSHA256,
              checkpoint.ledgerRootSHA256 == head.declaredLedgerRootSHA256,
              checkpoint.consumedW47PackageRootSHA256s == currentConsumed else {
            throw AnalysisPhysicalRealAudioBridgeConsumptionCheckpointError.staleCheckpointReplay
        }
    }

    public static func makeExternalAnchorHandoff(
        handoffID: String,
        approvalReference: String,
        checkpoint: AnalysisPhysicalRealAudioBridgeConsumptionCheckpoint,
        previousHandoff: AnalysisPhysicalRealAudioBridgeExternalAnchorHandoff? = nil
    ) throws -> AnalysisPhysicalRealAudioBridgeExternalAnchorHandoff {
        guard AnalysisPhysicalEvidenceW39BatchLoader.safeComponent(handoffID),
              !approvalReference.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              validateCheckpointEnvelope(checkpoint) else {
            throw AnalysisPhysicalRealAudioBridgeConsumptionCheckpointError.invalidHandoff
        }
        let predecessor: String?
        if checkpoint.checkpointSequence == 1 {
            guard previousHandoff == nil else {
                throw AnalysisPhysicalRealAudioBridgeConsumptionCheckpointError.predecessorHandoffMismatch
            }
            predecessor = nil
        } else {
            guard let previousHandoff,
                  validateHandoff(previousHandoff),
                  previousHandoff.ledgerID == checkpoint.ledgerID,
                  previousHandoff.checkpointSequence + 1 == checkpoint.checkpointSequence else {
                throw AnalysisPhysicalRealAudioBridgeConsumptionCheckpointError.predecessorHandoffMismatch
            }
            predecessor = previousHandoff.declaredHandoffRootSHA256
        }
        let inventoryRoot = try AnalysisAnalysisParityAdjudicationRoot.stableSHA256(checkpoint.consumedW47PackageRootSHA256s.sorted())
        let provisional = AnalysisPhysicalRealAudioBridgeExternalAnchorHandoff(
            handoffID: handoffID,
            authority: requiredAuthority,
            approvalReference: approvalReference,
            ledgerID: checkpoint.ledgerID,
            checkpointID: checkpoint.checkpointID,
            checkpointSequence: checkpoint.checkpointSequence,
            checkpointRootSHA256: checkpoint.declaredCheckpointRootSHA256,
            ledgerSequence: checkpoint.latestLedgerSequence,
            ledgerRootSHA256: checkpoint.ledgerRootSHA256,
            latestRecordRootSHA256: checkpoint.latestRecordRootSHA256,
            consumedW47InventoryRootSHA256: inventoryRoot,
            predecessorHandoffRootSHA256: predecessor,
            limitations: limitations,
            declaredHandoffRootSHA256: String(repeating: "0", count: 64)
        )
        let root = try AnalysisPhysicalRealAudioBridgeExternalAnchorHandoffRoot.compute(provisional)
        return AnalysisPhysicalRealAudioBridgeExternalAnchorHandoff(
            handoffID: provisional.handoffID,
            authority: provisional.authority,
            approvalReference: provisional.approvalReference,
            ledgerID: provisional.ledgerID,
            checkpointID: provisional.checkpointID,
            checkpointSequence: provisional.checkpointSequence,
            checkpointRootSHA256: provisional.checkpointRootSHA256,
            ledgerSequence: provisional.ledgerSequence,
            ledgerRootSHA256: provisional.ledgerRootSHA256,
            latestRecordRootSHA256: provisional.latestRecordRootSHA256,
            consumedW47InventoryRootSHA256: provisional.consumedW47InventoryRootSHA256,
            predecessorHandoffRootSHA256: provisional.predecessorHandoffRootSHA256,
            limitations: provisional.limitations,
            declaredHandoffRootSHA256: root
        )
    }

    public static func validateCheckpointEnvelope(
        _ value: AnalysisPhysicalRealAudioBridgeConsumptionCheckpoint
    ) -> Bool {
        let chainValid = value.checkpointSequence == 1
            ? value.predecessorCheckpointRootSHA256 == nil
            : value.predecessorCheckpointRootSHA256.map(AnalysisPhysicalEvidenceW39BatchLoader.isSHA256) == true
        return value.schemaVersion == 1
            && AnalysisPhysicalEvidenceW39BatchLoader.safeComponent(value.checkpointID)
            && value.checkpointSequence > 0
            && value.authority == requiredAuthority
            && !value.approvalReference.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && AnalysisPhysicalEvidenceW39BatchLoader.safeComponent(value.ledgerID)
            && value.latestLedgerSequence > 0
            && AnalysisPhysicalEvidenceW39BatchLoader.isSHA256(value.latestRecordRootSHA256)
            && AnalysisPhysicalEvidenceW39BatchLoader.isSHA256(value.ledgerRootSHA256)
            && !value.consumedW47PackageRootSHA256s.isEmpty
            && value.consumedW47PackageRootSHA256s == value.consumedW47PackageRootSHA256s.sorted()
            && Set(value.consumedW47PackageRootSHA256s).count == value.consumedW47PackageRootSHA256s.count
            && value.consumedW47PackageRootSHA256s.allSatisfy(AnalysisPhysicalEvidenceW39BatchLoader.isSHA256)
            && value.limitations == limitations
            && chainValid
            && AnalysisPhysicalEvidenceW39BatchLoader.isSHA256(value.declaredCheckpointRootSHA256)
            && (try? AnalysisPhysicalRealAudioBridgeConsumptionCheckpointRoot.compute(value)) == value.declaredCheckpointRootSHA256
    }

    public static func validateHandoff(_ value: AnalysisPhysicalRealAudioBridgeExternalAnchorHandoff) -> Bool {
        let chainValid = value.checkpointSequence == 1
            ? value.predecessorHandoffRootSHA256 == nil
            : value.predecessorHandoffRootSHA256.map(AnalysisPhysicalEvidenceW39BatchLoader.isSHA256) == true
        return value.schemaVersion == 1
            && AnalysisPhysicalEvidenceW39BatchLoader.safeComponent(value.handoffID)
            && value.authority == requiredAuthority
            && !value.approvalReference.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && AnalysisPhysicalEvidenceW39BatchLoader.safeComponent(value.ledgerID)
            && AnalysisPhysicalEvidenceW39BatchLoader.safeComponent(value.checkpointID)
            && value.checkpointSequence > 0
            && value.ledgerSequence > 0
            && [
                value.checkpointRootSHA256,
                value.ledgerRootSHA256,
                value.latestRecordRootSHA256,
                value.consumedW47InventoryRootSHA256,
                value.declaredHandoffRootSHA256
            ].allSatisfy(AnalysisPhysicalEvidenceW39BatchLoader.isSHA256)
            && value.limitations == limitations
            && chainValid
            && (try? AnalysisPhysicalRealAudioBridgeExternalAnchorHandoffRoot.compute(value)) == value.declaredHandoffRootSHA256
    }
}

public extension AnalysisPhysicalRealAudioBridgeConsumptionLedgerStore {
    static func expectationUsingDurableConsumedInventory(
        base: AnalysisPhysicalRealAudioParityBridgeExpectation,
        ledgerID: String,
        rootURL: URL,
        fileManager: FileManager = .default
    ) throws -> AnalysisPhysicalRealAudioParityBridgeExpectation {
        let consumed = try consumedW47PackageRootSHA256s(
            ledgerID: ledgerID,
            rootURL: rootURL,
            fileManager: fileManager
        )
        return AnalysisPhysicalRealAudioParityBridgeExpectation(
            schemaVersion: base.schemaVersion,
            authority: base.authority,
            approvalReference: base.approvalReference,
            bridgeID: base.bridgeID,
            expectedW47PackageRootSHA256: base.expectedW47PackageRootSHA256,
            expectedW47PackageBytesSHA256: base.expectedW47PackageBytesSHA256,
            expectedManifestID: base.expectedManifestID,
            expectedManifestSHA256: base.expectedManifestSHA256,
            expectedRuntimeBindingSHA256: base.expectedRuntimeBindingSHA256,
            expectedPhysicalSessionID: base.expectedPhysicalSessionID,
            expectedAuditedProjectReportSHA256: base.expectedAuditedProjectReportSHA256,
            expectedW46BindingSHA256: base.expectedW46BindingSHA256,
            previouslyConsumedW47PackageRootSHA256s: consumed
        )
    }
}

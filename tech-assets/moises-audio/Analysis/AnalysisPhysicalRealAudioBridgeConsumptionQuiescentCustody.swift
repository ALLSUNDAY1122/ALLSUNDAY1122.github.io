import Foundation

public struct AnalysisPhysicalRealAudioBridgeConsumptionQuiescentSnapshot: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let ledgerID: String
    public let latestSequence: UInt64
    public let ledgerRootSHA256: String
    public let latestRecordRootSHA256: String
    public let consumedW47PackageRootSHA256s: [String]
    public let declaredSnapshotRootSHA256: String

    public init(
        schemaVersion: Int = 1,
        ledgerID: String,
        latestSequence: UInt64,
        ledgerRootSHA256: String,
        latestRecordRootSHA256: String,
        consumedW47PackageRootSHA256s: [String],
        declaredSnapshotRootSHA256: String
    ) {
        self.schemaVersion = schemaVersion
        self.ledgerID = ledgerID
        self.latestSequence = latestSequence
        self.ledgerRootSHA256 = ledgerRootSHA256.lowercased()
        self.latestRecordRootSHA256 = latestRecordRootSHA256.lowercased()
        self.consumedW47PackageRootSHA256s = consumedW47PackageRootSHA256s.map { $0.lowercased() }.sorted()
        self.declaredSnapshotRootSHA256 = declaredSnapshotRootSHA256.lowercased()
    }
}

public struct AnalysisPhysicalRealAudioBridgeConsumptionQuiescentCustodyReceipt: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let transactionID: String
    public let authority: String
    public let approvalReference: String
    public let ledgerID: String
    public let snapshotRootSHA256: String
    public let checkpointRootSHA256: String
    public let handoffRootSHA256: String
    public let ledgerSequence: UInt64
    public let ledgerRootSHA256: String
    public let latestRecordRootSHA256: String
    public let consumedW47InventoryRootSHA256: String
    public let predecessorCheckpointRootSHA256: String?
    public let predecessorHandoffRootSHA256: String?
    public let limitations: [String]
    public let declaredReceiptRootSHA256: String

    public init(
        schemaVersion: Int = 1,
        transactionID: String,
        authority: String,
        approvalReference: String,
        ledgerID: String,
        snapshotRootSHA256: String,
        checkpointRootSHA256: String,
        handoffRootSHA256: String,
        ledgerSequence: UInt64,
        ledgerRootSHA256: String,
        latestRecordRootSHA256: String,
        consumedW47InventoryRootSHA256: String,
        predecessorCheckpointRootSHA256: String?,
        predecessorHandoffRootSHA256: String?,
        limitations: [String],
        declaredReceiptRootSHA256: String
    ) {
        self.schemaVersion = schemaVersion
        self.transactionID = transactionID
        self.authority = authority
        self.approvalReference = approvalReference
        self.ledgerID = ledgerID
        self.snapshotRootSHA256 = snapshotRootSHA256.lowercased()
        self.checkpointRootSHA256 = checkpointRootSHA256.lowercased()
        self.handoffRootSHA256 = handoffRootSHA256.lowercased()
        self.ledgerSequence = ledgerSequence
        self.ledgerRootSHA256 = ledgerRootSHA256.lowercased()
        self.latestRecordRootSHA256 = latestRecordRootSHA256.lowercased()
        self.consumedW47InventoryRootSHA256 = consumedW47InventoryRootSHA256.lowercased()
        self.predecessorCheckpointRootSHA256 = predecessorCheckpointRootSHA256?.lowercased()
        self.predecessorHandoffRootSHA256 = predecessorHandoffRootSHA256?.lowercased()
        self.limitations = limitations
        self.declaredReceiptRootSHA256 = declaredReceiptRootSHA256.lowercased()
    }
}

public struct AnalysisPhysicalRealAudioBridgeConsumptionQuiescentCustodyBundle: Codable, Equatable, Sendable {
    public let snapshot: AnalysisPhysicalRealAudioBridgeConsumptionQuiescentSnapshot
    public let checkpoint: AnalysisPhysicalRealAudioBridgeConsumptionCheckpoint
    public let handoff: AnalysisPhysicalRealAudioBridgeExternalAnchorHandoff
    public let receipt: AnalysisPhysicalRealAudioBridgeConsumptionQuiescentCustodyReceipt

    public init(
        snapshot: AnalysisPhysicalRealAudioBridgeConsumptionQuiescentSnapshot,
        checkpoint: AnalysisPhysicalRealAudioBridgeConsumptionCheckpoint,
        handoff: AnalysisPhysicalRealAudioBridgeExternalAnchorHandoff,
        receipt: AnalysisPhysicalRealAudioBridgeConsumptionQuiescentCustodyReceipt
    ) {
        self.snapshot = snapshot
        self.checkpoint = checkpoint
        self.handoff = handoff
        self.receipt = receipt
    }
}

public enum AnalysisPhysicalRealAudioBridgeConsumptionQuiescentCustodyError: Error, Equatable, Sendable {
    case invalidSnapshot
    case staleSnapshotCAS
    case ledgerMissing
    case invalidTransactionRequest
    case transactionVerificationFailed
}

public enum AnalysisPhysicalRealAudioBridgeConsumptionQuiescentSnapshotRoot {
    private struct Payload: Codable {
        let schemaVersion: Int
        let ledgerID: String
        let latestSequence: UInt64
        let ledgerRootSHA256: String
        let latestRecordRootSHA256: String
        let consumedW47PackageRootSHA256s: [String]
    }

    public static func compute(_ value: AnalysisPhysicalRealAudioBridgeConsumptionQuiescentSnapshot) throws -> String {
        try AnalysisAnalysisParityAdjudicationRoot.stableSHA256(Payload(
            schemaVersion: value.schemaVersion,
            ledgerID: value.ledgerID,
            latestSequence: value.latestSequence,
            ledgerRootSHA256: value.ledgerRootSHA256,
            latestRecordRootSHA256: value.latestRecordRootSHA256,
            consumedW47PackageRootSHA256s: value.consumedW47PackageRootSHA256s.sorted()
        ))
    }
}

public enum AnalysisPhysicalRealAudioBridgeConsumptionQuiescentCustodyReceiptRoot {
    private struct Payload: Codable {
        let schemaVersion: Int
        let transactionID: String
        let authority: String
        let approvalReference: String
        let ledgerID: String
        let snapshotRootSHA256: String
        let checkpointRootSHA256: String
        let handoffRootSHA256: String
        let ledgerSequence: UInt64
        let ledgerRootSHA256: String
        let latestRecordRootSHA256: String
        let consumedW47InventoryRootSHA256: String
        let predecessorCheckpointRootSHA256: String?
        let predecessorHandoffRootSHA256: String?
        let limitations: [String]
    }

    public static func compute(_ value: AnalysisPhysicalRealAudioBridgeConsumptionQuiescentCustodyReceipt) throws -> String {
        try AnalysisAnalysisParityAdjudicationRoot.stableSHA256(Payload(
            schemaVersion: value.schemaVersion,
            transactionID: value.transactionID,
            authority: value.authority,
            approvalReference: value.approvalReference,
            ledgerID: value.ledgerID,
            snapshotRootSHA256: value.snapshotRootSHA256,
            checkpointRootSHA256: value.checkpointRootSHA256,
            handoffRootSHA256: value.handoffRootSHA256,
            ledgerSequence: value.ledgerSequence,
            ledgerRootSHA256: value.ledgerRootSHA256,
            latestRecordRootSHA256: value.latestRecordRootSHA256,
            consumedW47InventoryRootSHA256: value.consumedW47InventoryRootSHA256,
            predecessorCheckpointRootSHA256: value.predecessorCheckpointRootSHA256,
            predecessorHandoffRootSHA256: value.predecessorHandoffRootSHA256,
            limitations: value.limitations
        ))
    }
}

public enum AnalysisPhysicalRealAudioBridgeConsumptionQuiescentCustodyManager {
    public static let requiredAuthority = "HQ_LATE_INTEGRATION"
    public static let limitations = [
        "NON_PARITY: W52 serializes ledger snapshots, checkpoints and external-anchor handoffs with W51 writers; it does not promote any Analysis PARITY row.",
        "A quiescent snapshot is a deterministic SHA-256 commitment to one recovered W50/W51 ledger state. It is not a signature, trusted timestamp, Secure Enclave proof or Apple attestation.",
        "The W52 custody receipt binds one snapshot, checkpoint and handoff generated while the authoritative W51 writer lease is held. It does not itself persist the handoff outside the mutable ledger root.",
        "Whole-ledger rollback remains externally authoritative only when HQ stores the latest checkpoint/handoff/receipt root independently from the mutable ledger directory."
    ]

    @available(*, deprecated, message: "Migration-only W52 API. Use AnalysisPhysicalRealAudioBridgeConsumptionNormalizedCustodyManager.observeSnapshot.")
    public static func observeSnapshot(
        ledgerID: String,
        rootURL: URL,
        fileManager: FileManager = .default
    ) throws -> AnalysisPhysicalRealAudioBridgeConsumptionQuiescentSnapshot {
        try AnalysisPhysicalRealAudioBridgeConsumptionLegacyBypassPolicy.requireCompatibilityRoute(.quiescentObserveSnapshot)
        return try AnalysisPhysicalRealAudioBridgeConsumptionNormalizedCustodyManager.observeSnapshot(
            ledgerID: ledgerID,
            rootURL: rootURL,
            fileManager: fileManager
        ).snapshot
    }

    public static func appendCAS(
        for snapshot: AnalysisPhysicalRealAudioBridgeConsumptionQuiescentSnapshot
    ) throws -> AnalysisPhysicalRealAudioBridgeConsumptionAppendCAS {
        guard validateSnapshot(snapshot) else {
            throw AnalysisPhysicalRealAudioBridgeConsumptionQuiescentCustodyError.invalidSnapshot
        }
        let cas = AnalysisPhysicalRealAudioBridgeConsumptionAppendCAS(
            ledgerID: snapshot.ledgerID,
            expectedLatestSequence: snapshot.latestSequence,
            expectedLedgerRootSHA256: snapshot.ledgerRootSHA256,
            expectedLatestRecordRootSHA256: snapshot.latestRecordRootSHA256
        )
        guard AnalysisPhysicalRealAudioBridgeConsumptionConcurrentStore.validateCAS(cas) else {
            throw AnalysisPhysicalRealAudioBridgeConsumptionQuiescentCustodyError.invalidSnapshot
        }
        return cas
    }

    @available(*, deprecated, message: "Migration-only W52 API. Use AnalysisPhysicalRealAudioBridgeConsumptionNormalizedCustodyManager.makeStrictCheckpoint.")
    public static func makeStrictCheckpoint(
        expectedSnapshot: AnalysisPhysicalRealAudioBridgeConsumptionQuiescentSnapshot,
        checkpointID: String,
        checkpointSequence: UInt64,
        approvalReference: String,
        previousCheckpoint: AnalysisPhysicalRealAudioBridgeConsumptionCheckpoint? = nil,
        rootURL: URL,
        fileManager: FileManager = .default
    ) throws -> AnalysisPhysicalRealAudioBridgeConsumptionCheckpoint {
        try AnalysisPhysicalRealAudioBridgeConsumptionLegacyBypassPolicy.requireCompatibilityRoute(.quiescentCheckpointCreate)
        return try AnalysisPhysicalRealAudioBridgeConsumptionNormalizedCustodyManager.makeStrictCheckpoint(
            expectedSnapshot: expectedSnapshot,
            checkpointID: checkpointID,
            checkpointSequence: checkpointSequence,
            approvalReference: approvalReference,
            previousCheckpoint: previousCheckpoint,
            rootURL: rootURL,
            fileManager: fileManager
        ).checkpoint
    }

    @available(*, deprecated, message: "Migration-only W52 API. Use AnalysisPhysicalRealAudioBridgeConsumptionNormalizedCustodyManager.verifyCurrentLedgerStrict.")
    public static func verifyCurrentLedgerStrict(
        checkpoint: AnalysisPhysicalRealAudioBridgeConsumptionCheckpoint,
        expectedSnapshot: AnalysisPhysicalRealAudioBridgeConsumptionQuiescentSnapshot,
        previousCheckpoint: AnalysisPhysicalRealAudioBridgeConsumptionCheckpoint? = nil,
        rootURL: URL,
        fileManager: FileManager = .default
    ) throws {
        try AnalysisPhysicalRealAudioBridgeConsumptionLegacyBypassPolicy.requireCompatibilityRoute(.quiescentCheckpointVerify)
        _ = try AnalysisPhysicalRealAudioBridgeConsumptionNormalizedCustodyManager.verifyCurrentLedgerStrict(
            checkpoint: checkpoint,
            expectedSnapshot: expectedSnapshot,
            previousCheckpoint: previousCheckpoint,
            rootURL: rootURL,
            fileManager: fileManager
        )
    }

    @available(*, deprecated, message: "Migration-only W52 API. Use AnalysisPhysicalRealAudioBridgeConsumptionNormalizedCustodyManager.makeCertifiedCustodyBundle.")
    public static func makeCustodyBundle(
        ledgerID: String,
        expectedSnapshot: AnalysisPhysicalRealAudioBridgeConsumptionQuiescentSnapshot,
        transactionID: String,
        checkpointID: String,
        checkpointSequence: UInt64,
        checkpointApprovalReference: String,
        previousCheckpoint: AnalysisPhysicalRealAudioBridgeConsumptionCheckpoint? = nil,
        handoffID: String,
        handoffApprovalReference: String,
        previousHandoff: AnalysisPhysicalRealAudioBridgeExternalAnchorHandoff? = nil,
        rootURL: URL,
        fileManager: FileManager = .default
    ) throws -> AnalysisPhysicalRealAudioBridgeConsumptionQuiescentCustodyBundle {
        try AnalysisPhysicalRealAudioBridgeConsumptionLegacyBypassPolicy.requireCompatibilityRoute(.quiescentCustodyBundle)
        return try AnalysisPhysicalRealAudioBridgeConsumptionNormalizedCustodyManager.makeCertifiedCustodyBundle(
            ledgerID: ledgerID,
            expectedSnapshot: expectedSnapshot,
            transactionID: transactionID,
            checkpointID: checkpointID,
            checkpointSequence: checkpointSequence,
            checkpointApprovalReference: checkpointApprovalReference,
            previousCheckpoint: previousCheckpoint,
            handoffID: handoffID,
            handoffApprovalReference: handoffApprovalReference,
            previousHandoff: previousHandoff,
            rootURL: rootURL,
            fileManager: fileManager
        ).bundle.custodyBundle
    }

    public static func validateSnapshot(
        _ value: AnalysisPhysicalRealAudioBridgeConsumptionQuiescentSnapshot
    ) -> Bool {
        let cas = AnalysisPhysicalRealAudioBridgeConsumptionAppendCAS(
            ledgerID: value.ledgerID,
            expectedLatestSequence: value.latestSequence,
            expectedLedgerRootSHA256: value.ledgerRootSHA256,
            expectedLatestRecordRootSHA256: value.latestRecordRootSHA256
        )
        return value.schemaVersion == 1
            && AnalysisPhysicalEvidenceW39BatchLoader.safeComponent(value.ledgerID)
            && value.latestSequence > 0
            && AnalysisPhysicalRealAudioBridgeConsumptionConcurrentStore.validateCAS(cas)
            && !value.consumedW47PackageRootSHA256s.isEmpty
            && value.consumedW47PackageRootSHA256s == value.consumedW47PackageRootSHA256s.sorted()
            && Set(value.consumedW47PackageRootSHA256s).count == value.consumedW47PackageRootSHA256s.count
            && value.consumedW47PackageRootSHA256s.allSatisfy(AnalysisPhysicalEvidenceW39BatchLoader.isSHA256)
            && AnalysisPhysicalEvidenceW39BatchLoader.isSHA256(value.declaredSnapshotRootSHA256)
            && (try? AnalysisPhysicalRealAudioBridgeConsumptionQuiescentSnapshotRoot.compute(value)) == value.declaredSnapshotRootSHA256
    }

    public static func validateReceipt(
        _ receipt: AnalysisPhysicalRealAudioBridgeConsumptionQuiescentCustodyReceipt,
        snapshot: AnalysisPhysicalRealAudioBridgeConsumptionQuiescentSnapshot,
        checkpoint: AnalysisPhysicalRealAudioBridgeConsumptionCheckpoint,
        handoff: AnalysisPhysicalRealAudioBridgeExternalAnchorHandoff
    ) -> Bool {
        guard validateSnapshot(snapshot),
              AnalysisPhysicalRealAudioBridgeConsumptionCheckpointManager.validateCheckpointEnvelope(checkpoint),
              AnalysisPhysicalRealAudioBridgeConsumptionCheckpointManager.validateHandoff(handoff),
              receipt.schemaVersion == 1,
              AnalysisPhysicalEvidenceW39BatchLoader.safeComponent(receipt.transactionID),
              receipt.authority == requiredAuthority,
              !receipt.approvalReference.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              receipt.ledgerID == snapshot.ledgerID,
              receipt.snapshotRootSHA256 == snapshot.declaredSnapshotRootSHA256,
              receipt.checkpointRootSHA256 == checkpoint.declaredCheckpointRootSHA256,
              receipt.handoffRootSHA256 == handoff.declaredHandoffRootSHA256,
              receipt.ledgerSequence == snapshot.latestSequence,
              receipt.ledgerRootSHA256 == snapshot.ledgerRootSHA256,
              receipt.latestRecordRootSHA256 == snapshot.latestRecordRootSHA256,
              receipt.predecessorCheckpointRootSHA256 == checkpoint.predecessorCheckpointRootSHA256,
              receipt.predecessorHandoffRootSHA256 == handoff.predecessorHandoffRootSHA256,
              receipt.limitations == limitations,
              AnalysisPhysicalEvidenceW39BatchLoader.isSHA256(receipt.consumedW47InventoryRootSHA256),
              AnalysisPhysicalEvidenceW39BatchLoader.isSHA256(receipt.declaredReceiptRootSHA256),
              checkpointMatchesSnapshot(checkpoint, snapshot: snapshot),
              handoffMatchesSnapshot(handoff, checkpoint: checkpoint, snapshot: snapshot),
              (try? AnalysisPhysicalRealAudioBridgeConsumptionQuiescentCustodyReceiptRoot.compute(receipt)) == receipt.declaredReceiptRootSHA256 else {
            return false
        }
        let inventoryRoot = try? AnalysisAnalysisParityAdjudicationRoot.stableSHA256(
            snapshot.consumedW47PackageRootSHA256s.sorted()
        )
        return inventoryRoot == receipt.consumedW47InventoryRootSHA256
    }

    private static func checkpointMatchesSnapshot(
        _ checkpoint: AnalysisPhysicalRealAudioBridgeConsumptionCheckpoint,
        snapshot: AnalysisPhysicalRealAudioBridgeConsumptionQuiescentSnapshot
    ) -> Bool {
        checkpoint.ledgerID == snapshot.ledgerID
            && checkpoint.latestLedgerSequence == snapshot.latestSequence
            && checkpoint.latestRecordRootSHA256 == snapshot.latestRecordRootSHA256
            && checkpoint.ledgerRootSHA256 == snapshot.ledgerRootSHA256
            && checkpoint.consumedW47PackageRootSHA256s == snapshot.consumedW47PackageRootSHA256s
    }

    private static func handoffMatchesSnapshot(
        _ handoff: AnalysisPhysicalRealAudioBridgeExternalAnchorHandoff,
        checkpoint: AnalysisPhysicalRealAudioBridgeConsumptionCheckpoint,
        snapshot: AnalysisPhysicalRealAudioBridgeConsumptionQuiescentSnapshot
    ) -> Bool {
        guard handoff.ledgerID == snapshot.ledgerID,
              handoff.checkpointID == checkpoint.checkpointID,
              handoff.checkpointSequence == checkpoint.checkpointSequence,
              handoff.checkpointRootSHA256 == checkpoint.declaredCheckpointRootSHA256,
              handoff.ledgerSequence == snapshot.latestSequence,
              handoff.ledgerRootSHA256 == snapshot.ledgerRootSHA256,
              handoff.latestRecordRootSHA256 == snapshot.latestRecordRootSHA256 else {
            return false
        }
        let inventoryRoot = try? AnalysisAnalysisParityAdjudicationRoot.stableSHA256(
            snapshot.consumedW47PackageRootSHA256s.sorted()
        )
        return inventoryRoot == handoff.consumedW47InventoryRootSHA256
    }
}

import Foundation

public struct AnalysisPhysicalRealAudioBridgeConsumptionNormalizedCustodyBundle: Codable, Equatable, Sendable {
    public let normalizationReceipt: AnalysisPhysicalRealAudioBridgeConsumptionNormalizedAccessReceipt
    public let custodyBundle: AnalysisPhysicalRealAudioBridgeConsumptionQuiescentCustodyBundle

    public init(
        normalizationReceipt: AnalysisPhysicalRealAudioBridgeConsumptionNormalizedAccessReceipt,
        custodyBundle: AnalysisPhysicalRealAudioBridgeConsumptionQuiescentCustodyBundle
    ) {
        self.normalizationReceipt = normalizationReceipt
        self.custodyBundle = custodyBundle
    }
}

public enum AnalysisPhysicalRealAudioBridgeConsumptionNormalizedCustodyManager {
    public static let limitations = AnalysisPhysicalRealAudioBridgeConsumptionNormalizedAccess.limitations + [
        "W55 custody APIs require normalization before snapshot/checkpoint/handoff construction and return the normalization receipt beside the existing W52 custody bundle.",
        "W52 checkpoint/handoff/receipt payload formats are preserved exactly; W55 adds an outer normalization receipt rather than changing previously defined roots."
    ]

    public static func observeSnapshot(
        ledgerID: String,
        rootURL: URL,
        fileManager: FileManager = .default
    ) throws -> (
        snapshot: AnalysisPhysicalRealAudioBridgeConsumptionQuiescentSnapshot,
        normalizationReceipt: AnalysisPhysicalRealAudioBridgeConsumptionNormalizedAccessReceipt
    ) {
        try AnalysisPhysicalRealAudioBridgeConsumptionNormalizedAccess.withExclusiveNormalizedLedger(
            ledgerID: ledgerID,
            rootURL: rootURL,
            fileManager: fileManager,
            requireHead: true
        ) { lease, state in
            guard let head = state.head else {
                throw AnalysisPhysicalRealAudioBridgeConsumptionNormalizedAccessError.ledgerMissing
            }
            let snapshot = try makeSnapshot(head)
            try AnalysisPhysicalRealAudioBridgeConsumptionWriterLock.validateLease(lease)
            return (snapshot, state.receipt)
        }
    }

    public static func appendCAS(
        for snapshot: AnalysisPhysicalRealAudioBridgeConsumptionQuiescentSnapshot
    ) throws -> AnalysisPhysicalRealAudioBridgeConsumptionAppendCAS {
        try AnalysisPhysicalRealAudioBridgeConsumptionQuiescentCustodyManager.appendCAS(for: snapshot)
    }

    public static func makeStrictCheckpoint(
        expectedSnapshot: AnalysisPhysicalRealAudioBridgeConsumptionQuiescentSnapshot,
        checkpointID: String,
        checkpointSequence: UInt64,
        approvalReference: String,
        previousCheckpoint: AnalysisPhysicalRealAudioBridgeConsumptionCheckpoint? = nil,
        rootURL: URL,
        fileManager: FileManager = .default
    ) throws -> (
        checkpoint: AnalysisPhysicalRealAudioBridgeConsumptionCheckpoint,
        normalizationReceipt: AnalysisPhysicalRealAudioBridgeConsumptionNormalizedAccessReceipt
    ) {
        guard AnalysisPhysicalRealAudioBridgeConsumptionQuiescentCustodyManager.validateSnapshot(expectedSnapshot) else {
            throw AnalysisPhysicalRealAudioBridgeConsumptionQuiescentCustodyError.invalidSnapshot
        }
        return try AnalysisPhysicalRealAudioBridgeConsumptionNormalizedAccess.withExclusiveNormalizedLedger(
            ledgerID: expectedSnapshot.ledgerID,
            rootURL: rootURL,
            fileManager: fileManager,
            requireHead: true
        ) { lease, state in
            guard let head = state.head else {
                throw AnalysisPhysicalRealAudioBridgeConsumptionNormalizedAccessError.ledgerMissing
            }
            let current = try makeSnapshot(head)
            guard current == expectedSnapshot else {
                throw AnalysisPhysicalRealAudioBridgeConsumptionQuiescentCustodyError.staleSnapshotCAS
            }
            let checkpoint = try AnalysisPhysicalRealAudioBridgeConsumptionSecureCheckpointManager.makeStrictCheckpoint(
                ledgerID: expectedSnapshot.ledgerID,
                checkpointID: checkpointID,
                checkpointSequence: checkpointSequence,
                approvalReference: approvalReference,
                previousCheckpoint: previousCheckpoint,
                rootURL: rootURL,
                fileManager: fileManager
            )
            guard checkpointMatchesSnapshot(checkpoint, snapshot: current) else {
                throw AnalysisPhysicalRealAudioBridgeConsumptionQuiescentCustodyError.transactionVerificationFailed
            }
            try AnalysisPhysicalRealAudioBridgeConsumptionWriterLock.validateLease(lease)
            return (checkpoint, state.receipt)
        }
    }

    public static func verifyCurrentLedgerStrict(
        checkpoint: AnalysisPhysicalRealAudioBridgeConsumptionCheckpoint,
        expectedSnapshot: AnalysisPhysicalRealAudioBridgeConsumptionQuiescentSnapshot,
        previousCheckpoint: AnalysisPhysicalRealAudioBridgeConsumptionCheckpoint? = nil,
        rootURL: URL,
        fileManager: FileManager = .default
    ) throws -> AnalysisPhysicalRealAudioBridgeConsumptionNormalizedAccessReceipt {
        guard AnalysisPhysicalRealAudioBridgeConsumptionQuiescentCustodyManager.validateSnapshot(expectedSnapshot),
              expectedSnapshot.ledgerID == checkpoint.ledgerID else {
            throw AnalysisPhysicalRealAudioBridgeConsumptionQuiescentCustodyError.invalidSnapshot
        }
        return try AnalysisPhysicalRealAudioBridgeConsumptionNormalizedAccess.withExclusiveNormalizedLedger(
            ledgerID: checkpoint.ledgerID,
            rootURL: rootURL,
            fileManager: fileManager,
            requireHead: true
        ) { lease, state in
            guard let head = state.head else {
                throw AnalysisPhysicalRealAudioBridgeConsumptionNormalizedAccessError.ledgerMissing
            }
            let current = try makeSnapshot(head)
            guard current == expectedSnapshot else {
                throw AnalysisPhysicalRealAudioBridgeConsumptionQuiescentCustodyError.staleSnapshotCAS
            }
            try AnalysisPhysicalRealAudioBridgeConsumptionSecureCheckpointManager.verifyCurrentLedgerStrict(
                checkpoint: checkpoint,
                previousCheckpoint: previousCheckpoint,
                rootURL: rootURL,
                fileManager: fileManager
            )
            guard checkpointMatchesSnapshot(checkpoint, snapshot: current) else {
                throw AnalysisPhysicalRealAudioBridgeConsumptionQuiescentCustodyError.transactionVerificationFailed
            }
            try AnalysisPhysicalRealAudioBridgeConsumptionWriterLock.validateLease(lease)
            return state.receipt
        }
    }

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
    ) throws -> AnalysisPhysicalRealAudioBridgeConsumptionNormalizedCustodyBundle {
        guard AnalysisPhysicalEvidenceW39BatchLoader.safeComponent(transactionID),
              !checkpointApprovalReference.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !handoffApprovalReference.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AnalysisPhysicalRealAudioBridgeConsumptionQuiescentCustodyError.invalidTransactionRequest
        }
        guard AnalysisPhysicalRealAudioBridgeConsumptionQuiescentCustodyManager.validateSnapshot(expectedSnapshot),
              expectedSnapshot.ledgerID == ledgerID else {
            throw AnalysisPhysicalRealAudioBridgeConsumptionQuiescentCustodyError.invalidSnapshot
        }

        return try AnalysisPhysicalRealAudioBridgeConsumptionNormalizedAccess.withExclusiveNormalizedLedger(
            ledgerID: ledgerID,
            rootURL: rootURL,
            fileManager: fileManager,
            requireHead: true
        ) { lease, state in
            guard let head = state.head else {
                throw AnalysisPhysicalRealAudioBridgeConsumptionNormalizedAccessError.ledgerMissing
            }
            let snapshot = try makeSnapshot(head)
            guard snapshot == expectedSnapshot else {
                throw AnalysisPhysicalRealAudioBridgeConsumptionQuiescentCustodyError.staleSnapshotCAS
            }

            let checkpoint = try AnalysisPhysicalRealAudioBridgeConsumptionSecureCheckpointManager.makeStrictCheckpoint(
                ledgerID: ledgerID,
                checkpointID: checkpointID,
                checkpointSequence: checkpointSequence,
                approvalReference: checkpointApprovalReference,
                previousCheckpoint: previousCheckpoint,
                rootURL: rootURL,
                fileManager: fileManager
            )
            guard checkpointMatchesSnapshot(checkpoint, snapshot: snapshot) else {
                throw AnalysisPhysicalRealAudioBridgeConsumptionQuiescentCustodyError.transactionVerificationFailed
            }

            let handoff = try AnalysisPhysicalRealAudioBridgeConsumptionCheckpointManager.makeStrictExternalAnchorHandoff(
                handoffID: handoffID,
                approvalReference: handoffApprovalReference,
                checkpoint: checkpoint,
                previousHandoff: previousHandoff
            )
            guard handoffMatchesSnapshot(handoff, checkpoint: checkpoint, snapshot: snapshot) else {
                throw AnalysisPhysicalRealAudioBridgeConsumptionQuiescentCustodyError.transactionVerificationFailed
            }

            let inventoryRoot = try AnalysisAnalysisParityAdjudicationRoot.stableSHA256(
                snapshot.consumedW47PackageRootSHA256s.sorted()
            )
            let provisional = AnalysisPhysicalRealAudioBridgeConsumptionQuiescentCustodyReceipt(
                transactionID: transactionID,
                authority: AnalysisPhysicalRealAudioBridgeConsumptionQuiescentCustodyManager.requiredAuthority,
                approvalReference: checkpointApprovalReference + " | " + handoffApprovalReference,
                ledgerID: ledgerID,
                snapshotRootSHA256: snapshot.declaredSnapshotRootSHA256,
                checkpointRootSHA256: checkpoint.declaredCheckpointRootSHA256,
                handoffRootSHA256: handoff.declaredHandoffRootSHA256,
                ledgerSequence: snapshot.latestSequence,
                ledgerRootSHA256: snapshot.ledgerRootSHA256,
                latestRecordRootSHA256: snapshot.latestRecordRootSHA256,
                consumedW47InventoryRootSHA256: inventoryRoot,
                predecessorCheckpointRootSHA256: checkpoint.predecessorCheckpointRootSHA256,
                predecessorHandoffRootSHA256: handoff.predecessorHandoffRootSHA256,
                limitations: AnalysisPhysicalRealAudioBridgeConsumptionQuiescentCustodyManager.limitations,
                declaredReceiptRootSHA256: String(repeating: "0", count: 64)
            )
            let receiptRoot = try AnalysisPhysicalRealAudioBridgeConsumptionQuiescentCustodyReceiptRoot.compute(provisional)
            let receipt = AnalysisPhysicalRealAudioBridgeConsumptionQuiescentCustodyReceipt(
                transactionID: provisional.transactionID,
                authority: provisional.authority,
                approvalReference: provisional.approvalReference,
                ledgerID: provisional.ledgerID,
                snapshotRootSHA256: provisional.snapshotRootSHA256,
                checkpointRootSHA256: provisional.checkpointRootSHA256,
                handoffRootSHA256: provisional.handoffRootSHA256,
                ledgerSequence: provisional.ledgerSequence,
                ledgerRootSHA256: provisional.ledgerRootSHA256,
                latestRecordRootSHA256: provisional.latestRecordRootSHA256,
                consumedW47InventoryRootSHA256: provisional.consumedW47InventoryRootSHA256,
                predecessorCheckpointRootSHA256: provisional.predecessorCheckpointRootSHA256,
                predecessorHandoffRootSHA256: provisional.predecessorHandoffRootSHA256,
                limitations: provisional.limitations,
                declaredReceiptRootSHA256: receiptRoot
            )
            guard AnalysisPhysicalRealAudioBridgeConsumptionQuiescentCustodyManager.validateReceipt(
                receipt,
                snapshot: snapshot,
                checkpoint: checkpoint,
                handoff: handoff
            ) else {
                throw AnalysisPhysicalRealAudioBridgeConsumptionQuiescentCustodyError.transactionVerificationFailed
            }
            try AnalysisPhysicalRealAudioBridgeConsumptionWriterLock.validateLease(lease)
            let bundle = AnalysisPhysicalRealAudioBridgeConsumptionQuiescentCustodyBundle(
                snapshot: snapshot,
                checkpoint: checkpoint,
                handoff: handoff,
                receipt: receipt
            )
            return .init(normalizationReceipt: state.receipt, custodyBundle: bundle)
        }
    }

    private static func makeSnapshot(
        _ head: AnalysisPhysicalRealAudioBridgeConsumptionLedgerHead
    ) throws -> AnalysisPhysicalRealAudioBridgeConsumptionQuiescentSnapshot {
        let provisional = AnalysisPhysicalRealAudioBridgeConsumptionQuiescentSnapshot(
            ledgerID: head.ledgerID,
            latestSequence: head.latestSequence,
            ledgerRootSHA256: head.declaredLedgerRootSHA256,
            latestRecordRootSHA256: head.latestRecordRootSHA256,
            consumedW47PackageRootSHA256s: head.records.map(\.w47PackageRootSHA256).sorted(),
            declaredSnapshotRootSHA256: String(repeating: "0", count: 64)
        )
        let root = try AnalysisPhysicalRealAudioBridgeConsumptionQuiescentSnapshotRoot.compute(provisional)
        return .init(
            ledgerID: provisional.ledgerID,
            latestSequence: provisional.latestSequence,
            ledgerRootSHA256: provisional.ledgerRootSHA256,
            latestRecordRootSHA256: provisional.latestRecordRootSHA256,
            consumedW47PackageRootSHA256s: provisional.consumedW47PackageRootSHA256s,
            declaredSnapshotRootSHA256: root
        )
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

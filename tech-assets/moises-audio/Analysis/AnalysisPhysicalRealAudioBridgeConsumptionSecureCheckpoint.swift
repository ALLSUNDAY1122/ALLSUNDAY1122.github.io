import Foundation

public enum AnalysisPhysicalRealAudioBridgeConsumptionSecureCheckpointManager {
    @available(*, deprecated, message: "Migration-only checkpoint API. Use AnalysisPhysicalRealAudioBridgeConsumptionNormalizedCustodyManager.makeStrictCheckpoint so W55 normalization evidence is retained.")
    public static func makeStrictCheckpoint(
        ledgerID: String,
        checkpointID: String,
        checkpointSequence: UInt64,
        approvalReference: String,
        previousCheckpoint: AnalysisPhysicalRealAudioBridgeConsumptionCheckpoint? = nil,
        rootURL: URL,
        fileManager: FileManager = .default
    ) throws -> AnalysisPhysicalRealAudioBridgeConsumptionCheckpoint {
        try AnalysisPhysicalRealAudioBridgeConsumptionLegacyBypassPolicy.requireCompatibilityRoute(.secureCheckpointCreate)
        let observed = try AnalysisPhysicalRealAudioBridgeConsumptionNormalizedCustodyManager.observeSnapshot(
            ledgerID: ledgerID,
            rootURL: rootURL,
            fileManager: fileManager
        )
        return try AnalysisPhysicalRealAudioBridgeConsumptionNormalizedCustodyManager.makeStrictCheckpoint(
            expectedSnapshot: observed.snapshot,
            checkpointID: checkpointID,
            checkpointSequence: checkpointSequence,
            approvalReference: approvalReference,
            previousCheckpoint: previousCheckpoint,
            rootURL: rootURL,
            fileManager: fileManager
        ).checkpoint
    }

    @available(*, deprecated, message: "Migration-only checkpoint API. Use AnalysisPhysicalRealAudioBridgeConsumptionNormalizedCustodyManager.verifyCurrentLedgerStrict so W55 normalization evidence is retained.")
    public static func verifyCurrentLedgerStrict(
        checkpoint: AnalysisPhysicalRealAudioBridgeConsumptionCheckpoint,
        previousCheckpoint: AnalysisPhysicalRealAudioBridgeConsumptionCheckpoint? = nil,
        rootURL: URL,
        fileManager: FileManager = .default
    ) throws {
        try AnalysisPhysicalRealAudioBridgeConsumptionLegacyBypassPolicy.requireCompatibilityRoute(.secureCheckpointVerify)
        let observed = try AnalysisPhysicalRealAudioBridgeConsumptionNormalizedCustodyManager.observeSnapshot(
            ledgerID: checkpoint.ledgerID,
            rootURL: rootURL,
            fileManager: fileManager
        )
        _ = try AnalysisPhysicalRealAudioBridgeConsumptionNormalizedCustodyManager.verifyCurrentLedgerStrict(
            checkpoint: checkpoint,
            expectedSnapshot: observed.snapshot,
            previousCheckpoint: previousCheckpoint,
            rootURL: rootURL,
            fileManager: fileManager
        )
    }

    static func makeStrictCheckpointCore(
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
                  AnalysisPhysicalRealAudioBridgeConsumptionCheckpointManager.validateCheckpointEnvelope(previousCheckpoint),
                  previousCheckpoint.checkpointSequence + 1 == checkpointSequence,
                  previousCheckpoint.ledgerID == ledgerID else {
                throw AnalysisPhysicalRealAudioBridgeConsumptionCheckpointError.predecessorCheckpointMismatch
            }
            predecessorRoot = previousCheckpoint.declaredCheckpointRootSHA256
        }

        _ = try AnalysisPhysicalRealAudioBridgeConsumptionSecureStore.recoverIfNeeded(
            ledgerID: ledgerID,
            rootURL: rootURL,
            fileManager: fileManager
        )
        guard let head = try AnalysisPhysicalRealAudioBridgeConsumptionSecureStore.loadValidatedHead(
            ledgerID: ledgerID,
            rootURL: rootURL,
            fileManager: fileManager
        ) else {
            throw AnalysisPhysicalRealAudioBridgeConsumptionCheckpointError.ledgerMissing
        }
        if let previousCheckpoint,
           !AnalysisPhysicalRealAudioBridgeConsumptionCheckpointManager.checkpointIsExactPrefix(previousCheckpoint, of: head) {
            throw AnalysisPhysicalRealAudioBridgeConsumptionCheckpointError.predecessorCheckpointMismatch
        }
        let consumed = head.records.map(\.w47PackageRootSHA256).sorted()
        let provisional = AnalysisPhysicalRealAudioBridgeConsumptionCheckpoint(
            checkpointID: checkpointID,
            checkpointSequence: checkpointSequence,
            authority: AnalysisPhysicalRealAudioBridgeConsumptionCheckpointManager.requiredAuthority,
            approvalReference: approvalReference,
            ledgerID: ledgerID,
            latestLedgerSequence: head.latestSequence,
            latestRecordRootSHA256: head.latestRecordRootSHA256,
            ledgerRootSHA256: head.declaredLedgerRootSHA256,
            consumedW47PackageRootSHA256s: consumed,
            predecessorCheckpointRootSHA256: predecessorRoot,
            limitations: AnalysisPhysicalRealAudioBridgeConsumptionCheckpointManager.limitations,
            declaredCheckpointRootSHA256: String(repeating: "0", count: 64)
        )
        let root = try AnalysisPhysicalRealAudioBridgeConsumptionCheckpointRoot.compute(provisional)
        return .init(
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

    static func verifyCurrentLedgerStrictCore(
        checkpoint: AnalysisPhysicalRealAudioBridgeConsumptionCheckpoint,
        previousCheckpoint: AnalysisPhysicalRealAudioBridgeConsumptionCheckpoint? = nil,
        rootURL: URL,
        fileManager: FileManager = .default
    ) throws {
        guard AnalysisPhysicalRealAudioBridgeConsumptionCheckpointManager.validateCheckpointEnvelope(checkpoint) else {
            throw AnalysisPhysicalRealAudioBridgeConsumptionCheckpointError.invalidCheckpoint
        }
        if checkpoint.checkpointSequence == 1 {
            guard previousCheckpoint == nil, checkpoint.predecessorCheckpointRootSHA256 == nil else {
                throw AnalysisPhysicalRealAudioBridgeConsumptionCheckpointError.predecessorCheckpointMismatch
            }
        } else {
            guard let previousCheckpoint,
                  AnalysisPhysicalRealAudioBridgeConsumptionCheckpointManager.validateCheckpointEnvelope(previousCheckpoint),
                  previousCheckpoint.checkpointSequence + 1 == checkpoint.checkpointSequence,
                  previousCheckpoint.ledgerID == checkpoint.ledgerID,
                  checkpoint.predecessorCheckpointRootSHA256 == previousCheckpoint.declaredCheckpointRootSHA256 else {
                throw AnalysisPhysicalRealAudioBridgeConsumptionCheckpointError.predecessorCheckpointMismatch
            }
        }
        _ = try AnalysisPhysicalRealAudioBridgeConsumptionSecureStore.recoverIfNeeded(
            ledgerID: checkpoint.ledgerID,
            rootURL: rootURL,
            fileManager: fileManager
        )
        guard let head = try AnalysisPhysicalRealAudioBridgeConsumptionSecureStore.loadValidatedHead(
            ledgerID: checkpoint.ledgerID,
            rootURL: rootURL,
            fileManager: fileManager
        ) else {
            throw AnalysisPhysicalRealAudioBridgeConsumptionCheckpointError.ledgerMissing
        }
        if let previousCheckpoint,
           !AnalysisPhysicalRealAudioBridgeConsumptionCheckpointManager.checkpointIsExactPrefix(previousCheckpoint, of: head) {
            throw AnalysisPhysicalRealAudioBridgeConsumptionCheckpointError.predecessorCheckpointMismatch
        }
        let currentConsumed = head.records.map(\.w47PackageRootSHA256).sorted()
        guard checkpoint.latestLedgerSequence == head.latestSequence,
              checkpoint.latestRecordRootSHA256 == head.latestRecordRootSHA256,
              checkpoint.ledgerRootSHA256 == head.declaredLedgerRootSHA256,
              checkpoint.consumedW47PackageRootSHA256s == currentConsumed else {
            throw AnalysisPhysicalRealAudioBridgeConsumptionCheckpointError.staleCheckpointReplay
        }
    }
}

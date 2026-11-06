import Foundation

public extension AnalysisPhysicalRealAudioBridgeConsumptionCheckpointManager {
    static func makeStrictCheckpoint(
        ledgerID: String,
        checkpointID: String,
        checkpointSequence: UInt64,
        approvalReference: String,
        previousCheckpoint: AnalysisPhysicalRealAudioBridgeConsumptionCheckpoint? = nil,
        rootURL: URL,
        fileManager: FileManager = .default
    ) throws -> AnalysisPhysicalRealAudioBridgeConsumptionCheckpoint {
        if let previousCheckpoint {
            guard let head = try AnalysisPhysicalRealAudioBridgeConsumptionLedgerStore.loadValidatedHead(
                ledgerID: ledgerID,
                rootURL: rootURL,
                fileManager: fileManager
            ) else {
                throw AnalysisPhysicalRealAudioBridgeConsumptionCheckpointError.ledgerMissing
            }
            guard checkpointIsExactPrefix(previousCheckpoint, of: head) else {
                throw AnalysisPhysicalRealAudioBridgeConsumptionCheckpointError.predecessorCheckpointMismatch
            }
        }
        return try makeCheckpoint(
            ledgerID: ledgerID,
            checkpointID: checkpointID,
            checkpointSequence: checkpointSequence,
            approvalReference: approvalReference,
            previousCheckpoint: previousCheckpoint,
            rootURL: rootURL,
            fileManager: fileManager
        )
    }

    static func verifyCurrentLedgerStrict(
        checkpoint: AnalysisPhysicalRealAudioBridgeConsumptionCheckpoint,
        previousCheckpoint: AnalysisPhysicalRealAudioBridgeConsumptionCheckpoint? = nil,
        rootURL: URL,
        fileManager: FileManager = .default
    ) throws {
        try verifyCurrentLedger(
            checkpoint: checkpoint,
            previousCheckpoint: previousCheckpoint,
            rootURL: rootURL,
            fileManager: fileManager
        )
        if let previousCheckpoint {
            guard let head = try AnalysisPhysicalRealAudioBridgeConsumptionLedgerStore.loadValidatedHead(
                ledgerID: checkpoint.ledgerID,
                rootURL: rootURL,
                fileManager: fileManager
            ), checkpointIsExactPrefix(previousCheckpoint, of: head) else {
                throw AnalysisPhysicalRealAudioBridgeConsumptionCheckpointError.predecessorCheckpointMismatch
            }
        }
    }

    static func makeStrictExternalAnchorHandoff(
        handoffID: String,
        approvalReference: String,
        checkpoint: AnalysisPhysicalRealAudioBridgeConsumptionCheckpoint,
        previousHandoff: AnalysisPhysicalRealAudioBridgeExternalAnchorHandoff? = nil
    ) throws -> AnalysisPhysicalRealAudioBridgeExternalAnchorHandoff {
        if checkpoint.checkpointSequence > 1 {
            guard let previousHandoff,
                  previousHandoff.checkpointRootSHA256 == checkpoint.predecessorCheckpointRootSHA256 else {
                throw AnalysisPhysicalRealAudioBridgeConsumptionCheckpointError.predecessorHandoffMismatch
            }
        }
        return try makeExternalAnchorHandoff(
            handoffID: handoffID,
            approvalReference: approvalReference,
            checkpoint: checkpoint,
            previousHandoff: previousHandoff
        )
    }

    static func checkpointIsExactPrefix(
        _ checkpoint: AnalysisPhysicalRealAudioBridgeConsumptionCheckpoint,
        of head: AnalysisPhysicalRealAudioBridgeConsumptionLedgerHead
    ) -> Bool {
        guard validateCheckpointEnvelope(checkpoint),
              checkpoint.ledgerID == head.ledgerID,
              checkpoint.latestLedgerSequence < head.latestSequence,
              checkpoint.latestLedgerSequence <= UInt64(head.records.count) else {
            return false
        }
        let prefixCount = Int(checkpoint.latestLedgerSequence)
        let prefix = Array(head.records.prefix(prefixCount))
        guard let latest = prefix.last,
              latest.recordRootSHA256 == checkpoint.latestRecordRootSHA256,
              prefix.map(\.w47PackageRootSHA256).sorted() == checkpoint.consumedW47PackageRootSHA256s,
              let prefixRoot = try? AnalysisPhysicalRealAudioBridgeConsumptionLedgerRoot.compute(
                ledgerID: head.ledgerID,
                records: prefix
              ),
              prefixRoot == checkpoint.ledgerRootSHA256 else {
            return false
        }
        return true
    }
}

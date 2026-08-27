import Foundation

public extension AnalysisPhysicalRealAudioBridgeConsumptionCheckpointManager {
    static func validateHandoff(
        _ value: AnalysisPhysicalRealAudioBridgeExternalAnchorHandoff,
        checkpoint: AnalysisPhysicalRealAudioBridgeConsumptionCheckpoint
    ) -> Bool {
        guard validateHandoff(value), validateCheckpointEnvelope(checkpoint) else { return false }
        let inventoryRoot = try? AnalysisAnalysisParityAdjudicationRoot.stableSHA256(
            checkpoint.consumedW47PackageRootSHA256s.sorted()
        )
        return value.ledgerID == checkpoint.ledgerID
            && value.checkpointID == checkpoint.checkpointID
            && value.checkpointSequence == checkpoint.checkpointSequence
            && value.checkpointRootSHA256 == checkpoint.declaredCheckpointRootSHA256
            && value.ledgerSequence == checkpoint.latestLedgerSequence
            && value.ledgerRootSHA256 == checkpoint.ledgerRootSHA256
            && value.latestRecordRootSHA256 == checkpoint.latestRecordRootSHA256
            && inventoryRoot == value.consumedW47InventoryRootSHA256
    }
}

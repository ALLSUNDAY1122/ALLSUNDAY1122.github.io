import Foundation

public enum AnalysisPhysicalRealAudioBridgeDurabilityRecoveredState: String, Codable, Equatable, Sendable {
    case exactPreAppend = "EXACT_PRE_APPEND"
    case exactPostAppend = "EXACT_POST_APPEND"
    case exactPreOrPost = "EXACT_PRE_OR_POST"
}

public struct AnalysisPhysicalRealAudioBridgeDurabilityProbeTicket: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let authority: String
    public let approvalReference: String
    public let probeID: String
    public let ledgerID: String
    public let sourceRevision: String
    public let buildIdentity: String
    public let physicalSessionID: String
    public let deviceModel: String
    public let osVersion: String
    public let target: AnalysisPhysicalRealAudioBridgeConsumptionDurablePublicationTarget
    public let faultPoint: AnalysisPhysicalRealAudioBridgeConsumptionDurablePublicationFaultPoint
    public let expectedRecoveredState: AnalysisPhysicalRealAudioBridgeDurabilityRecoveredState
    public let preSnapshot: AnalysisPhysicalRealAudioBridgeConsumptionQuiescentSnapshot
    public let bridgeCertificateRootSHA256: String
    public let declaredTicketRootSHA256: String

    public init(
        schemaVersion: Int = 1,
        authority: String,
        approvalReference: String,
        probeID: String,
        ledgerID: String,
        sourceRevision: String,
        buildIdentity: String,
        physicalSessionID: String,
        deviceModel: String,
        osVersion: String,
        target: AnalysisPhysicalRealAudioBridgeConsumptionDurablePublicationTarget,
        faultPoint: AnalysisPhysicalRealAudioBridgeConsumptionDurablePublicationFaultPoint,
        expectedRecoveredState: AnalysisPhysicalRealAudioBridgeDurabilityRecoveredState,
        preSnapshot: AnalysisPhysicalRealAudioBridgeConsumptionQuiescentSnapshot,
        bridgeCertificateRootSHA256: String,
        declaredTicketRootSHA256: String
    ) {
        self.schemaVersion = schemaVersion
        self.authority = authority
        self.approvalReference = approvalReference
        self.probeID = probeID
        self.ledgerID = ledgerID
        self.sourceRevision = sourceRevision
        self.buildIdentity = buildIdentity
        self.physicalSessionID = physicalSessionID
        self.deviceModel = deviceModel
        self.osVersion = osVersion
        self.target = target
        self.faultPoint = faultPoint
        self.expectedRecoveredState = expectedRecoveredState
        self.preSnapshot = preSnapshot
        self.bridgeCertificateRootSHA256 = bridgeCertificateRootSHA256.lowercased()
        self.declaredTicketRootSHA256 = declaredTicketRootSHA256.lowercased()
    }
}

public enum AnalysisPhysicalRealAudioBridgeDurabilityProbeTicketRoot {
    private struct Payload: Codable {
        let schemaVersion: Int
        let authority: String
        let approvalReference: String
        let probeID: String
        let ledgerID: String
        let sourceRevision: String
        let buildIdentity: String
        let physicalSessionID: String
        let deviceModel: String
        let osVersion: String
        let target: AnalysisPhysicalRealAudioBridgeConsumptionDurablePublicationTarget
        let faultPoint: AnalysisPhysicalRealAudioBridgeConsumptionDurablePublicationFaultPoint
        let expectedRecoveredState: AnalysisPhysicalRealAudioBridgeDurabilityRecoveredState
        let preSnapshotRootSHA256: String
        let bridgeCertificateRootSHA256: String
    }

    public static func compute(_ ticket: AnalysisPhysicalRealAudioBridgeDurabilityProbeTicket) throws -> String {
        try AnalysisAnalysisParityAdjudicationRoot.stableSHA256(Payload(
            schemaVersion: ticket.schemaVersion,
            authority: ticket.authority,
            approvalReference: ticket.approvalReference,
            probeID: ticket.probeID,
            ledgerID: ticket.ledgerID,
            sourceRevision: ticket.sourceRevision,
            buildIdentity: ticket.buildIdentity,
            physicalSessionID: ticket.physicalSessionID,
            deviceModel: ticket.deviceModel,
            osVersion: ticket.osVersion,
            target: ticket.target,
            faultPoint: ticket.faultPoint,
            expectedRecoveredState: ticket.expectedRecoveredState,
            preSnapshotRootSHA256: ticket.preSnapshot.declaredSnapshotRootSHA256,
            bridgeCertificateRootSHA256: ticket.bridgeCertificateRootSHA256
        ))
    }
}

public enum AnalysisPhysicalRealAudioBridgeDurabilityProbeContract {
    public static let requiredAuthority = "HQ_LATE_INTEGRATION"
    public static let limitations = [
        "NON_PARITY: W53 durability probes test ledger publication/recovery only and do not establish Moises product parity.",
        "Portable fsync/F_FULLFSYNC protocol evidence is not physical-iPhone/APFS power-loss evidence; the selected device must execute terminate/suspend/relaunch probes.",
        "AFTER_PUBLISH_BEFORE_DIRECTORY_SYNC for an immutable record may recover to exact pre or exact post state after true power loss; mixed/corrupt state is never acceptable.",
        "Probe tickets are SHA-256 commitments to requested runtime/state, not signatures, trusted timestamps, Secure Enclave proofs or Apple attestation."
    ]

    public static func expectedRecoveredState(
        target: AnalysisPhysicalRealAudioBridgeConsumptionDurablePublicationTarget,
        faultPoint: AnalysisPhysicalRealAudioBridgeConsumptionDurablePublicationFaultPoint
    ) -> AnalysisPhysicalRealAudioBridgeDurabilityRecoveredState {
        switch target {
        case .pendingMarker:
            return .exactPreAppend
        case .immutableRecord:
            switch faultPoint {
            case .beforeDataSync, .afterDataSyncBeforePublish:
                return .exactPreAppend
            case .afterPublishBeforeDirectorySync:
                return .exactPreOrPost
            case .afterDirectorySync:
                return .exactPostAppend
            }
        case .ledgerHead:
            return .exactPostAppend
        }
    }

    public static func validate(_ ticket: AnalysisPhysicalRealAudioBridgeDurabilityProbeTicket) -> Bool {
        guard ticket.schemaVersion == 1,
              ticket.authority == requiredAuthority,
              !ticket.approvalReference.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              AnalysisPhysicalEvidenceW39BatchLoader.safeComponent(ticket.probeID),
              AnalysisPhysicalEvidenceW39BatchLoader.safeComponent(ticket.ledgerID),
              !ticket.sourceRevision.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !ticket.buildIdentity.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              AnalysisPhysicalEvidenceW39BatchLoader.safeComponent(ticket.physicalSessionID),
              !ticket.deviceModel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !ticket.osVersion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              ticket.preSnapshot.ledgerID == ticket.ledgerID,
              AnalysisPhysicalRealAudioBridgeConsumptionQuiescentCustodyManager.validateSnapshot(ticket.preSnapshot),
              AnalysisPhysicalEvidenceW39BatchLoader.isSHA256(ticket.bridgeCertificateRootSHA256),
              ticket.expectedRecoveredState == expectedRecoveredState(target: ticket.target, faultPoint: ticket.faultPoint),
              AnalysisPhysicalEvidenceW39BatchLoader.isSHA256(ticket.declaredTicketRootSHA256),
              let computed = try? AnalysisPhysicalRealAudioBridgeDurabilityProbeTicketRoot.compute(ticket),
              computed == ticket.declaredTicketRootSHA256 else {
            return false
        }
        return true
    }
}

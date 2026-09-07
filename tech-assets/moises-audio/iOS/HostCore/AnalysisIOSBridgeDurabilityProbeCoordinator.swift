#if canImport(UIKit) && canImport(Darwin)
import Foundation
import UIKit
import Darwin

public enum AnalysisIOSBridgeDurabilityProbeStatus: String, Codable, Equatable, Sendable {
    case invalidRequest = "W53_INVALID_REQUEST"
    case nonPhysicalRuntime = "W53_NON_PHYSICAL_RUNTIME_NON_PARITY"
    case staleTicket = "W53_STALE_TICKET"
    case interruptedStatePrepared = "W53_INTERRUPTED_STATE_PREPARED_TERMINATE_OR_SUSPEND_NOW"
    case reopenedExactPre = "W53_REOPENED_EXACT_PRE_NON_PARITY"
    case reopenedExactPost = "W53_REOPENED_EXACT_POST_NON_PARITY"
    case reopenedUnexpectedState = "W53_REOPENED_UNEXPECTED_STATE_FAIL_CLOSED"
}

public struct AnalysisIOSBridgeDurabilityProbePreparation: Codable, Equatable, Sendable {
    public let status: AnalysisIOSBridgeDurabilityProbeStatus
    public let ticket: AnalysisPhysicalRealAudioBridgeDurabilityProbeTicket?
    public let observedSyncMode: AnalysisPhysicalRealAudioBridgeConsumptionDurableSyncMode?
    public let issues: [String]

    public init(
        status: AnalysisIOSBridgeDurabilityProbeStatus,
        ticket: AnalysisPhysicalRealAudioBridgeDurabilityProbeTicket?,
        observedSyncMode: AnalysisPhysicalRealAudioBridgeConsumptionDurableSyncMode?,
        issues: [String]
    ) {
        self.status = status
        self.ticket = ticket
        self.observedSyncMode = observedSyncMode
        self.issues = issues.sorted()
    }
}

public struct AnalysisIOSBridgeDurabilityProbeReopenResult: Codable, Equatable, Sendable {
    public let status: AnalysisIOSBridgeDurabilityProbeStatus
    public let ticketRootSHA256: String
    public let observedRecoveredState: AnalysisPhysicalRealAudioBridgeDurabilityRecoveredState?
    public let recoveredSnapshot: AnalysisPhysicalRealAudioBridgeConsumptionQuiescentSnapshot?
    public let issues: [String]

    public init(
        status: AnalysisIOSBridgeDurabilityProbeStatus,
        ticketRootSHA256: String,
        observedRecoveredState: AnalysisPhysicalRealAudioBridgeDurabilityRecoveredState?,
        recoveredSnapshot: AnalysisPhysicalRealAudioBridgeConsumptionQuiescentSnapshot?,
        issues: [String]
    ) {
        self.status = status
        self.ticketRootSHA256 = ticketRootSHA256.lowercased()
        self.observedRecoveredState = observedRecoveredState
        self.recoveredSnapshot = recoveredSnapshot
        self.issues = issues.sorted()
    }
}

@MainActor
public enum AnalysisIOSBridgeDurabilityProbeCoordinator {
    @available(*, deprecated, message: "Migration-only W53 API. Use AnalysisIOSBridgeNormalizedDurabilityProbeCoordinator.makeTicket so W55 normalization evidence is retained.")
    public static func makeTicket(
        authority: String,
        approvalReference: String,
        probeID: String,
        ledgerID: String,
        sourceRevision: String,
        buildIdentity: String,
        physicalSessionID: String,
        target: AnalysisPhysicalRealAudioBridgeConsumptionDurablePublicationTarget,
        faultPoint: AnalysisPhysicalRealAudioBridgeConsumptionDurablePublicationFaultPoint,
        certificate: AnalysisPhysicalRealAudioParityBridgeCertificate,
        rootURL: URL,
        fileManager: FileManager = .default
    ) throws -> AnalysisPhysicalRealAudioBridgeDurabilityProbeTicket {
        try AnalysisPhysicalRealAudioBridgeConsumptionLegacyBypassPolicy.requireCompatibilityRoute(.iosDurabilityMakeTicket)
        return try AnalysisIOSBridgeNormalizedDurabilityProbeCoordinator.makeTicket(
            authority: authority,
            approvalReference: approvalReference,
            probeID: probeID,
            ledgerID: ledgerID,
            sourceRevision: sourceRevision,
            buildIdentity: buildIdentity,
            physicalSessionID: physicalSessionID,
            target: target,
            faultPoint: faultPoint,
            certificate: certificate,
            rootURL: rootURL,
            fileManager: fileManager
        ).ticket
    }

    @available(*, deprecated, message: "Migration-only W53 API. Use AnalysisIOSBridgeNormalizedDurabilityProbeCoordinator.prepareInterruptedState so W55 normalization evidence is retained.")
    public static func prepareInterruptedState(
        ticket: AnalysisPhysicalRealAudioBridgeDurabilityProbeTicket,
        certificate: AnalysisPhysicalRealAudioParityBridgeCertificate,
        custody: AnalysisPhysicalRealAudioBridgeConsumptionCustody,
        rootURL: URL,
        fileManager: FileManager = .default
    ) -> AnalysisIOSBridgeDurabilityProbePreparation {
        do {
            try AnalysisPhysicalRealAudioBridgeConsumptionLegacyBypassPolicy.requireCompatibilityRoute(.iosDurabilityPrepare)
        } catch {
            return .init(
                status: .invalidRequest,
                ticket: ticket,
                observedSyncMode: nil,
                issues: ["W56_LEGACY_PRODUCTION_BYPASS_REJECTED"]
            )
        }
        return AnalysisIOSBridgeNormalizedDurabilityProbeCoordinator.prepareInterruptedState(
            ticket: ticket,
            certificate: certificate,
            custody: custody,
            rootURL: rootURL,
            fileManager: fileManager
        ).preparation
    }

    @available(*, deprecated, message: "Migration-only W53 API. Use AnalysisIOSBridgeNormalizedDurabilityProbeCoordinator.reopenAfterRelaunch so W55 normalization evidence is retained.")
    public static func reopenAfterRelaunch(
        ticket: AnalysisPhysicalRealAudioBridgeDurabilityProbeTicket,
        rootURL: URL,
        fileManager: FileManager = .default
    ) -> AnalysisIOSBridgeDurabilityProbeReopenResult {
        do {
            try AnalysisPhysicalRealAudioBridgeConsumptionLegacyBypassPolicy.requireCompatibilityRoute(.iosDurabilityReopen)
        } catch {
            return .init(
                status: .reopenedUnexpectedState,
                ticketRootSHA256: ticket.declaredTicketRootSHA256,
                observedRecoveredState: nil,
                recoveredSnapshot: nil,
                issues: ["W56_LEGACY_PRODUCTION_BYPASS_REJECTED"]
            )
        }
        return AnalysisIOSBridgeNormalizedDurabilityProbeCoordinator.reopenAfterRelaunch(
            ticket: ticket,
            rootURL: rootURL,
            fileManager: fileManager
        ).result
    }
}
#endif

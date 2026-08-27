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
        guard isSelectedPhysicalIOSRuntime,
              authority == AnalysisPhysicalRealAudioBridgeDurabilityProbeContract.requiredAuthority,
              !approvalReference.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              AnalysisPhysicalEvidenceW39BatchLoader.safeComponent(probeID),
              AnalysisPhysicalEvidenceW39BatchLoader.safeComponent(ledgerID),
              !sourceRevision.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !buildIdentity.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              AnalysisPhysicalEvidenceW39BatchLoader.safeComponent(physicalSessionID),
              AnalysisPhysicalRealAudioParityBridgeCertificateValidator.validate(certificate) else {
            throw AnalysisPhysicalRealAudioBridgeConsumptionQuiescentCustodyError.invalidTransactionRequest
        }
        let snapshot = try AnalysisPhysicalRealAudioBridgeConsumptionQuiescentCustodyManager.observeSnapshot(
            ledgerID: ledgerID,
            rootURL: rootURL,
            fileManager: fileManager
        )
        let expected = AnalysisPhysicalRealAudioBridgeDurabilityProbeContract.expectedRecoveredState(
            target: target,
            faultPoint: faultPoint
        )
        let provisional = AnalysisPhysicalRealAudioBridgeDurabilityProbeTicket(
            authority: authority,
            approvalReference: approvalReference,
            probeID: probeID,
            ledgerID: ledgerID,
            sourceRevision: sourceRevision,
            buildIdentity: buildIdentity,
            physicalSessionID: physicalSessionID,
            deviceModel: deviceModelIdentifier(),
            osVersion: UIDevice.current.systemVersion,
            target: target,
            faultPoint: faultPoint,
            expectedRecoveredState: expected,
            preSnapshot: snapshot,
            bridgeCertificateRootSHA256: certificate.declaredCertificateRootSHA256,
            declaredTicketRootSHA256: String(repeating: "0", count: 64)
        )
        let root = try AnalysisPhysicalRealAudioBridgeDurabilityProbeTicketRoot.compute(provisional)
        return .init(
            authority: provisional.authority,
            approvalReference: provisional.approvalReference,
            probeID: provisional.probeID,
            ledgerID: provisional.ledgerID,
            sourceRevision: provisional.sourceRevision,
            buildIdentity: provisional.buildIdentity,
            physicalSessionID: provisional.physicalSessionID,
            deviceModel: provisional.deviceModel,
            osVersion: provisional.osVersion,
            target: provisional.target,
            faultPoint: provisional.faultPoint,
            expectedRecoveredState: provisional.expectedRecoveredState,
            preSnapshot: provisional.preSnapshot,
            bridgeCertificateRootSHA256: provisional.bridgeCertificateRootSHA256,
            declaredTicketRootSHA256: root
        )
    }

    public static func prepareInterruptedState(
        ticket: AnalysisPhysicalRealAudioBridgeDurabilityProbeTicket,
        certificate: AnalysisPhysicalRealAudioParityBridgeCertificate,
        custody: AnalysisPhysicalRealAudioBridgeConsumptionCustody,
        rootURL: URL,
        fileManager: FileManager = .default
    ) -> AnalysisIOSBridgeDurabilityProbePreparation {
        guard isSelectedPhysicalIOSRuntime else {
            return .init(status: .nonPhysicalRuntime, ticket: nil, observedSyncMode: nil, issues: ["W53_REQUIRES_SELECTED_PHYSICAL_IPHONE"])
        }
        guard AnalysisPhysicalRealAudioBridgeDurabilityProbeContract.validate(ticket),
              ticket.deviceModel == deviceModelIdentifier(),
              ticket.osVersion == UIDevice.current.systemVersion,
              AnalysisPhysicalRealAudioParityBridgeCertificateValidator.validate(certificate),
              certificate.declaredCertificateRootSHA256 == ticket.bridgeCertificateRootSHA256 else {
            return .init(status: .invalidRequest, ticket: nil, observedSyncMode: nil, issues: ["W53_TICKET_DEVICE_OR_CERTIFICATE_BINDING_INVALID"])
        }

        do {
            let syncMode = try calibrateDurableSyncMode(rootURL: rootURL, probeID: ticket.probeID, fileManager: fileManager)
            let injected = AnalysisPhysicalRealAudioBridgeConsumptionDurablePublicationInjectedFault(
                target: ticket.target,
                point: ticket.faultPoint
            )
            return try AnalysisPhysicalRealAudioBridgeConsumptionWriterLock.withExclusiveLock(
                ledgerID: ticket.ledgerID,
                rootURL: rootURL
            ) { lease in
                try AnalysisPhysicalRealAudioBridgeConsumptionWriterLock.validateLease(lease)
                _ = try AnalysisPhysicalRealAudioBridgeConsumptionSecureStore.recoverIfNeeded(
                    ledgerID: ticket.ledgerID,
                    rootURL: rootURL,
                    fileManager: fileManager
                )
                guard let head = try AnalysisPhysicalRealAudioBridgeConsumptionSecureStore.loadValidatedHead(
                    ledgerID: ticket.ledgerID,
                    rootURL: rootURL,
                    fileManager: fileManager
                ), headMatchesSnapshot(head, snapshot: ticket.preSnapshot) else {
                    return .init(status: .staleTicket, ticket: ticket, observedSyncMode: syncMode, issues: ["W53_PRE_SNAPSHOT_CHANGED_BEFORE_INJECTION"])
                }
                do {
                    _ = try AnalysisPhysicalRealAudioBridgeConsumptionSecureStore.appendDurabilityForTesting(
                        ledgerID: ticket.ledgerID,
                        certificate: certificate,
                        custody: custody,
                        rootURL: rootURL,
                        fileManager: fileManager,
                        durablePublicationFault: injected
                    )
                    return .init(status: .invalidRequest, ticket: ticket, observedSyncMode: syncMode, issues: ["W53_INJECTED_BOUNDARY_DID_NOT_INTERRUPT"])
                } catch let error as AnalysisPhysicalRealAudioBridgeConsumptionDurablePublicationError {
                    guard error == .injectedFault(injected) else {
                        return .init(status: .invalidRequest, ticket: ticket, observedSyncMode: syncMode, issues: ["W53_UNEXPECTED_DURABLE_PUBLICATION_ERROR_\(String(describing: error))"])
                    }
                    try AnalysisPhysicalRealAudioBridgeConsumptionWriterLock.validateLease(lease)
                    return .init(
                        status: .interruptedStatePrepared,
                        ticket: ticket,
                        observedSyncMode: syncMode,
                        issues: ["W53_DO_NOT_CALL_RECOVERY_BEFORE_EXTERNAL_TERMINATION_OR_SUSPENSION"]
                    )
                }
            }
        } catch {
            return .init(status: .invalidRequest, ticket: ticket, observedSyncMode: nil, issues: ["W53_PREPARE_FAILED_\(String(describing: error))"])
        }
    }

    public static func reopenAfterRelaunch(
        ticket: AnalysisPhysicalRealAudioBridgeDurabilityProbeTicket,
        rootURL: URL,
        fileManager: FileManager = .default
    ) -> AnalysisIOSBridgeDurabilityProbeReopenResult {
        guard isSelectedPhysicalIOSRuntime,
              AnalysisPhysicalRealAudioBridgeDurabilityProbeContract.validate(ticket),
              ticket.deviceModel == deviceModelIdentifier(),
              ticket.osVersion == UIDevice.current.systemVersion else {
            return .init(
                status: .invalidRequest,
                ticketRootSHA256: ticket.declaredTicketRootSHA256,
                observedRecoveredState: nil,
                recoveredSnapshot: nil,
                issues: ["W53_REOPEN_TICKET_OR_DEVICE_INVALID"]
            )
        }
        do {
            return try AnalysisPhysicalRealAudioBridgeConsumptionWriterLock.withExclusiveLock(
                ledgerID: ticket.ledgerID,
                rootURL: rootURL
            ) { lease in
                try AnalysisPhysicalRealAudioBridgeConsumptionWriterLock.validateLease(lease)
                _ = try AnalysisPhysicalRealAudioBridgeConsumptionSecureStore.recoverIfNeeded(
                    ledgerID: ticket.ledgerID,
                    rootURL: rootURL,
                    fileManager: fileManager
                )
                guard let head = try AnalysisPhysicalRealAudioBridgeConsumptionSecureStore.loadValidatedHead(
                    ledgerID: ticket.ledgerID,
                    rootURL: rootURL,
                    fileManager: fileManager
                ) else {
                    return unexpected(ticket, "W53_LEDGER_MISSING_AFTER_RELAUNCH")
                }
                let snapshot = try snapshot(from: head)
                let observed: AnalysisPhysicalRealAudioBridgeDurabilityRecoveredState
                if snapshot == ticket.preSnapshot {
                    observed = .exactPreAppend
                } else if headIsExactPost(head, ticket: ticket) {
                    observed = .exactPostAppend
                } else {
                    return .init(
                        status: .reopenedUnexpectedState,
                        ticketRootSHA256: ticket.declaredTicketRootSHA256,
                        observedRecoveredState: nil,
                        recoveredSnapshot: snapshot,
                        issues: ["W53_MIXED_OR_MULTI_ADVANCE_STATE_REJECTED"]
                    )
                }
                let accepted: Bool
                switch ticket.expectedRecoveredState {
                case .exactPreAppend:
                    accepted = observed == .exactPreAppend
                case .exactPostAppend:
                    accepted = observed == .exactPostAppend
                case .exactPreOrPost:
                    accepted = true
                }
                guard accepted else {
                    return .init(
                        status: .reopenedUnexpectedState,
                        ticketRootSHA256: ticket.declaredTicketRootSHA256,
                        observedRecoveredState: observed,
                        recoveredSnapshot: snapshot,
                        issues: ["W53_RECOVERED_STATE_OUTSIDE_TICKET_CONTRACT"]
                    )
                }
                try AnalysisPhysicalRealAudioBridgeConsumptionWriterLock.validateLease(lease)
                return .init(
                    status: observed == .exactPreAppend ? .reopenedExactPre : .reopenedExactPost,
                    ticketRootSHA256: ticket.declaredTicketRootSHA256,
                    observedRecoveredState: observed,
                    recoveredSnapshot: snapshot,
                    issues: []
                )
            }
        } catch {
            return unexpected(ticket, "W53_REOPEN_FAILED_\(String(describing: error))")
        }
    }

    private static func calibrateDurableSyncMode(
        rootURL: URL,
        probeID: String,
        fileManager: FileManager
    ) throws -> AnalysisPhysicalRealAudioBridgeConsumptionDurableSyncMode {
        let directory = rootURL.appendingPathComponent(".w53-durability-probe", isDirectory: true)
        if !fileManager.fileExists(atPath: directory.path) {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: false)
            try AnalysisPhysicalRealAudioBridgeConsumptionSecureFilesystem.validateDirectory(directory, within: rootURL)
            try AnalysisPhysicalRealAudioBridgeConsumptionDurablePublication.syncDirectoryMetadata(rootURL, within: rootURL)
        } else {
            try AnalysisPhysicalRealAudioBridgeConsumptionSecureFilesystem.validateDirectory(directory, within: rootURL)
        }
        let url = directory.appendingPathComponent("\(probeID)-sync-calibration.json")
        let receipt = try AnalysisPhysicalRealAudioBridgeConsumptionDurablePublication.replaceAtomically(
            Data("{\"w53\":\"sync-calibration\"}".utf8),
            to: url,
            within: rootURL,
            maximumBytes: 4096,
            target: .pendingMarker
        )
        try AnalysisPhysicalRealAudioBridgeConsumptionDurablePublication.removeDurably(url, within: rootURL)
        return receipt.dataSyncMode
    }

    private static func headMatchesSnapshot(
        _ head: AnalysisPhysicalRealAudioBridgeConsumptionLedgerHead,
        snapshot: AnalysisPhysicalRealAudioBridgeConsumptionQuiescentSnapshot
    ) -> Bool {
        head.ledgerID == snapshot.ledgerID
            && head.latestSequence == snapshot.latestSequence
            && head.declaredLedgerRootSHA256 == snapshot.ledgerRootSHA256
            && head.latestRecordRootSHA256 == snapshot.latestRecordRootSHA256
            && head.records.map(\.w47PackageRootSHA256).sorted() == snapshot.consumedW47PackageRootSHA256s
    }

    private static func headIsExactPost(
        _ head: AnalysisPhysicalRealAudioBridgeConsumptionLedgerHead,
        ticket: AnalysisPhysicalRealAudioBridgeDurabilityProbeTicket
    ) -> Bool {
        guard head.ledgerID == ticket.ledgerID,
              head.latestSequence == ticket.preSnapshot.latestSequence + 1,
              let last = head.records.last,
              last.bridgeCertificateRootSHA256 == ticket.bridgeCertificateRootSHA256,
              last.predecessorRecordRootSHA256 == ticket.preSnapshot.latestRecordRootSHA256 else {
            return false
        }
        let prefix = Array(head.records.dropLast())
        guard prefix.count == Int(ticket.preSnapshot.latestSequence),
              let root = try? AnalysisPhysicalRealAudioBridgeConsumptionLedgerRoot.compute(
                ledgerID: ticket.ledgerID,
                records: prefix
              ), root == ticket.preSnapshot.ledgerRootSHA256 else {
            return false
        }
        return prefix.map(\.w47PackageRootSHA256).sorted() == ticket.preSnapshot.consumedW47PackageRootSHA256s
    }

    private static func snapshot(
        from head: AnalysisPhysicalRealAudioBridgeConsumptionLedgerHead
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

    private static func unexpected(
        _ ticket: AnalysisPhysicalRealAudioBridgeDurabilityProbeTicket,
        _ issue: String
    ) -> AnalysisIOSBridgeDurabilityProbeReopenResult {
        .init(
            status: .reopenedUnexpectedState,
            ticketRootSHA256: ticket.declaredTicketRootSHA256,
            observedRecoveredState: nil,
            recoveredSnapshot: nil,
            issues: [issue]
        )
    }

    private static var isSelectedPhysicalIOSRuntime: Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        return UIDevice.current.userInterfaceIdiom == .phone
        #endif
    }

    private static func deviceModelIdentifier() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let mirror = Mirror(reflecting: systemInfo.machine)
        return mirror.children.reduce(into: "") { result, element in
            guard let value = element.value as? Int8, value != 0 else { return }
            result.append(Character(UnicodeScalar(UInt8(value))))
        }
    }
}
#endif

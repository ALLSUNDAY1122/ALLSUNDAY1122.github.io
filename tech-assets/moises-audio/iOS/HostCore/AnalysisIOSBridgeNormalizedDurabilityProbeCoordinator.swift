#if canImport(UIKit) && canImport(Darwin)
import Foundation
import UIKit
import Darwin

public struct AnalysisIOSBridgeNormalizedDurabilityProbePreparation: Codable, Equatable, Sendable {
    public let preparation: AnalysisIOSBridgeDurabilityProbePreparation
    public let normalizationReceipt: AnalysisPhysicalRealAudioBridgeConsumptionNormalizedAccessReceipt?

    public init(
        preparation: AnalysisIOSBridgeDurabilityProbePreparation,
        normalizationReceipt: AnalysisPhysicalRealAudioBridgeConsumptionNormalizedAccessReceipt?
    ) {
        self.preparation = preparation
        self.normalizationReceipt = normalizationReceipt
    }
}

public struct AnalysisIOSBridgeNormalizedDurabilityProbeReopenResult: Codable, Equatable, Sendable {
    public let result: AnalysisIOSBridgeDurabilityProbeReopenResult
    public let normalizationReceipt: AnalysisPhysicalRealAudioBridgeConsumptionNormalizedAccessReceipt?

    public init(
        result: AnalysisIOSBridgeDurabilityProbeReopenResult,
        normalizationReceipt: AnalysisPhysicalRealAudioBridgeConsumptionNormalizedAccessReceipt?
    ) {
        self.result = result
        self.normalizationReceipt = normalizationReceipt
    }
}

@MainActor
public enum AnalysisIOSBridgeNormalizedDurabilityProbeCoordinator {
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
    ) throws -> (
        ticket: AnalysisPhysicalRealAudioBridgeDurabilityProbeTicket,
        normalizationReceipt: AnalysisPhysicalRealAudioBridgeConsumptionNormalizedAccessReceipt
    ) {
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
        let observed = try AnalysisPhysicalRealAudioBridgeConsumptionNormalizedCustodyManager.observeSnapshot(
            ledgerID: ledgerID,
            rootURL: rootURL,
            fileManager: fileManager
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
            expectedRecoveredState: AnalysisPhysicalRealAudioBridgeDurabilityProbeContract.expectedRecoveredState(
                target: target,
                faultPoint: faultPoint
            ),
            preSnapshot: observed.snapshot,
            bridgeCertificateRootSHA256: certificate.declaredCertificateRootSHA256,
            declaredTicketRootSHA256: String(repeating: "0", count: 64)
        )
        let root = try AnalysisPhysicalRealAudioBridgeDurabilityProbeTicketRoot.compute(provisional)
        let ticket = AnalysisPhysicalRealAudioBridgeDurabilityProbeTicket(
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
        return (ticket, observed.normalizationReceipt)
    }

    public static func prepareInterruptedState(
        ticket: AnalysisPhysicalRealAudioBridgeDurabilityProbeTicket,
        certificate: AnalysisPhysicalRealAudioParityBridgeCertificate,
        custody: AnalysisPhysicalRealAudioBridgeConsumptionCustody,
        rootURL: URL,
        fileManager: FileManager = .default
    ) -> AnalysisIOSBridgeNormalizedDurabilityProbePreparation {
        guard isSelectedPhysicalIOSRuntime else {
            return .init(
                preparation: .init(status: .nonPhysicalRuntime, ticket: nil, observedSyncMode: nil, issues: ["W55_REQUIRES_SELECTED_PHYSICAL_IPHONEOS_ARM64"]),
                normalizationReceipt: nil
            )
        }
        guard AnalysisPhysicalRealAudioBridgeDurabilityProbeContract.validate(ticket),
              ticket.deviceModel == deviceModelIdentifier(),
              ticket.osVersion == UIDevice.current.systemVersion,
              AnalysisPhysicalRealAudioParityBridgeCertificateValidator.validate(certificate),
              certificate.declaredCertificateRootSHA256 == ticket.bridgeCertificateRootSHA256 else {
            return .init(
                preparation: .init(status: .invalidRequest, ticket: nil, observedSyncMode: nil, issues: ["W55_TICKET_DEVICE_OR_CERTIFICATE_BINDING_INVALID"]),
                normalizationReceipt: nil
            )
        }
        do {
            let syncMode = try calibrateDurableSyncMode(rootURL: rootURL, probeID: ticket.probeID, fileManager: fileManager)
            let injected = AnalysisPhysicalRealAudioBridgeConsumptionDurablePublicationInjectedFault(
                target: ticket.target,
                point: ticket.faultPoint
            )
            return try AnalysisPhysicalRealAudioBridgeConsumptionNormalizedAccess.withExclusiveNormalizedLedger(
                ledgerID: ticket.ledgerID,
                rootURL: rootURL,
                fileManager: fileManager,
                requireHead: true
            ) { lease, state in
                guard let head = state.head, headMatchesSnapshot(head, snapshot: ticket.preSnapshot) else {
                    return .init(
                        preparation: .init(status: .staleTicket, ticket: ticket, observedSyncMode: syncMode, issues: ["W55_PRE_SNAPSHOT_CHANGED_AFTER_NORMALIZATION"]),
                        normalizationReceipt: state.receipt
                    )
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
                    return .init(
                        preparation: .init(status: .invalidRequest, ticket: ticket, observedSyncMode: syncMode, issues: ["W55_INJECTED_BOUNDARY_DID_NOT_INTERRUPT"]),
                        normalizationReceipt: state.receipt
                    )
                } catch let error as AnalysisPhysicalRealAudioBridgeConsumptionDurablePublicationError {
                    guard error == .injectedFault(injected) else {
                        return .init(
                            preparation: .init(status: .invalidRequest, ticket: ticket, observedSyncMode: syncMode, issues: ["W55_UNEXPECTED_DURABLE_PUBLICATION_ERROR_\(String(describing: error))"]),
                            normalizationReceipt: state.receipt
                        )
                    }
                    try AnalysisPhysicalRealAudioBridgeConsumptionWriterLock.validateLease(lease)
                    return .init(
                        preparation: .init(
                            status: .interruptedStatePrepared,
                            ticket: ticket,
                            observedSyncMode: syncMode,
                            issues: ["W55_NORMALIZED_BEFORE_INJECTION_DO_NOT_RECOVER_BEFORE_EXTERNAL_TERMINATION"]
                        ),
                        normalizationReceipt: state.receipt
                    )
                }
            }
        } catch {
            return .init(
                preparation: .init(status: .invalidRequest, ticket: ticket, observedSyncMode: nil, issues: ["W55_PREPARE_FAILED_\(String(describing: error))"]),
                normalizationReceipt: nil
            )
        }
    }

    public static func reopenAfterRelaunch(
        ticket: AnalysisPhysicalRealAudioBridgeDurabilityProbeTicket,
        rootURL: URL,
        fileManager: FileManager = .default
    ) -> AnalysisIOSBridgeNormalizedDurabilityProbeReopenResult {
        guard isSelectedPhysicalIOSRuntime,
              AnalysisPhysicalRealAudioBridgeDurabilityProbeContract.validate(ticket),
              ticket.deviceModel == deviceModelIdentifier(),
              ticket.osVersion == UIDevice.current.systemVersion else {
            return .init(
                result: unexpected(ticket, "W55_REOPEN_TICKET_OR_DEVICE_INVALID"),
                normalizationReceipt: nil
            )
        }
        do {
            return try AnalysisPhysicalRealAudioBridgeConsumptionNormalizedAccess.withExclusiveNormalizedLedger(
                ledgerID: ticket.ledgerID,
                rootURL: rootURL,
                fileManager: fileManager,
                requireHead: true
            ) { lease, state in
                guard let head = state.head else {
                    return .init(result: unexpected(ticket, "W55_LEDGER_MISSING_AFTER_NORMALIZED_RELAUNCH"), normalizationReceipt: state.receipt)
                }
                let snapshot = try snapshot(from: head)
                let observed: AnalysisPhysicalRealAudioBridgeDurabilityRecoveredState
                if snapshot == ticket.preSnapshot {
                    observed = .exactPreAppend
                } else if headIsExactPost(head, ticket: ticket) {
                    observed = .exactPostAppend
                } else {
                    return .init(
                        result: .init(
                            status: .reopenedUnexpectedState,
                            ticketRootSHA256: ticket.declaredTicketRootSHA256,
                            observedRecoveredState: nil,
                            recoveredSnapshot: snapshot,
                            issues: ["W55_MIXED_OR_MULTI_ADVANCE_STATE_REJECTED"]
                        ),
                        normalizationReceipt: state.receipt
                    )
                }
                let accepted: Bool
                switch ticket.expectedRecoveredState {
                case .exactPreAppend: accepted = observed == .exactPreAppend
                case .exactPostAppend: accepted = observed == .exactPostAppend
                case .exactPreOrPost: accepted = true
                }
                guard accepted else {
                    return .init(
                        result: .init(
                            status: .reopenedUnexpectedState,
                            ticketRootSHA256: ticket.declaredTicketRootSHA256,
                            observedRecoveredState: observed,
                            recoveredSnapshot: snapshot,
                            issues: ["W55_RECOVERED_STATE_OUTSIDE_TICKET_CONTRACT"]
                        ),
                        normalizationReceipt: state.receipt
                    )
                }
                try AnalysisPhysicalRealAudioBridgeConsumptionWriterLock.validateLease(lease)
                return .init(
                    result: .init(
                        status: observed == .exactPreAppend ? .reopenedExactPre : .reopenedExactPost,
                        ticketRootSHA256: ticket.declaredTicketRootSHA256,
                        observedRecoveredState: observed,
                        recoveredSnapshot: snapshot,
                        issues: []
                    ),
                    normalizationReceipt: state.receipt
                )
            }
        } catch {
            return .init(result: unexpected(ticket, "W55_REOPEN_FAILED_\(String(describing: error))"), normalizationReceipt: nil)
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
        let url = directory.appendingPathComponent("\(probeID)-w55-sync-calibration.json")
        let receipt = try AnalysisPhysicalRealAudioBridgeConsumptionDurablePublication.replaceAtomically(
            Data("{\"w55\":\"sync-calibration\"}".utf8),
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
              last.predecessorRecordRootSHA256 == ticket.preSnapshot.latestRecordRootSHA256 else { return false }
        let prefix = Array(head.records.dropLast())
        guard prefix.count == Int(ticket.preSnapshot.latestSequence),
              let root = try? AnalysisPhysicalRealAudioBridgeConsumptionLedgerRoot.compute(
                ledgerID: ticket.ledgerID,
                records: prefix
              ), root == ticket.preSnapshot.ledgerRootSHA256 else { return false }
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
        #if targetEnvironment(simulator) || targetEnvironment(macCatalyst)
        return false
        #elseif arch(arm64)
        return UIDevice.current.userInterfaceIdiom == .phone
        #else
        return false
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

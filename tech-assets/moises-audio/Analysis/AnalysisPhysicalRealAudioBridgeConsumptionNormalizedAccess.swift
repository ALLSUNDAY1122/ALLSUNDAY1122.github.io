import Foundation

public struct AnalysisPhysicalRealAudioBridgeConsumptionNormalizedAccessReceipt: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let ledgerID: String
    public let removedLedgerTemporaryCount: Int
    public let removedRecordTemporaryCount: Int
    public let recoveredInterruptedAppend: Bool
    public let latestSequence: UInt64
    public let ledgerRootSHA256: String?
    public let latestRecordRootSHA256: String?
    public let declaredReceiptRootSHA256: String

    public init(
        schemaVersion: Int = 1,
        ledgerID: String,
        removedLedgerTemporaryCount: Int,
        removedRecordTemporaryCount: Int,
        recoveredInterruptedAppend: Bool,
        latestSequence: UInt64,
        ledgerRootSHA256: String?,
        latestRecordRootSHA256: String?,
        declaredReceiptRootSHA256: String
    ) {
        self.schemaVersion = schemaVersion
        self.ledgerID = ledgerID
        self.removedLedgerTemporaryCount = removedLedgerTemporaryCount
        self.removedRecordTemporaryCount = removedRecordTemporaryCount
        self.recoveredInterruptedAppend = recoveredInterruptedAppend
        self.latestSequence = latestSequence
        self.ledgerRootSHA256 = ledgerRootSHA256?.lowercased()
        self.latestRecordRootSHA256 = latestRecordRootSHA256?.lowercased()
        self.declaredReceiptRootSHA256 = declaredReceiptRootSHA256.lowercased()
    }
}

struct AnalysisPhysicalRealAudioBridgeConsumptionNormalizedLedgerState: Equatable, Sendable {
    let head: AnalysisPhysicalRealAudioBridgeConsumptionLedgerHead?
    let receipt: AnalysisPhysicalRealAudioBridgeConsumptionNormalizedAccessReceipt
}

public enum AnalysisPhysicalRealAudioBridgeConsumptionNormalizedAccessError: Error, Equatable, Sendable {
    case invalidLedgerID
    case ledgerMissing
    case invalidReceipt
    case preflightChangedBeforeGC
}

public enum AnalysisPhysicalRealAudioBridgeConsumptionNormalizedAccessReceiptRoot {
    private struct Payload: Codable {
        let schemaVersion: Int
        let ledgerID: String
        let removedLedgerTemporaryCount: Int
        let removedRecordTemporaryCount: Int
        let recoveredInterruptedAppend: Bool
        let latestSequence: UInt64
        let ledgerRootSHA256: String?
        let latestRecordRootSHA256: String?
    }

    public static func compute(
        _ value: AnalysisPhysicalRealAudioBridgeConsumptionNormalizedAccessReceipt
    ) throws -> String {
        try AnalysisAnalysisParityAdjudicationRoot.stableSHA256(Payload(
            schemaVersion: value.schemaVersion,
            ledgerID: value.ledgerID,
            removedLedgerTemporaryCount: value.removedLedgerTemporaryCount,
            removedRecordTemporaryCount: value.removedRecordTemporaryCount,
            recoveredInterruptedAppend: value.recoveredInterruptedAppend,
            latestSequence: value.latestSequence,
            ledgerRootSHA256: value.ledgerRootSHA256,
            latestRecordRootSHA256: value.latestRecordRootSHA256
        ))
    }
}

enum AnalysisPhysicalRealAudioBridgeConsumptionNormalizedAccess {
    private typealias Namespace = AnalysisPhysicalRealAudioBridgeConsumptionNamespaceHardening
    private typealias FS = AnalysisPhysicalRealAudioBridgeConsumptionSecureFilesystem

    static let limitations = [
        "NON_PARITY: W55 unifies local ledger normalization before custody/checkpoint/probe access; it does not promote any Analysis PARITY row.",
        "Both ledger and records interrupted-temporary sets are preflight-validated before any W54 garbage collection is attempted. This prevents a pre-existing invalid second directory from causing first-directory cleanup before failure.",
        "W55 normalization requires the W51 writer lease, then performs secure directory bootstrap, two-directory temporary preflight, W54 identity-checked GC, W50/W53 recovery, secure full reopen and final lease validation.",
        "The normalization receipt is a deterministic local SHA-256 commitment to cleanup/recovery/result state, not a signature, trusted timestamp, Apple attestation or substitute for HQ external checkpoint custody."
    ]

    static func withExclusiveNormalizedLedger<T>(
        ledgerID: String,
        rootURL: URL,
        fileManager: FileManager = .default,
        requireHead: Bool,
        body: (
            AnalysisPhysicalRealAudioBridgeConsumptionWriterLease,
            AnalysisPhysicalRealAudioBridgeConsumptionNormalizedLedgerState
        ) throws -> T
    ) throws -> T {
        try AnalysisPhysicalRealAudioBridgeConsumptionWriterLock.withExclusiveLock(
            ledgerID: ledgerID,
            rootURL: rootURL
        ) { lease in
            let state = try normalizeUnderLease(
                ledgerID: ledgerID,
                rootURL: rootURL,
                lease: lease,
                fileManager: fileManager,
                requireHead: requireHead
            )
            let result = try body(lease, state)
            try AnalysisPhysicalRealAudioBridgeConsumptionWriterLock.validateLease(lease)
            return result
        }
    }

    static func normalizeUnderLease(
        ledgerID: String,
        rootURL: URL,
        lease: AnalysisPhysicalRealAudioBridgeConsumptionWriterLease,
        fileManager: FileManager = .default,
        requireHead: Bool
    ) throws -> AnalysisPhysicalRealAudioBridgeConsumptionNormalizedLedgerState {
        guard AnalysisPhysicalEvidenceW39BatchLoader.safeComponent(ledgerID) else {
            throw AnalysisPhysicalRealAudioBridgeConsumptionNormalizedAccessError.invalidLedgerID
        }
        try AnalysisPhysicalRealAudioBridgeConsumptionWriterLock.validateLease(lease)
        try FS.ensureDirectories(ledgerID: ledgerID, rootURL: rootURL, fileManager: fileManager)
        try AnalysisPhysicalRealAudioBridgeConsumptionWriterLock.validateLease(lease)

        let ledgerURL = FS.ledgerURL(ledgerID: ledgerID, rootURL: rootURL)
        let recordsURL = ledgerURL.appendingPathComponent("records", isDirectory: true)
        let ledgerPlan = try preflightTemporarySet(
            directoryURL: ledgerURL,
            rootURL: rootURL,
            maximumBytes: max(FS.maxHeadBytes, FS.maxPendingBytes)
        )
        let recordPlan = try preflightTemporarySet(
            directoryURL: recordsURL,
            rootURL: rootURL,
            maximumBytes: FS.maxRecordBytes
        )
        try AnalysisPhysicalRealAudioBridgeConsumptionWriterLock.validateLease(lease)

        // Recheck both preflight sets immediately before mutation. W54 GC then
        // performs its own identity checks before every unlinkat.
        guard try preflightTemporarySet(
            directoryURL: ledgerURL,
            rootURL: rootURL,
            maximumBytes: max(FS.maxHeadBytes, FS.maxPendingBytes)
        ) == ledgerPlan,
        try preflightTemporarySet(
            directoryURL: recordsURL,
            rootURL: rootURL,
            maximumBytes: FS.maxRecordBytes
        ) == recordPlan else {
            throw AnalysisPhysicalRealAudioBridgeConsumptionNormalizedAccessError.preflightChangedBeforeGC
        }

        let gc = try Namespace.garbageCollectInterruptedPublicationTemps(
            ledgerID: ledgerID,
            rootURL: rootURL,
            lease: lease,
            fileManager: fileManager
        )
        let recovered = try AnalysisPhysicalRealAudioBridgeConsumptionSecureStore.recoverIfNeeded(
            ledgerID: ledgerID,
            rootURL: rootURL,
            fileManager: fileManager
        )
        let head = try AnalysisPhysicalRealAudioBridgeConsumptionSecureStore.loadValidatedHead(
            ledgerID: ledgerID,
            rootURL: rootURL,
            fileManager: fileManager
        )
        if requireHead, head == nil {
            throw AnalysisPhysicalRealAudioBridgeConsumptionNormalizedAccessError.ledgerMissing
        }
        try AnalysisPhysicalRealAudioBridgeConsumptionWriterLock.validateLease(lease)

        let provisional = AnalysisPhysicalRealAudioBridgeConsumptionNormalizedAccessReceipt(
            ledgerID: ledgerID,
            removedLedgerTemporaryCount: gc.removedLedgerTemporaryCount,
            removedRecordTemporaryCount: gc.removedRecordTemporaryCount,
            recoveredInterruptedAppend: recovered,
            latestSequence: head?.latestSequence ?? 0,
            ledgerRootSHA256: head?.declaredLedgerRootSHA256,
            latestRecordRootSHA256: head?.latestRecordRootSHA256,
            declaredReceiptRootSHA256: String(repeating: "0", count: 64)
        )
        let root = try AnalysisPhysicalRealAudioBridgeConsumptionNormalizedAccessReceiptRoot.compute(provisional)
        let receipt = AnalysisPhysicalRealAudioBridgeConsumptionNormalizedAccessReceipt(
            ledgerID: provisional.ledgerID,
            removedLedgerTemporaryCount: provisional.removedLedgerTemporaryCount,
            removedRecordTemporaryCount: provisional.removedRecordTemporaryCount,
            recoveredInterruptedAppend: provisional.recoveredInterruptedAppend,
            latestSequence: provisional.latestSequence,
            ledgerRootSHA256: provisional.ledgerRootSHA256,
            latestRecordRootSHA256: provisional.latestRecordRootSHA256,
            declaredReceiptRootSHA256: root
        )
        guard validateReceipt(receipt, head: head) else {
            throw AnalysisPhysicalRealAudioBridgeConsumptionNormalizedAccessError.invalidReceipt
        }
        return .init(head: head, receipt: receipt)
    }

    static func validateReceipt(
        _ receipt: AnalysisPhysicalRealAudioBridgeConsumptionNormalizedAccessReceipt,
        head: AnalysisPhysicalRealAudioBridgeConsumptionLedgerHead?
    ) -> Bool {
        guard receipt.schemaVersion == 1,
              AnalysisPhysicalEvidenceW39BatchLoader.safeComponent(receipt.ledgerID),
              receipt.removedLedgerTemporaryCount >= 0,
              receipt.removedRecordTemporaryCount >= 0,
              receipt.removedLedgerTemporaryCount <= AnalysisPhysicalRealAudioBridgeConsumptionDurablePublication.maximumInterruptedTemporaryFilesPerDirectory,
              receipt.removedRecordTemporaryCount <= AnalysisPhysicalRealAudioBridgeConsumptionDurablePublication.maximumInterruptedTemporaryFilesPerDirectory,
              AnalysisPhysicalEvidenceW39BatchLoader.isSHA256(receipt.declaredReceiptRootSHA256),
              (try? AnalysisPhysicalRealAudioBridgeConsumptionNormalizedAccessReceiptRoot.compute(receipt)) == receipt.declaredReceiptRootSHA256 else {
            return false
        }
        if let head {
            return receipt.latestSequence == head.latestSequence
                && receipt.ledgerRootSHA256 == head.declaredLedgerRootSHA256
                && receipt.latestRecordRootSHA256 == head.latestRecordRootSHA256
        }
        return receipt.latestSequence == 0
            && receipt.ledgerRootSHA256 == nil
            && receipt.latestRecordRootSHA256 == nil
    }

    private struct TempPlanEntry: Equatable {
        let name: String
        let identity: AnalysisPhysicalRealAudioBridgeConsumptionNamespaceEntryIdentity
    }

    private static func preflightTemporarySet(
        directoryURL: URL,
        rootURL: URL,
        maximumBytes: Int
    ) throws -> [TempPlanEntry] {
        try Namespace.withPinnedDirectory(directoryURL, within: rootURL) { directory in
            let names = try Namespace.directoryEntryNames(directory).filter {
                AnalysisPhysicalRealAudioBridgeConsumptionDurablePublication.isInterruptedTemporaryFileName($0)
            }
            guard names.count <= AnalysisPhysicalRealAudioBridgeConsumptionDurablePublication.maximumInterruptedTemporaryFilesPerDirectory else {
                throw AnalysisPhysicalRealAudioBridgeConsumptionNamespaceError.excessiveInterruptedTemporaries
            }
            return try names.map { name in
                guard let identity = try Namespace.entryIdentity(name: name, in: directory) else {
                    throw AnalysisPhysicalRealAudioBridgeConsumptionNamespaceError.entryIdentityChanged
                }
                try Namespace.validateRegularEntry(identity, maximumBytes: maximumBytes)
                return TempPlanEntry(name: name, identity: identity)
            }
        }
    }
}

import Foundation

public enum AnalysisPhysicalRealAudioBridgeConsumptionInjectedFault: String, Codable, Equatable, Sendable {
    case afterPendingMarker = "AFTER_PENDING_MARKER"
    case afterRecordWrite = "AFTER_RECORD_WRITE"
    case afterHeadWriteBeforePendingRemoval = "AFTER_HEAD_WRITE_BEFORE_PENDING_REMOVAL"
    case corruptPendingMarker = "CORRUPT_PENDING_MARKER"
    case recordCollision = "RECORD_COLLISION"
    case readBackFailure = "READ_BACK_FAILURE"
}

public enum AnalysisPhysicalRealAudioBridgeConsumptionSecureStoreError: Error, Equatable, Sendable {
    case unsafeLedgerID
    case invalidCustody
    case invalidBridgeCertificate
    case duplicateBridgeID
    case duplicateW47PackageRoot
    case duplicateBridgeCertificateRoot
    case unsafeFilesystemTopology
    case pathOutsideLedgerRoot
    case symbolicLinkRejected
    case nonRegularFileRejected
    case oversizedFile
    case corruptedLedger
    case forkedHistory
    case ambiguousRecoveryState
    case existingRecordCollision
    case writeFailed
    case readBackFailed
    case injectedFault(AnalysisPhysicalRealAudioBridgeConsumptionInjectedFault)
}

enum AnalysisPhysicalRealAudioBridgeConsumptionSecureFilesystem {
    static let maxHeadBytes = 16 * 1024 * 1024
    static let maxPendingBytes = 4 * 1024 * 1024
    static let maxRecordBytes = 2 * 1024 * 1024

    static func bridgeRootURL(rootURL: URL) -> URL {
        rootURL.appendingPathComponent("w49-bridge-consumption", isDirectory: true)
    }

    static func ledgerURL(ledgerID: String, rootURL: URL) -> URL {
        bridgeRootURL(rootURL: rootURL).appendingPathComponent(ledgerID, isDirectory: true)
    }

    static func recordRelativePath(_ record: AnalysisPhysicalRealAudioBridgeConsumptionRecord) -> String {
        String(format: "records/%012llu-%@.json", record.sequence, record.declaredRecordRootSHA256)
    }

    static func ensureDirectories(
        ledgerID: String,
        rootURL: URL,
        fileManager: FileManager
    ) throws {
        guard AnalysisPhysicalEvidenceW39BatchLoader.safeComponent(ledgerID) else {
            throw AnalysisPhysicalRealAudioBridgeConsumptionSecureStoreError.unsafeLedgerID
        }
        if !fileManager.fileExists(atPath: rootURL.path) {
            try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
        }
        try validateDirectory(rootURL, within: rootURL)

        let bridgeRoot = bridgeRootURL(rootURL: rootURL)
        let bridgeCreated = !fileManager.fileExists(atPath: bridgeRoot.path)
        if bridgeCreated {
            try fileManager.createDirectory(at: bridgeRoot, withIntermediateDirectories: false)
        }
        try validateDirectory(bridgeRoot, within: rootURL)
        if bridgeCreated {
            try AnalysisPhysicalRealAudioBridgeConsumptionDurablePublication.syncDirectoryMetadata(
                rootURL,
                within: rootURL
            )
        }

        let ledger = ledgerURL(ledgerID: ledgerID, rootURL: rootURL)
        let ledgerCreated = !fileManager.fileExists(atPath: ledger.path)
        if ledgerCreated {
            try fileManager.createDirectory(at: ledger, withIntermediateDirectories: false)
        }
        try validateDirectory(ledger, within: rootURL)
        if ledgerCreated {
            try AnalysisPhysicalRealAudioBridgeConsumptionDurablePublication.syncDirectoryMetadata(
                bridgeRoot,
                within: rootURL
            )
        }

        let records = ledger.appendingPathComponent("records", isDirectory: true)
        let recordsCreated = !fileManager.fileExists(atPath: records.path)
        if recordsCreated {
            try fileManager.createDirectory(at: records, withIntermediateDirectories: false)
        }
        try validateDirectory(records, within: ledger)
        if recordsCreated {
            try AnalysisPhysicalRealAudioBridgeConsumptionDurablePublication.syncDirectoryMetadata(
                ledger,
                within: rootURL
            )
        }
        try validateLedgerTopology(ledgerURL: ledger, rootURL: rootURL, fileManager: fileManager)
    }

    static func validateLedgerTopology(
        ledgerURL: URL,
        rootURL: URL,
        fileManager: FileManager
    ) throws {
        try validateDirectory(ledgerURL, within: rootURL)
        let fixedAllowed: Set<String> = [
            "records",
            AnalysisPhysicalRealAudioBridgeConsumptionLedgerStore.headFileName,
            AnalysisPhysicalRealAudioBridgeConsumptionLedgerStore.pendingFileName
        ]
        let names = try fileManager.contentsOfDirectory(atPath: ledgerURL.path)
        let temporaryNames = names.filter {
            AnalysisPhysicalRealAudioBridgeConsumptionDurablePublication.isInterruptedTemporaryFileName($0)
        }
        guard temporaryNames.count <= AnalysisPhysicalRealAudioBridgeConsumptionDurablePublication.maximumInterruptedTemporaryFilesPerDirectory,
              names.allSatisfy({ fixedAllowed.contains($0) || temporaryNames.contains($0) }) else {
            throw AnalysisPhysicalRealAudioBridgeConsumptionSecureStoreError.unsafeFilesystemTopology
        }
        for name in temporaryNames {
            do {
                try AnalysisPhysicalRealAudioBridgeConsumptionDurablePublication.validateInterruptedTemporaryFile(
                    ledgerURL.appendingPathComponent(name),
                    within: ledgerURL,
                    maximumBytes: maxHeadBytes
                )
            } catch let error as AnalysisPhysicalRealAudioBridgeConsumptionSecureStoreError {
                throw error
            } catch let error as AnalysisPhysicalRealAudioBridgeConsumptionDurablePublicationError {
                switch error {
                case .pathOutsideLedgerRoot:
                    throw AnalysisPhysicalRealAudioBridgeConsumptionSecureStoreError.pathOutsideLedgerRoot
                case .symbolicLinkRejected:
                    throw AnalysisPhysicalRealAudioBridgeConsumptionSecureStoreError.symbolicLinkRejected
                case .nonRegularTargetRejected:
                    throw AnalysisPhysicalRealAudioBridgeConsumptionSecureStoreError.nonRegularFileRejected
                case .oversizedFile:
                    throw AnalysisPhysicalRealAudioBridgeConsumptionSecureStoreError.oversizedFile
                default:
                    throw AnalysisPhysicalRealAudioBridgeConsumptionSecureStoreError.unsafeFilesystemTopology
                }
            } catch {
                throw AnalysisPhysicalRealAudioBridgeConsumptionSecureStoreError.unsafeFilesystemTopology
            }
        }
        let records = ledgerURL.appendingPathComponent("records", isDirectory: true)
        if fileManager.fileExists(atPath: records.path) {
            try validateDirectory(records, within: ledgerURL)
        }
    }

    static func recordDirectoryNames(
        recordsURL: URL,
        ledgerURL: URL,
        fileManager: FileManager
    ) throws -> Set<String> {
        guard fileManager.fileExists(atPath: recordsURL.path) else { return [] }
        try validateDirectory(recordsURL, within: ledgerURL)
        let names = try fileManager.contentsOfDirectory(atPath: recordsURL.path)
        let temporaryNames = names.filter {
            AnalysisPhysicalRealAudioBridgeConsumptionDurablePublication.isInterruptedTemporaryFileName($0)
        }
        guard temporaryNames.count <= AnalysisPhysicalRealAudioBridgeConsumptionDurablePublication.maximumInterruptedTemporaryFilesPerDirectory else {
            throw AnalysisPhysicalRealAudioBridgeConsumptionSecureStoreError.unsafeFilesystemTopology
        }
        for name in temporaryNames {
            do {
                try AnalysisPhysicalRealAudioBridgeConsumptionDurablePublication.validateInterruptedTemporaryFile(
                    recordsURL.appendingPathComponent(name),
                    within: ledgerURL,
                    maximumBytes: maxRecordBytes
                )
            } catch let error as AnalysisPhysicalRealAudioBridgeConsumptionSecureStoreError {
                throw error
            } catch let error as AnalysisPhysicalRealAudioBridgeConsumptionDurablePublicationError {
                switch error {
                case .pathOutsideLedgerRoot:
                    throw AnalysisPhysicalRealAudioBridgeConsumptionSecureStoreError.pathOutsideLedgerRoot
                case .symbolicLinkRejected:
                    throw AnalysisPhysicalRealAudioBridgeConsumptionSecureStoreError.symbolicLinkRejected
                case .nonRegularTargetRejected:
                    throw AnalysisPhysicalRealAudioBridgeConsumptionSecureStoreError.nonRegularFileRejected
                case .oversizedFile:
                    throw AnalysisPhysicalRealAudioBridgeConsumptionSecureStoreError.oversizedFile
                default:
                    throw AnalysisPhysicalRealAudioBridgeConsumptionSecureStoreError.unsafeFilesystemTopology
                }
            } catch {
                throw AnalysisPhysicalRealAudioBridgeConsumptionSecureStoreError.unsafeFilesystemTopology
            }
        }
        return Set(names.filter { !temporaryNames.contains($0) })
    }

    static func validateDirectory(_ url: URL, within root: URL) throws {
        guard lexicallyContained(url, within: root) else {
            throw AnalysisPhysicalRealAudioBridgeConsumptionSecureStoreError.pathOutsideLedgerRoot
        }
        let values = try url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard values.isSymbolicLink != true else {
            throw AnalysisPhysicalRealAudioBridgeConsumptionSecureStoreError.symbolicLinkRejected
        }
        guard values.isDirectory == true else {
            throw AnalysisPhysicalRealAudioBridgeConsumptionSecureStoreError.unsafeFilesystemTopology
        }
        let resolvedRoot = root.standardizedFileURL.resolvingSymlinksInPath()
        let resolvedURL = url.standardizedFileURL.resolvingSymlinksInPath()
        guard lexicallyContained(resolvedURL, within: resolvedRoot) else {
            throw AnalysisPhysicalRealAudioBridgeConsumptionSecureStoreError.pathOutsideLedgerRoot
        }
    }

    static func readRegularFile(
        _ url: URL,
        within root: URL,
        maximumBytes: Int
    ) throws -> Data {
        guard lexicallyContained(url, within: root) else {
            throw AnalysisPhysicalRealAudioBridgeConsumptionSecureStoreError.pathOutsideLedgerRoot
        }
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
        guard values.isSymbolicLink != true else {
            throw AnalysisPhysicalRealAudioBridgeConsumptionSecureStoreError.symbolicLinkRejected
        }
        guard values.isRegularFile == true else {
            throw AnalysisPhysicalRealAudioBridgeConsumptionSecureStoreError.nonRegularFileRejected
        }
        guard let fileSize = values.fileSize, fileSize >= 0, fileSize <= maximumBytes else {
            throw AnalysisPhysicalRealAudioBridgeConsumptionSecureStoreError.oversizedFile
        }
        let resolvedRoot = root.standardizedFileURL.resolvingSymlinksInPath()
        let resolvedURL = url.standardizedFileURL.resolvingSymlinksInPath()
        guard lexicallyContained(resolvedURL, within: resolvedRoot) else {
            throw AnalysisPhysicalRealAudioBridgeConsumptionSecureStoreError.pathOutsideLedgerRoot
        }
        let data = try Data(contentsOf: url)
        guard data.count <= maximumBytes else {
            throw AnalysisPhysicalRealAudioBridgeConsumptionSecureStoreError.oversizedFile
        }
        return data
    }

    static func writeControlFile(
        _ data: Data,
        to url: URL,
        ledgerURL: URL,
        maximumBytes: Int,
        fileManager: FileManager
    ) throws {
        let target: AnalysisPhysicalRealAudioBridgeConsumptionDurablePublicationTarget =
            url.lastPathComponent == AnalysisPhysicalRealAudioBridgeConsumptionLedgerStore.pendingFileName
            ? .pendingMarker
            : .ledgerHead
        _ = try writeControlFileDurably(
            data,
            to: url,
            ledgerURL: ledgerURL,
            maximumBytes: maximumBytes,
            target: target,
            fileManager: fileManager,
            injectedFault: nil
        )
    }

    @discardableResult
    static func writeControlFileDurably(
        _ data: Data,
        to url: URL,
        ledgerURL: URL,
        maximumBytes: Int,
        target: AnalysisPhysicalRealAudioBridgeConsumptionDurablePublicationTarget,
        fileManager: FileManager,
        injectedFault: AnalysisPhysicalRealAudioBridgeConsumptionDurablePublicationInjectedFault?
    ) throws -> AnalysisPhysicalRealAudioBridgeConsumptionDurablePublicationReceipt {
        guard data.count <= maximumBytes else {
            throw AnalysisPhysicalRealAudioBridgeConsumptionSecureStoreError.oversizedFile
        }
        guard lexicallyContained(url, within: ledgerURL) else {
            throw AnalysisPhysicalRealAudioBridgeConsumptionSecureStoreError.pathOutsideLedgerRoot
        }
        if fileManager.fileExists(atPath: url.path) {
            let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
            guard values.isSymbolicLink != true else {
                throw AnalysisPhysicalRealAudioBridgeConsumptionSecureStoreError.symbolicLinkRejected
            }
            guard values.isRegularFile == true else {
                throw AnalysisPhysicalRealAudioBridgeConsumptionSecureStoreError.nonRegularFileRejected
            }
        }
        let receipt = try AnalysisPhysicalRealAudioBridgeConsumptionDurablePublication.replaceAtomically(
            data,
            to: url,
            within: ledgerURL,
            maximumBytes: maximumBytes,
            target: target,
            injectedFault: injectedFault
        )
        _ = try readRegularFile(url, within: ledgerURL, maximumBytes: maximumBytes)
        return receipt
    }

    static func lexicallyContained(_ url: URL, within root: URL) -> Bool {
        let rootPath = root.standardizedFileURL.path
        let targetPath = url.standardizedFileURL.path
        if targetPath == rootPath { return true }
        let prefix = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"
        return targetPath.hasPrefix(prefix)
    }
}

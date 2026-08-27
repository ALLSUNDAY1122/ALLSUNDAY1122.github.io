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

public enum AnalysisPhysicalRealAudioBridgeConsumptionSecureStore {
    public static let maxHeadBytes = 16 * 1024 * 1024
    public static let maxPendingBytes = 4 * 1024 * 1024
    public static let maxRecordBytes = 2 * 1024 * 1024
    public static let limitations = [
        "NON_PARITY: W50 hardens W49 bridge-consumption custody against filesystem substitution and ambiguous local crash states; it does not promote any Analysis PARITY row.",
        "W50 rejects symlinked or non-regular ledger/control/record paths, confines reads to the caller-selected canonical ledger root and bounds control/record file sizes before decoding.",
        "Injected fault recovery establishes deterministic local state-machine behavior, not APFS power-loss durability, fsync guarantees, Apple attestation or a trusted timestamp.",
        "Whole-ledger rollback remains externally authoritative only when HQ independently retains the latest W49 checkpoint/handoff root outside the mutable ledger directory."
    ]

    @discardableResult
    public static func append(
        ledgerID: String,
        certificate: AnalysisPhysicalRealAudioParityBridgeCertificate,
        custody: AnalysisPhysicalRealAudioBridgeConsumptionCustody,
        rootURL: URL,
        fileManager: FileManager = .default
    ) throws -> AnalysisPhysicalRealAudioBridgeConsumptionLedgerHead {
        try appendInternal(
            ledgerID: ledgerID,
            certificate: certificate,
            custody: custody,
            rootURL: rootURL,
            fileManager: fileManager,
            injectedFault: nil
        )
    }

    @discardableResult
    static func appendForTesting(
        ledgerID: String,
        certificate: AnalysisPhysicalRealAudioParityBridgeCertificate,
        custody: AnalysisPhysicalRealAudioBridgeConsumptionCustody,
        rootURL: URL,
        fileManager: FileManager = .default,
        injectedFault: AnalysisPhysicalRealAudioBridgeConsumptionInjectedFault
    ) throws -> AnalysisPhysicalRealAudioBridgeConsumptionLedgerHead {
        try appendInternal(
            ledgerID: ledgerID,
            certificate: certificate,
            custody: custody,
            rootURL: rootURL,
            fileManager: fileManager,
            injectedFault: injectedFault
        )
    }

    public static func consumedW47PackageRootSHA256s(
        ledgerID: String,
        rootURL: URL,
        fileManager: FileManager = .default
    ) throws -> [String] {
        _ = try recoverIfNeeded(ledgerID: ledgerID, rootURL: rootURL, fileManager: fileManager)
        return try loadValidatedHead(ledgerID: ledgerID, rootURL: rootURL, fileManager: fileManager)?
            .records.map(\.w47PackageRootSHA256).sorted() ?? []
    }

    public static func expectationUsingDurableConsumedInventory(
        base: AnalysisPhysicalRealAudioParityBridgeExpectation,
        ledgerID: String,
        rootURL: URL,
        fileManager: FileManager = .default
    ) throws -> AnalysisPhysicalRealAudioParityBridgeExpectation {
        let consumed = try consumedW47PackageRootSHA256s(
            ledgerID: ledgerID,
            rootURL: rootURL,
            fileManager: fileManager
        )
        return .init(
            schemaVersion: base.schemaVersion,
            authority: base.authority,
            approvalReference: base.approvalReference,
            bridgeID: base.bridgeID,
            expectedW47PackageRootSHA256: base.expectedW47PackageRootSHA256,
            expectedW47PackageBytesSHA256: base.expectedW47PackageBytesSHA256,
            expectedManifestID: base.expectedManifestID,
            expectedManifestSHA256: base.expectedManifestSHA256,
            expectedRuntimeBindingSHA256: base.expectedRuntimeBindingSHA256,
            expectedPhysicalSessionID: base.expectedPhysicalSessionID,
            expectedAuditedProjectReportSHA256: base.expectedAuditedProjectReportSHA256,
            expectedW46BindingSHA256: base.expectedW46BindingSHA256,
            previouslyConsumedW47PackageRootSHA256s: consumed
        )
    }

    public static func loadValidatedHead(
        ledgerID: String,
        rootURL: URL,
        fileManager: FileManager = .default
    ) throws -> AnalysisPhysicalRealAudioBridgeConsumptionLedgerHead? {
        try loadValidatedHead(
            ledgerID: ledgerID,
            rootURL: rootURL,
            fileManager: fileManager,
            allowedPendingRelativePath: nil
        )
    }

    @discardableResult
    public static func recoverIfNeeded(
        ledgerID: String,
        rootURL: URL,
        fileManager: FileManager = .default
    ) throws -> Bool {
        guard safeComponent(ledgerID) else { throw AnalysisPhysicalRealAudioBridgeConsumptionSecureStoreError.unsafeLedgerID }
        guard fileManager.fileExists(atPath: rootURL.path) else { return false }
        try validateDirectory(rootURL, within: rootURL, fileManager: fileManager)

        let parentURL = bridgeConsumptionRootURL(rootURL: rootURL)
        guard fileManager.fileExists(atPath: parentURL.path) else { return false }
        try validateDirectory(parentURL, within: rootURL, fileManager: fileManager)

        let ledgerURL = ledgerDirectoryURL(ledgerID: ledgerID, rootURL: rootURL)
        guard fileManager.fileExists(atPath: ledgerURL.path) else { return false }
        try validateLedgerTopology(ledgerURL: ledgerURL, rootURL: rootURL, fileManager: fileManager)

        let pendingURL = ledgerURL.appendingPathComponent(AnalysisPhysicalRealAudioBridgeConsumptionLedgerStore.pendingFileName)
        guard fileManager.fileExists(atPath: pendingURL.path) else {
            _ = try loadValidatedHead(ledgerID: ledgerID, rootURL: rootURL, fileManager: fileManager)
            return false
        }

        let pending: AnalysisPhysicalRealAudioBridgeConsumptionPendingAppend
        do {
            let bytes = try readRegularFile(
                pendingURL,
                within: ledgerURL,
                maximumBytes: maxPendingBytes,
                fileManager: fileManager
            )
            pending = try AnalysisPhysicalRealAudioBridgeConsumptionLedgerCodec.decodePending(bytes)
        } catch let error as AnalysisPhysicalRealAudioBridgeConsumptionSecureStoreError {
            switch error {
            case .symbolicLinkRejected, .nonRegularFileRejected, .pathOutsideLedgerRoot, .oversizedFile, .unsafeFilesystemTopology:
                throw error
            default:
                throw AnalysisPhysicalRealAudioBridgeConsumptionSecureStoreError.ambiguousRecoveryState
            }
        } catch {
            throw AnalysisPhysicalRealAudioBridgeConsumptionSecureStoreError.ambiguousRecoveryState
        }

        guard pending.schemaVersion == 1,
              pending.ledgerID == ledgerID,
              validateRecord(pending.candidateRecord),
              pending.candidateRelativePath == recordRelativePath(pending.candidateRecord),
              AnalysisPhysicalEvidenceW39BatchLoader.safeRelativePath(pending.candidateRelativePath),
              pending.candidateRelativePath.hasPrefix("records/"),
              pending.previousLedgerRootSHA256.map(isSHA256) ?? true,
              pending.previousLatestRecordRootSHA256.map(isSHA256) ?? true else {
            throw AnalysisPhysicalRealAudioBridgeConsumptionSecureStoreError.ambiguousRecoveryState
        }

        let head = try loadValidatedHead(
            ledgerID: ledgerID,
            rootURL: rootURL,
            fileManager: fileManager,
            allowedPendingRelativePath: pending.candidateRelativePath
        )
        let recordURL = ledgerURL.appendingPathComponent(pending.candidateRelativePath)
        let recordExists = fileManager.fileExists(atPath: recordURL.path)

        if let head, head.latestSequence == pending.candidateRecord.sequence {
            guard head.latestRecordRootSHA256 == pending.candidateRecord.declaredRecordRootSHA256,
                  recordExists,
                  try readRecord(
                    relativePath: pending.candidateRelativePath,
                    ledgerURL: ledgerURL,
                    fileManager: fileManager
                  ) == pending.candidateRecord else {
                throw AnalysisPhysicalRealAudioBridgeConsumptionSecureStoreError.ambiguousRecoveryState
            }
            try fileManager.removeItem(at: pendingURL)
            _ = try loadValidatedHead(ledgerID: ledgerID, rootURL: rootURL, fileManager: fileManager)
            return true
        }

        let expectedSequence = (head?.latestSequence ?? 0) + 1
        guard pending.candidateRecord.sequence == expectedSequence,
              pending.previousLedgerRootSHA256 == head?.declaredLedgerRootSHA256,
              pending.previousLatestRecordRootSHA256 == head?.latestRecordRootSHA256,
              pending.candidateRecord.predecessorRecordRootSHA256 == head?.latestRecordRootSHA256 else {
            throw AnalysisPhysicalRealAudioBridgeConsumptionSecureStoreError.ambiguousRecoveryState
        }

        if !recordExists {
            try fileManager.removeItem(at: pendingURL)
            _ = try loadValidatedHead(ledgerID: ledgerID, rootURL: rootURL, fileManager: fileManager)
            return true
        }

        guard try readRecord(
            relativePath: pending.candidateRelativePath,
            ledgerURL: ledgerURL,
            fileManager: fileManager
        ) == pending.candidateRecord else {
            throw AnalysisPhysicalRealAudioBridgeConsumptionSecureStoreError.ambiguousRecoveryState
        }

        let repaired = try makeHead(previous: head, record: pending.candidateRecord, relativePath: pending.candidateRelativePath)
        try writeControlFile(
            AnalysisPhysicalRealAudioBridgeConsumptionLedgerCodec.encodeHead(repaired),
            to: ledgerURL.appendingPathComponent(AnalysisPhysicalRealAudioBridgeConsumptionLedgerStore.headFileName),
            ledgerURL: ledgerURL,
            maximumBytes: maxHeadBytes,
            fileManager: fileManager
        )
        try fileManager.removeItem(at: pendingURL)
        guard try loadValidatedHead(ledgerID: ledgerID, rootURL: rootURL, fileManager: fileManager) == repaired else {
            throw AnalysisPhysicalRealAudioBridgeConsumptionSecureStoreError.readBackFailed
        }
        return true
    }

    private static func appendInternal(
        ledgerID: String,
        certificate: AnalysisPhysicalRealAudioParityBridgeCertificate,
        custody: AnalysisPhysicalRealAudioBridgeConsumptionCustody,
        rootURL: URL,
        fileManager: FileManager,
        injectedFault: AnalysisPhysicalRealAudioBridgeConsumptionInjectedFault?
    ) throws -> AnalysisPhysicalRealAudioBridgeConsumptionLedgerHead {
        guard safeComponent(ledgerID) else { throw AnalysisPhysicalRealAudioBridgeConsumptionSecureStoreError.unsafeLedgerID }
        guard AnalysisPhysicalRealAudioBridgeConsumptionLedgerStore.validateCustody(custody) else {
            throw AnalysisPhysicalRealAudioBridgeConsumptionSecureStoreError.invalidCustody
        }
        guard AnalysisPhysicalRealAudioParityBridgeCertificateValidator.validate(certificate) else {
            throw AnalysisPhysicalRealAudioBridgeConsumptionSecureStoreError.invalidBridgeCertificate
        }

        try ensureSecureDirectories(ledgerID: ledgerID, rootURL: rootURL, fileManager: fileManager)
        _ = try recoverIfNeeded(ledgerID: ledgerID, rootURL: rootURL, fileManager: fileManager)
        let oldHead = try loadValidatedHead(ledgerID: ledgerID, rootURL: rootURL, fileManager: fileManager)
        if let oldHead {
            if oldHead.records.contains(where: { $0.bridgeID == certificate.bridgeID }) {
                throw AnalysisPhysicalRealAudioBridgeConsumptionSecureStoreError.duplicateBridgeID
            }
            if oldHead.records.contains(where: { $0.w47PackageRootSHA256 == certificate.w47PackageRootSHA256 }) {
                throw AnalysisPhysicalRealAudioBridgeConsumptionSecureStoreError.duplicateW47PackageRoot
            }
            if oldHead.records.contains(where: { $0.bridgeCertificateRootSHA256 == certificate.declaredCertificateRootSHA256 }) {
                throw AnalysisPhysicalRealAudioBridgeConsumptionSecureStoreError.duplicateBridgeCertificateRoot
            }
        }

        let sequence = (oldHead?.latestSequence ?? 0) + 1
        let provisional = AnalysisPhysicalRealAudioBridgeConsumptionRecord(
            ledgerID: ledgerID,
            sequence: sequence,
            bridgeID: certificate.bridgeID,
            bridgeCertificateRootSHA256: certificate.declaredCertificateRootSHA256,
            w47PackageRootSHA256: certificate.w47PackageRootSHA256,
            w46AdjudicationReportRootSHA256: certificate.w46AdjudicationReportRootSHA256,
            expectationRootSHA256: certificate.expectationRootSHA256,
            custody: custody,
            predecessorRecordRootSHA256: oldHead?.latestRecordRootSHA256,
            declaredRecordRootSHA256: String(repeating: "0", count: 64)
        )
        let recordRoot = try AnalysisPhysicalRealAudioBridgeConsumptionRecordRoot.compute(provisional)
        let record = AnalysisPhysicalRealAudioBridgeConsumptionRecord(
            ledgerID: provisional.ledgerID,
            sequence: provisional.sequence,
            bridgeID: provisional.bridgeID,
            bridgeCertificateRootSHA256: provisional.bridgeCertificateRootSHA256,
            w47PackageRootSHA256: provisional.w47PackageRootSHA256,
            w46AdjudicationReportRootSHA256: provisional.w46AdjudicationReportRootSHA256,
            expectationRootSHA256: provisional.expectationRootSHA256,
            custody: provisional.custody,
            predecessorRecordRootSHA256: provisional.predecessorRecordRootSHA256,
            declaredRecordRootSHA256: recordRoot
        )
        let relativePath = recordRelativePath(record)
        let ledgerURL = ledgerDirectoryURL(ledgerID: ledgerID, rootURL: rootURL)
        let pendingURL = ledgerURL.appendingPathComponent(AnalysisPhysicalRealAudioBridgeConsumptionLedgerStore.pendingFileName)
        let pending = AnalysisPhysicalRealAudioBridgeConsumptionPendingAppend(
            ledgerID: ledgerID,
            candidateRecord: record,
            candidateRelativePath: relativePath,
            previousLedgerRootSHA256: oldHead?.declaredLedgerRootSHA256,
            previousLatestRecordRootSHA256: oldHead?.latestRecordRootSHA256
        )

        do {
            let pendingBytes = try AnalysisPhysicalRealAudioBridgeConsumptionLedgerCodec.encodePending(pending)
            try writeControlFile(
                pendingBytes,
                to: pendingURL,
                ledgerURL: ledgerURL,
                maximumBytes: maxPendingBytes,
                fileManager: fileManager
            )
            if injectedFault == .corruptPendingMarker {
                try Data("{".utf8).write(to: pendingURL, options: .atomic)
                throw AnalysisPhysicalRealAudioBridgeConsumptionSecureStoreError.injectedFault(.corruptPendingMarker)
            }
            if injectedFault == .afterPendingMarker {
                throw AnalysisPhysicalRealAudioBridgeConsumptionSecureStoreError.injectedFault(.afterPendingMarker)
            }

            if injectedFault == .recordCollision {
                let collisionURL = ledgerURL.appendingPathComponent(relativePath)
                try Data("collision".utf8).write(to: collisionURL, options: .atomic)
                throw AnalysisPhysicalRealAudioBridgeConsumptionSecureStoreError.injectedFault(.recordCollision)
            }

            try writeRecord(record, relativePath: relativePath, ledgerURL: ledgerURL, fileManager: fileManager)
            if injectedFault == .afterRecordWrite {
                throw AnalysisPhysicalRealAudioBridgeConsumptionSecureStoreError.injectedFault(.afterRecordWrite)
            }

            let newHead = try makeHead(previous: oldHead, record: record, relativePath: relativePath)
            try writeControlFile(
                AnalysisPhysicalRealAudioBridgeConsumptionLedgerCodec.encodeHead(newHead),
                to: ledgerURL.appendingPathComponent(AnalysisPhysicalRealAudioBridgeConsumptionLedgerStore.headFileName),
                ledgerURL: ledgerURL,
                maximumBytes: maxHeadBytes,
                fileManager: fileManager
            )
            if injectedFault == .afterHeadWriteBeforePendingRemoval {
                throw AnalysisPhysicalRealAudioBridgeConsumptionSecureStoreError.injectedFault(.afterHeadWriteBeforePendingRemoval)
            }

            try fileManager.removeItem(at: pendingURL)
            if injectedFault == .readBackFailure {
                throw AnalysisPhysicalRealAudioBridgeConsumptionSecureStoreError.injectedFault(.readBackFailure)
            }

            guard let verified = try loadValidatedHead(
                ledgerID: ledgerID,
                rootURL: rootURL,
                fileManager: fileManager
            ), verified == newHead else {
                throw AnalysisPhysicalRealAudioBridgeConsumptionSecureStoreError.readBackFailed
            }
            return verified
        } catch let error as AnalysisPhysicalRealAudioBridgeConsumptionSecureStoreError {
            throw error
        } catch {
            throw AnalysisPhysicalRealAudioBridgeConsumptionSecureStoreError.writeFailed
        }
    }

    private static func loadValidatedHead(
        ledgerID: String,
        rootURL: URL,
        fileManager: FileManager,
        allowedPendingRelativePath: String?
    ) throws -> AnalysisPhysicalRealAudioBridgeConsumptionLedgerHead? {
        guard safeComponent(ledgerID) else { throw AnalysisPhysicalRealAudioBridgeConsumptionSecureStoreError.unsafeLedgerID }
        guard fileManager.fileExists(atPath: rootURL.path) else { return nil }
        try validateDirectory(rootURL, within: rootURL, fileManager: fileManager)

        let parentURL = bridgeConsumptionRootURL(rootURL: rootURL)
        guard fileManager.fileExists(atPath: parentURL.path) else { return nil }
        try validateDirectory(parentURL, within: rootURL, fileManager: fileManager)

        let ledgerURL = ledgerDirectoryURL(ledgerID: ledgerID, rootURL: rootURL)
        guard fileManager.fileExists(atPath: ledgerURL.path) else { return nil }
        try validateLedgerTopology(ledgerURL: ledgerURL, rootURL: rootURL, fileManager: fileManager)

        let recordsURL = ledgerURL.appendingPathComponent("records", isDirectory: true)
        let headURL = ledgerURL.appendingPathComponent(AnalysisPhysicalRealAudioBridgeConsumptionLedgerStore.headFileName)
        guard fileManager.fileExists(atPath: headURL.path) else {
            let observedNames = try recordDirectoryNames(recordsURL: recordsURL, ledgerURL: ledgerURL, fileManager: fileManager)
            let allowedName = allowedPendingRelativePath.map { URL(fileURLWithPath: $0).lastPathComponent }
            let allowed: Set<String> = allowedName.map { [$0] } ?? []
            guard observedNames == allowed || observedNames.isEmpty else {
                throw AnalysisPhysicalRealAudioBridgeConsumptionSecureStoreError.forkedHistory
            }
            return nil
        }

        let head: AnalysisPhysicalRealAudioBridgeConsumptionLedgerHead
        do {
            head = try AnalysisPhysicalRealAudioBridgeConsumptionLedgerCodec.decodeHead(
                readRegularFile(headURL, within: ledgerURL, maximumBytes: maxHeadBytes, fileManager: fileManager)
            )
        } catch let error as AnalysisPhysicalRealAudioBridgeConsumptionSecureStoreError {
            throw error
        } catch {
            throw AnalysisPhysicalRealAudioBridgeConsumptionSecureStoreError.corruptedLedger
        }

        guard head.schemaVersion == 1,
              head.ledgerID == ledgerID,
              !head.records.isEmpty,
              head.records == head.records.sorted(by: { $0.sequence < $1.sequence }),
              head.latestSequence == UInt64(head.records.count),
              head.records.last?.sequence == head.latestSequence,
              head.latestRecordRootSHA256 == head.records.last?.recordRootSHA256,
              isSHA256(head.latestRecordRootSHA256),
              isSHA256(head.declaredLedgerRootSHA256),
              (try? AnalysisPhysicalRealAudioBridgeConsumptionLedgerRoot.compute(
                ledgerID: ledgerID,
                records: head.records
              )) == head.declaredLedgerRootSHA256 else {
            throw AnalysisPhysicalRealAudioBridgeConsumptionSecureStoreError.corruptedLedger
        }
        guard Set(head.records.map(\.bridgeID)).count == head.records.count,
              Set(head.records.map(\.w47PackageRootSHA256)).count == head.records.count,
              Set(head.records.map(\.bridgeCertificateRootSHA256)).count == head.records.count else {
            throw AnalysisPhysicalRealAudioBridgeConsumptionSecureStoreError.forkedHistory
        }

        var previousRoot: String? = nil
        for (index, summary) in head.records.enumerated() {
            guard summary.sequence == UInt64(index + 1),
                  safeComponent(summary.bridgeID),
                  AnalysisPhysicalEvidenceW39BatchLoader.safeRelativePath(summary.relativePath),
                  summary.relativePath.hasPrefix("records/"),
                  isSHA256(summary.bridgeCertificateRootSHA256),
                  isSHA256(summary.w47PackageRootSHA256),
                  isSHA256(summary.w46AdjudicationReportRootSHA256),
                  isSHA256(summary.recordRootSHA256),
                  summary.predecessorRecordRootSHA256 == previousRoot else {
                throw AnalysisPhysicalRealAudioBridgeConsumptionSecureStoreError.corruptedLedger
            }
            let record = try readRecord(relativePath: summary.relativePath, ledgerURL: ledgerURL, fileManager: fileManager)
            guard validateRecord(record),
                  summary.relativePath == recordRelativePath(record),
                  record.sequence == summary.sequence,
                  record.bridgeID == summary.bridgeID,
                  record.bridgeCertificateRootSHA256 == summary.bridgeCertificateRootSHA256,
                  record.w47PackageRootSHA256 == summary.w47PackageRootSHA256,
                  record.w46AdjudicationReportRootSHA256 == summary.w46AdjudicationReportRootSHA256,
                  record.predecessorRecordRootSHA256 == summary.predecessorRecordRootSHA256,
                  record.declaredRecordRootSHA256 == summary.recordRootSHA256 else {
                throw AnalysisPhysicalRealAudioBridgeConsumptionSecureStoreError.corruptedLedger
            }
            previousRoot = summary.recordRootSHA256
        }

        let expectedNames = Set(head.records.map { URL(fileURLWithPath: $0.relativePath).lastPathComponent })
        let allowedName = allowedPendingRelativePath.map { URL(fileURLWithPath: $0).lastPathComponent }
        let observedNames = try recordDirectoryNames(recordsURL: recordsURL, ledgerURL: ledgerURL, fileManager: fileManager)
        let allowedNames = allowedName.map { expectedNames.union([$0]) } ?? expectedNames
        guard observedNames == expectedNames || observedNames == allowedNames else {
            throw AnalysisPhysicalRealAudioBridgeConsumptionSecureStoreError.forkedHistory
        }
        return head
    }

    private static func ensureSecureDirectories(
        ledgerID: String,
        rootURL: URL,
        fileManager: FileManager
    ) throws {
        guard safeComponent(ledgerID) else { throw AnalysisPhysicalRealAudioBridgeConsumptionSecureStoreError.unsafeLedgerID }
        if !fileManager.fileExists(atPath: rootURL.path) {
            try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
        }
        try validateDirectory(rootURL, within: rootURL, fileManager: fileManager)

        let parentURL = bridgeConsumptionRootURL(rootURL: rootURL)
        if !fileManager.fileExists(atPath: parentURL.path) {
            try fileManager.createDirectory(at: parentURL, withIntermediateDirectories: false)
        }
        try validateDirectory(parentURL, within: rootURL, fileManager: fileManager)

        let ledgerURL = ledgerDirectoryURL(ledgerID: ledgerID, rootURL: rootURL)
        if !fileManager.fileExists(atPath: ledgerURL.path) {
            try fileManager.createDirectory(at: ledgerURL, withIntermediateDirectories: false)
        }
        try validateDirectory(ledgerURL, within: rootURL, fileManager: fileManager)

        let recordsURL = ledgerURL.appendingPathComponent("records", isDirectory: true)
        if !fileManager.fileExists(atPath: recordsURL.path) {
            try fileManager.createDirectory(at: recordsURL, withIntermediateDirectories: false)
        }
        try validateDirectory(recordsURL, within: ledgerURL, fileManager: fileManager)
        try validateLedgerTopology(ledgerURL: ledgerURL, rootURL: rootURL, fileManager: fileManager)
    }

    private static func validateLedgerTopology(
        ledgerURL: URL,
        rootURL: URL,
        fileManager: FileManager
    ) throws {
        try validateDirectory(ledgerURL, within: rootURL, fileManager: fileManager)
        let allowed = Set([
            "records",
            AnalysisPhysicalRealAudioBridgeConsumptionLedgerStore.headFileName,
            AnalysisPhysicalRealAudioBridgeConsumptionLedgerStore.pendingFileName
        ])
        let names = try fileManager.contentsOfDirectory(atPath: ledgerURL.path)
        guard names.allSatisfy({ allowed.contains($0) }) else {
            throw AnalysisPhysicalRealAudioBridgeConsumptionSecureStoreError.unsafeFilesystemTopology
        }
        let recordsURL = ledgerURL.appendingPathComponent("records", isDirectory: true)
        if fileManager.fileExists(atPath: recordsURL.path) {
            try validateDirectory(recordsURL, within: ledgerURL, fileManager: fileManager)
        }
    }

    private static func recordDirectoryNames(
        recordsURL: URL,
        ledgerURL: URL,
        fileManager: FileManager
    ) throws -> Set<String> {
        guard fileManager.fileExists(atPath: recordsURL.path) else { return [] }
        try validateDirectory(recordsURL, within: ledgerURL, fileManager: fileManager)
        return Set(try fileManager.contentsOfDirectory(atPath: recordsURL.path))
    }

    private static func validateDirectory(
        _ url: URL,
        within root: URL,
        fileManager: FileManager
    ) throws {
        guard isLexicallyContained(url, within: root) else {
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
        guard isLexicallyContained(resolvedURL, within: resolvedRoot) else {
            throw AnalysisPhysicalRealAudioBridgeConsumptionSecureStoreError.pathOutsideLedgerRoot
        }
    }

    private static func readRegularFile(
        _ url: URL,
        within root: URL,
        maximumBytes: Int,
        fileManager: FileManager
    ) throws -> Data {
        guard isLexicallyContained(url, within: root) else {
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
        guard isLexicallyContained(resolvedURL, within: resolvedRoot) else {
            throw AnalysisPhysicalRealAudioBridgeConsumptionSecureStoreError.pathOutsideLedgerRoot
        }
        let data = try Data(contentsOf: url)
        guard data.count <= maximumBytes else {
            throw AnalysisPhysicalRealAudioBridgeConsumptionSecureStoreError.oversizedFile
        }
        return data
    }

    private static func writeControlFile(
        _ data: Data,
        to url: URL,
        ledgerURL: URL,
        maximumBytes: Int,
        fileManager: FileManager
    ) throws {
        guard data.count <= maximumBytes,
              isLexicallyContained(url, within: ledgerURL) else {
            throw AnalysisPhysicalRealAudioBridgeConsumptionSecureStoreError.oversizedFile
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
        try data.write(to: url, options: .atomic)
        _ = try readRegularFile(url, within: ledgerURL, maximumBytes: maximumBytes, fileManager: fileManager)
    }

    private static func writeRecord(
        _ record: AnalysisPhysicalRealAudioBridgeConsumptionRecord,
        relativePath: String,
        ledgerURL: URL,
        fileManager: FileManager
    ) throws {
        guard AnalysisPhysicalEvidenceW39BatchLoader.safeRelativePath(relativePath),
              relativePath == recordRelativePath(record),
              relativePath.hasPrefix("records/") else {
            throw AnalysisPhysicalRealAudioBridgeConsumptionSecureStoreError.pathOutsideLedgerRoot
        }
        let url = ledgerURL.appendingPathComponent(relativePath)
        guard isLexicallyContained(url, within: ledgerURL) else {
            throw AnalysisPhysicalRealAudioBridgeConsumptionSecureStoreError.pathOutsideLedgerRoot
        }
        guard !fileManager.fileExists(atPath: url.path) else {
            throw AnalysisPhysicalRealAudioBridgeConsumptionSecureStoreError.existingRecordCollision
        }
        let bytes = try AnalysisPhysicalRealAudioBridgeConsumptionLedgerCodec.encodeRecord(record)
        guard bytes.count <= maxRecordBytes else {
            throw AnalysisPhysicalRealAudioBridgeConsumptionSecureStoreError.oversizedFile
        }
        try bytes.write(to: url, options: .atomic)
        guard try readRecord(relativePath: relativePath, ledgerURL: ledgerURL, fileManager: fileManager) == record else {
            throw AnalysisPhysicalRealAudioBridgeConsumptionSecureStoreError.readBackFailed
        }
    }

    private static func readRecord(
        relativePath: String,
        ledgerURL: URL,
        fileManager: FileManager
    ) throws -> AnalysisPhysicalRealAudioBridgeConsumptionRecord {
        guard AnalysisPhysicalEvidenceW39BatchLoader.safeRelativePath(relativePath),
              relativePath.hasPrefix("records/") else {
            throw AnalysisPhysicalRealAudioBridgeConsumptionSecureStoreError.pathOutsideLedgerRoot
        }
        let url = ledgerURL.appendingPathComponent(relativePath)
        do {
            return try AnalysisPhysicalRealAudioBridgeConsumptionLedgerCodec.decodeRecord(
                readRegularFile(url, within: ledgerURL, maximumBytes: maxRecordBytes, fileManager: fileManager)
            )
        } catch let error as AnalysisPhysicalRealAudioBridgeConsumptionSecureStoreError {
            throw error
        } catch {
            throw AnalysisPhysicalRealAudioBridgeConsumptionSecureStoreError.corruptedLedger
        }
    }

    private static func makeHead(
        previous: AnalysisPhysicalRealAudioBridgeConsumptionLedgerHead?,
        record: AnalysisPhysicalRealAudioBridgeConsumptionRecord,
        relativePath: String
    ) throws -> AnalysisPhysicalRealAudioBridgeConsumptionLedgerHead {
        let summary = AnalysisPhysicalRealAudioBridgeConsumptionRecordSummary(
            sequence: record.sequence,
            relativePath: relativePath,
            bridgeID: record.bridgeID,
            bridgeCertificateRootSHA256: record.bridgeCertificateRootSHA256,
            w47PackageRootSHA256: record.w47PackageRootSHA256,
            w46AdjudicationReportRootSHA256: record.w46AdjudicationReportRootSHA256,
            predecessorRecordRootSHA256: record.predecessorRecordRootSHA256,
            recordRootSHA256: record.declaredRecordRootSHA256
        )
        let records = (previous?.records ?? []) + [summary]
        let root = try AnalysisPhysicalRealAudioBridgeConsumptionLedgerRoot.compute(
            ledgerID: record.ledgerID,
            records: records
        )
        return .init(
            ledgerID: record.ledgerID,
            records: records,
            latestSequence: record.sequence,
            latestRecordRootSHA256: record.declaredRecordRootSHA256,
            declaredLedgerRootSHA256: root
        )
    }

    private static func recordRelativePath(_ record: AnalysisPhysicalRealAudioBridgeConsumptionRecord) -> String {
        String(format: "records/%012llu-%@.json", record.sequence, record.declaredRecordRootSHA256)
    }

    private static func bridgeConsumptionRootURL(rootURL: URL) -> URL {
        rootURL.appendingPathComponent("w49-bridge-consumption", isDirectory: true)
    }

    private static func ledgerDirectoryURL(ledgerID: String, rootURL: URL) -> URL {
        bridgeConsumptionRootURL(rootURL: rootURL).appendingPathComponent(ledgerID, isDirectory: true)
    }

    private static func validateRecord(_ value: AnalysisPhysicalRealAudioBridgeConsumptionRecord) -> Bool {
        AnalysisPhysicalRealAudioBridgeConsumptionLedgerStore.validateRecord(value)
    }

    private static func safeComponent(_ value: String) -> Bool {
        AnalysisPhysicalEvidenceW39BatchLoader.safeComponent(value)
    }

    private static func isSHA256(_ value: String) -> Bool {
        AnalysisPhysicalEvidenceW39BatchLoader.isSHA256(value)
    }

    private static func isLexicallyContained(_ url: URL, within root: URL) -> Bool {
        let rootPath = root.standardizedFileURL.path
        let targetPath = url.standardizedFileURL.path
        if targetPath == rootPath { return true }
        let prefix = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"
        return targetPath.hasPrefix(prefix)
    }
}

public enum AnalysisPhysicalRealAudioBridgeConsumptionSecureCheckpointManager {
    public static func makeStrictCheckpoint(
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

    public static func verifyCurrentLedgerStrict(
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

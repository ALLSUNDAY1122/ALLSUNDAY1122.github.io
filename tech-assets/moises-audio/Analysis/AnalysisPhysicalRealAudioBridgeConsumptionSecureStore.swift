import Foundation

public enum AnalysisPhysicalRealAudioBridgeConsumptionSecureStore {
    public static let limitations = [
        "NON_PARITY: W50-W53 harden bridge-consumption custody, filesystem safety and crash-durable publication; they do not promote any Analysis PARITY row.",
        "W53 publishes pending/head through synced same-directory temporary files and atomic rename, publishes immutable records with collision-safe exclusive linking, and syncs the parent directory before durability is claimed.",
        "Darwin attempts F_FULLFSYNC and falls back to fsync if unavailable; the exact sync mode must be captured on the selected physical iPhone before APFS/power-loss durability is claimed.",
        "Whole-ledger rollback remains externally authoritative only when HQ independently retains the latest checkpoint/handoff/receipt root outside the mutable ledger directory."
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
            injectedFault: nil,
            durablePublicationFault: nil
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
            injectedFault: injectedFault,
            durablePublicationFault: nil
        )
    }

    @discardableResult
    static func appendDurabilityForTesting(
        ledgerID: String,
        certificate: AnalysisPhysicalRealAudioParityBridgeCertificate,
        custody: AnalysisPhysicalRealAudioBridgeConsumptionCustody,
        rootURL: URL,
        fileManager: FileManager = .default,
        durablePublicationFault: AnalysisPhysicalRealAudioBridgeConsumptionDurablePublicationInjectedFault
    ) throws -> AnalysisPhysicalRealAudioBridgeConsumptionLedgerHead {
        try appendInternal(
            ledgerID: ledgerID,
            certificate: certificate,
            custody: custody,
            rootURL: rootURL,
            fileManager: fileManager,
            injectedFault: nil,
            durablePublicationFault: durablePublicationFault
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
        guard safeComponent(ledgerID) else {
            throw AnalysisPhysicalRealAudioBridgeConsumptionSecureStoreError.unsafeLedgerID
        }
        guard fileManager.fileExists(atPath: rootURL.path) else { return false }
        try FS.validateDirectory(rootURL, within: rootURL)

        let bridgeRoot = FS.bridgeRootURL(rootURL: rootURL)
        guard fileManager.fileExists(atPath: bridgeRoot.path) else { return false }
        try FS.validateDirectory(bridgeRoot, within: rootURL)

        let ledgerURL = FS.ledgerURL(ledgerID: ledgerID, rootURL: rootURL)
        guard fileManager.fileExists(atPath: ledgerURL.path) else { return false }
        try FS.validateLedgerTopology(ledgerURL: ledgerURL, rootURL: rootURL, fileManager: fileManager)

        let pendingURL = ledgerURL.appendingPathComponent(AnalysisPhysicalRealAudioBridgeConsumptionLedgerStore.pendingFileName)
        guard fileManager.fileExists(atPath: pendingURL.path) else {
            _ = try loadValidatedHead(ledgerID: ledgerID, rootURL: rootURL, fileManager: fileManager)
            return false
        }

        let pending: AnalysisPhysicalRealAudioBridgeConsumptionPendingAppend
        do {
            pending = try AnalysisPhysicalRealAudioBridgeConsumptionLedgerCodec.decodePending(
                FS.readRegularFile(pendingURL, within: ledgerURL, maximumBytes: FS.maxPendingBytes)
            )
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
              pending.candidateRelativePath == FS.recordRelativePath(pending.candidateRecord),
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
                    ledgerURL: ledgerURL
                  ) == pending.candidateRecord else {
                throw AnalysisPhysicalRealAudioBridgeConsumptionSecureStoreError.ambiguousRecoveryState
            }
            try AnalysisPhysicalRealAudioBridgeConsumptionDurablePublication.removeDurably(
                pendingURL,
                within: ledgerURL
            )
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
            try AnalysisPhysicalRealAudioBridgeConsumptionDurablePublication.removeDurably(
                pendingURL,
                within: ledgerURL
            )
            _ = try loadValidatedHead(ledgerID: ledgerID, rootURL: rootURL, fileManager: fileManager)
            return true
        }

        guard try readRecord(relativePath: pending.candidateRelativePath, ledgerURL: ledgerURL) == pending.candidateRecord else {
            throw AnalysisPhysicalRealAudioBridgeConsumptionSecureStoreError.ambiguousRecoveryState
        }
        let repaired = try makeHead(previous: head, record: pending.candidateRecord, relativePath: pending.candidateRelativePath)
        try FS.writeControlFile(
            try AnalysisPhysicalRealAudioBridgeConsumptionLedgerCodec.encodeHead(repaired),
            to: ledgerURL.appendingPathComponent(AnalysisPhysicalRealAudioBridgeConsumptionLedgerStore.headFileName),
            ledgerURL: ledgerURL,
            maximumBytes: FS.maxHeadBytes,
            fileManager: fileManager
        )
        try AnalysisPhysicalRealAudioBridgeConsumptionDurablePublication.removeDurably(
            pendingURL,
            within: ledgerURL
        )
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
        injectedFault: AnalysisPhysicalRealAudioBridgeConsumptionInjectedFault?,
        durablePublicationFault: AnalysisPhysicalRealAudioBridgeConsumptionDurablePublicationInjectedFault?
    ) throws -> AnalysisPhysicalRealAudioBridgeConsumptionLedgerHead {
        guard safeComponent(ledgerID) else {
            throw AnalysisPhysicalRealAudioBridgeConsumptionSecureStoreError.unsafeLedgerID
        }
        guard AnalysisPhysicalRealAudioBridgeConsumptionLedgerStore.validateCustody(custody) else {
            throw AnalysisPhysicalRealAudioBridgeConsumptionSecureStoreError.invalidCustody
        }
        guard AnalysisPhysicalRealAudioParityBridgeCertificateValidator.validate(certificate) else {
            throw AnalysisPhysicalRealAudioBridgeConsumptionSecureStoreError.invalidBridgeCertificate
        }

        try FS.ensureDirectories(ledgerID: ledgerID, rootURL: rootURL, fileManager: fileManager)
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
        let relativePath = FS.recordRelativePath(record)
        let ledgerURL = FS.ledgerURL(ledgerID: ledgerID, rootURL: rootURL)
        let pendingURL = ledgerURL.appendingPathComponent(AnalysisPhysicalRealAudioBridgeConsumptionLedgerStore.pendingFileName)
        let pending = AnalysisPhysicalRealAudioBridgeConsumptionPendingAppend(
            ledgerID: ledgerID,
            candidateRecord: record,
            candidateRelativePath: relativePath,
            previousLedgerRootSHA256: oldHead?.declaredLedgerRootSHA256,
            previousLatestRecordRootSHA256: oldHead?.latestRecordRootSHA256
        )

        do {
            _ = try FS.writeControlFileDurably(
                try AnalysisPhysicalRealAudioBridgeConsumptionLedgerCodec.encodePending(pending),
                to: pendingURL,
                ledgerURL: ledgerURL,
                maximumBytes: FS.maxPendingBytes,
                target: .pendingMarker,
                fileManager: fileManager,
                injectedFault: fault(for: .pendingMarker, from: durablePublicationFault)
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

            try writeRecord(
                record,
                relativePath: relativePath,
                ledgerURL: ledgerURL,
                fileManager: fileManager,
                durablePublicationFault: fault(for: .immutableRecord, from: durablePublicationFault)
            )
            if injectedFault == .afterRecordWrite {
                throw AnalysisPhysicalRealAudioBridgeConsumptionSecureStoreError.injectedFault(.afterRecordWrite)
            }

            let newHead = try makeHead(previous: oldHead, record: record, relativePath: relativePath)
            _ = try FS.writeControlFileDurably(
                try AnalysisPhysicalRealAudioBridgeConsumptionLedgerCodec.encodeHead(newHead),
                to: ledgerURL.appendingPathComponent(AnalysisPhysicalRealAudioBridgeConsumptionLedgerStore.headFileName),
                ledgerURL: ledgerURL,
                maximumBytes: FS.maxHeadBytes,
                target: .ledgerHead,
                fileManager: fileManager,
                injectedFault: fault(for: .ledgerHead, from: durablePublicationFault)
            )
            if injectedFault == .afterHeadWriteBeforePendingRemoval {
                throw AnalysisPhysicalRealAudioBridgeConsumptionSecureStoreError.injectedFault(.afterHeadWriteBeforePendingRemoval)
            }

            try AnalysisPhysicalRealAudioBridgeConsumptionDurablePublication.removeDurably(
                pendingURL,
                within: ledgerURL
            )
            if injectedFault == .readBackFailure {
                throw AnalysisPhysicalRealAudioBridgeConsumptionSecureStoreError.injectedFault(.readBackFailure)
            }
            guard let verified = try loadValidatedHead(ledgerID: ledgerID, rootURL: rootURL, fileManager: fileManager),
                  verified == newHead else {
                throw AnalysisPhysicalRealAudioBridgeConsumptionSecureStoreError.readBackFailed
            }
            return verified
        } catch let error as AnalysisPhysicalRealAudioBridgeConsumptionSecureStoreError {
            throw error
        } catch let error as AnalysisPhysicalRealAudioBridgeConsumptionDurablePublicationError {
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
        guard safeComponent(ledgerID) else {
            throw AnalysisPhysicalRealAudioBridgeConsumptionSecureStoreError.unsafeLedgerID
        }
        guard fileManager.fileExists(atPath: rootURL.path) else { return nil }
        try FS.validateDirectory(rootURL, within: rootURL)
        let bridgeRoot = FS.bridgeRootURL(rootURL: rootURL)
        guard fileManager.fileExists(atPath: bridgeRoot.path) else { return nil }
        try FS.validateDirectory(bridgeRoot, within: rootURL)
        let ledgerURL = FS.ledgerURL(ledgerID: ledgerID, rootURL: rootURL)
        guard fileManager.fileExists(atPath: ledgerURL.path) else { return nil }
        try FS.validateLedgerTopology(ledgerURL: ledgerURL, rootURL: rootURL, fileManager: fileManager)

        let recordsURL = ledgerURL.appendingPathComponent("records", isDirectory: true)
        let headURL = ledgerURL.appendingPathComponent(AnalysisPhysicalRealAudioBridgeConsumptionLedgerStore.headFileName)
        guard fileManager.fileExists(atPath: headURL.path) else {
            let observed = try FS.recordDirectoryNames(recordsURL: recordsURL, ledgerURL: ledgerURL, fileManager: fileManager)
            let allowedName = allowedPendingRelativePath.map { URL(fileURLWithPath: $0).lastPathComponent }
            let allowed: Set<String> = allowedName.map { Set([$0]) } ?? Set()
            guard observed == allowed || observed.isEmpty else {
                throw AnalysisPhysicalRealAudioBridgeConsumptionSecureStoreError.forkedHistory
            }
            return nil
        }

        let head: AnalysisPhysicalRealAudioBridgeConsumptionLedgerHead
        do {
            head = try AnalysisPhysicalRealAudioBridgeConsumptionLedgerCodec.decodeHead(
                FS.readRegularFile(headURL, within: ledgerURL, maximumBytes: FS.maxHeadBytes)
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
              (try? AnalysisPhysicalRealAudioBridgeConsumptionLedgerRoot.compute(ledgerID: ledgerID, records: head.records)) == head.declaredLedgerRootSHA256 else {
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
            let record = try readRecord(relativePath: summary.relativePath, ledgerURL: ledgerURL)
            guard validateRecord(record),
                  summary.relativePath == FS.recordRelativePath(record),
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

        let expected = Set(head.records.map { URL(fileURLWithPath: $0.relativePath).lastPathComponent })
        let allowedName = allowedPendingRelativePath.map { URL(fileURLWithPath: $0).lastPathComponent }
        let allowed = allowedName.map { expected.union([$0]) } ?? expected
        let observed = try FS.recordDirectoryNames(recordsURL: recordsURL, ledgerURL: ledgerURL, fileManager: fileManager)
        guard observed == expected || observed == allowed else {
            throw AnalysisPhysicalRealAudioBridgeConsumptionSecureStoreError.forkedHistory
        }
        return head
    }

    private static func writeRecord(
        _ record: AnalysisPhysicalRealAudioBridgeConsumptionRecord,
        relativePath: String,
        ledgerURL: URL,
        fileManager: FileManager,
        durablePublicationFault: AnalysisPhysicalRealAudioBridgeConsumptionDurablePublicationInjectedFault?
    ) throws {
        guard AnalysisPhysicalEvidenceW39BatchLoader.safeRelativePath(relativePath),
              relativePath.hasPrefix("records/"),
              relativePath == FS.recordRelativePath(record) else {
            throw AnalysisPhysicalRealAudioBridgeConsumptionSecureStoreError.pathOutsideLedgerRoot
        }
        let url = ledgerURL.appendingPathComponent(relativePath)
        guard FS.lexicallyContained(url, within: ledgerURL) else {
            throw AnalysisPhysicalRealAudioBridgeConsumptionSecureStoreError.pathOutsideLedgerRoot
        }
        guard !fileManager.fileExists(atPath: url.path) else {
            throw AnalysisPhysicalRealAudioBridgeConsumptionSecureStoreError.existingRecordCollision
        }
        let bytes = try AnalysisPhysicalRealAudioBridgeConsumptionLedgerCodec.encodeRecord(record)
        guard bytes.count <= FS.maxRecordBytes else {
            throw AnalysisPhysicalRealAudioBridgeConsumptionSecureStoreError.oversizedFile
        }
        _ = try AnalysisPhysicalRealAudioBridgeConsumptionDurablePublication.createExclusive(
            bytes,
            at: url,
            within: ledgerURL,
            maximumBytes: FS.maxRecordBytes,
            target: .immutableRecord,
            injectedFault: durablePublicationFault
        )
        guard try readRecord(relativePath: relativePath, ledgerURL: ledgerURL) == record else {
            throw AnalysisPhysicalRealAudioBridgeConsumptionSecureStoreError.readBackFailed
        }
    }

    private static func readRecord(
        relativePath: String,
        ledgerURL: URL
    ) throws -> AnalysisPhysicalRealAudioBridgeConsumptionRecord {
        guard AnalysisPhysicalEvidenceW39BatchLoader.safeRelativePath(relativePath),
              relativePath.hasPrefix("records/") else {
            throw AnalysisPhysicalRealAudioBridgeConsumptionSecureStoreError.pathOutsideLedgerRoot
        }
        do {
            return try AnalysisPhysicalRealAudioBridgeConsumptionLedgerCodec.decodeRecord(
                FS.readRegularFile(
                    ledgerURL.appendingPathComponent(relativePath),
                    within: ledgerURL,
                    maximumBytes: FS.maxRecordBytes
                )
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
        return .init(
            ledgerID: record.ledgerID,
            records: records,
            latestSequence: record.sequence,
            latestRecordRootSHA256: record.declaredRecordRootSHA256,
            declaredLedgerRootSHA256: try AnalysisPhysicalRealAudioBridgeConsumptionLedgerRoot.compute(
                ledgerID: record.ledgerID,
                records: records
            )
        )
    }

    private static func fault(
        for target: AnalysisPhysicalRealAudioBridgeConsumptionDurablePublicationTarget,
        from injection: AnalysisPhysicalRealAudioBridgeConsumptionDurablePublicationInjectedFault?
    ) -> AnalysisPhysicalRealAudioBridgeConsumptionDurablePublicationInjectedFault? {
        guard let injection, injection.target == target else { return nil }
        return injection
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

    private typealias FS = AnalysisPhysicalRealAudioBridgeConsumptionSecureFilesystem
}

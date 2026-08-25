import Foundation

public enum AnalysisPhysicalEvidenceAnchorLedgerRecordRoot {
    private struct Payload: Codable {
        let schemaVersion: Int
        let ledgerID: String
        let anchorID: String
        let sequence: UInt64
        let anchorReceiptRootSHA256: String
        let certificateRootSHA256: String
        let predecessorLedgerRecordRootSHA256: String?
    }

    public static func compute(_ record: AnalysisPhysicalEvidenceAnchorLedgerRecord) throws -> String {
        let payload = Payload(
            schemaVersion: record.schemaVersion,
            ledgerID: record.ledgerID,
            anchorID: record.anchorID,
            sequence: record.sequence,
            anchorReceiptRootSHA256: record.anchorReceiptRootSHA256.lowercased(),
            certificateRootSHA256: record.certificateRootSHA256.lowercased(),
            predecessorLedgerRecordRootSHA256: record.predecessorLedgerRecordRootSHA256?.lowercased()
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return AnalysisDeviceWorkloadSHA256.hexDigest(try encoder.encode(payload))
    }
}

public enum AnalysisPhysicalEvidenceAnchorLedgerRoot {
    private struct Payload: Codable {
        let schemaVersion: Int
        let ledgerID: String
        let anchorID: String
        let records: [AnalysisPhysicalEvidenceAnchorLedgerRecordSummary]
    }

    public static func compute(
        ledgerID: String,
        anchorID: String,
        records: [AnalysisPhysicalEvidenceAnchorLedgerRecordSummary]
    ) throws -> String {
        let payload = Payload(
            schemaVersion: 1,
            ledgerID: ledgerID,
            anchorID: anchorID,
            records: records.sorted { $0.sequence < $1.sequence }
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return AnalysisDeviceWorkloadSHA256.hexDigest(try encoder.encode(payload))
    }
}

public enum AnalysisPhysicalEvidenceAnchorLedgerCodec {
    private static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return encoder
    }

    public static func encodeRecord(_ value: AnalysisPhysicalEvidenceAnchorLedgerRecord) throws -> Data {
        try encoder().encode(value)
    }

    public static func decodeRecord(_ data: Data) throws -> AnalysisPhysicalEvidenceAnchorLedgerRecord {
        try JSONDecoder().decode(AnalysisPhysicalEvidenceAnchorLedgerRecord.self, from: data)
    }

    public static func encodeHead(_ value: AnalysisPhysicalEvidenceAnchorLedgerHead) throws -> Data {
        try encoder().encode(value)
    }

    public static func decodeHead(_ data: Data) throws -> AnalysisPhysicalEvidenceAnchorLedgerHead {
        try JSONDecoder().decode(AnalysisPhysicalEvidenceAnchorLedgerHead.self, from: data)
    }

    public static func encodePending(_ value: AnalysisPhysicalEvidenceAnchorLedgerPendingAppend) throws -> Data {
        try encoder().encode(value)
    }

    public static func decodePending(_ data: Data) throws -> AnalysisPhysicalEvidenceAnchorLedgerPendingAppend {
        try JSONDecoder().decode(AnalysisPhysicalEvidenceAnchorLedgerPendingAppend.self, from: data)
    }

    public static func encodeSnapshot(_ value: AnalysisPhysicalEvidenceAnchorLedgerSnapshot) throws -> Data {
        try encoder().encode(value)
    }
}

public enum AnalysisPhysicalEvidenceAnchorLedgerPairValidator {
    public static func validate(
        receipt: AnalysisPhysicalEvidenceAnchorReceipt,
        certificate: AnalysisPhysicalEvidenceDestinationVerificationCertificate
    ) -> Bool {
        guard receipt.schemaVersion == 1,
              AnalysisPhysicalEvidenceAnchorReceiptIssuer.validateAnchor(receipt.anchor),
              AnalysisPhysicalEvidenceW39BatchLoader.isSHA256(receipt.declaredAnchorReceiptRootSHA256),
              (try? AnalysisPhysicalEvidenceAnchorReceiptRoot.compute(receipt.anchor)) == receipt.declaredAnchorReceiptRootSHA256.lowercased(),
              certificate.schemaVersion == 1,
              certificate.status == .verifiedAgainstExternalAnchorNonParity,
              certificate.anchorID == receipt.anchor.anchorID,
              certificate.anchorSequence == receipt.anchor.anchorSequence,
              certificate.anchorReceiptRootSHA256 == receipt.declaredAnchorReceiptRootSHA256.lowercased(),
              certificate.publicationID == receipt.anchor.publicationID,
              certificate.transferID == receipt.anchor.transferID,
              certificate.expectedW27RootSHA256 == receipt.anchor.w27RootSHA256,
              certificate.expectedW38RootSHA256 == receipt.anchor.w38RootSHA256,
              certificate.expectedW40RootSHA256 == receipt.anchor.w40RootSHA256,
              certificate.expectedW41RootSHA256 == receipt.anchor.w41RootSHA256,
              certificate.destinationW27RootSHA256 == receipt.anchor.w27RootSHA256,
              certificate.destinationW38RootSHA256 == receipt.anchor.w38RootSHA256,
              certificate.destinationW40RootSHA256 == receipt.anchor.w40RootSHA256,
              certificate.destinationW41RootSHA256 == receipt.anchor.w41RootSHA256,
              certificate.runs == receipt.anchor.runs,
              certificate.limitations == AnalysisPhysicalEvidenceDestinationAnchorVerifier.limitations,
              AnalysisPhysicalEvidenceW39BatchLoader.isSHA256(certificate.declaredCertificateRootSHA256),
              (try? AnalysisPhysicalEvidenceDestinationCertificateRoot.compute(certificate)) == certificate.declaredCertificateRootSHA256.lowercased() else {
            return false
        }
        return true
    }
}

public enum AnalysisPhysicalEvidenceAnchorLedgerStore {
    public static let headFileName = "W43_LEDGER_HEAD.json"
    public static let pendingFileName = ".W43_PENDING.json"
    public static let limitations = [
        "NON_PARITY: the local W43 ledger records integrity-verification continuity; it does not establish product parity.",
        "The ledger is a local SHA-256 hash chain, not a signature, trusted timestamp, Secure Enclave proof or Apple attestation.",
        "Rollback resistance is authoritative only when HQ independently preserves or signs the latest ledger root outside this local ledger.",
        "Foundation atomic file replacement reduces partial-write risk but does not prove APFS/device durability without physical-device execution and crash testing."
    ]

    @discardableResult
    public static func append(
        ledgerID: String,
        anchorReceipt: AnalysisPhysicalEvidenceAnchorReceipt,
        destinationCertificate: AnalysisPhysicalEvidenceDestinationVerificationCertificate,
        rootURL: URL,
        fileManager: FileManager = .default
    ) throws -> AnalysisPhysicalEvidenceAnchorLedgerAppendReceipt {
        guard AnalysisPhysicalEvidenceW39BatchLoader.safeComponent(ledgerID) else {
            throw AnalysisPhysicalEvidenceAnchorLedgerError.unsafeLedgerID
        }
        guard AnalysisPhysicalEvidenceAnchorLedgerPairValidator.validate(
            receipt: anchorReceipt,
            certificate: destinationCertificate
        ) else {
            throw AnalysisPhysicalEvidenceAnchorLedgerError.invalidReceiptOrCertificate
        }

        let ledgerURL = ledgerDirectoryURL(ledgerID: ledgerID, rootURL: rootURL)
        let recovered = try recoverIfNeeded(ledgerID: ledgerID, rootURL: rootURL, fileManager: fileManager)
        let head = try loadValidatedHead(ledgerID: ledgerID, rootURL: rootURL, fileManager: fileManager)
        let sequence = anchorReceipt.anchor.anchorSequence

        if let head {
            guard head.anchorID == anchorReceipt.anchor.anchorID else {
                throw AnalysisPhysicalEvidenceAnchorLedgerError.ledgerAnchorMismatch
            }
            if sequence < head.latestSequence {
                throw AnalysisPhysicalEvidenceAnchorLedgerError.rollbackImport
            }
            if sequence == head.latestSequence {
                guard let latest = head.records.last else {
                    throw AnalysisPhysicalEvidenceAnchorLedgerError.corruptedLedger
                }
                let existing = try readRecord(relativePath: latest.relativePath, ledgerURL: ledgerURL, fileManager: fileManager)
                let candidate = try makeRecord(
                    ledgerID: ledgerID,
                    anchorReceipt: anchorReceipt,
                    destinationCertificate: destinationCertificate,
                    predecessorLedgerRecordRootSHA256: existing.predecessorLedgerRecordRootSHA256
                )
                guard existing == candidate else {
                    throw AnalysisPhysicalEvidenceAnchorLedgerError.sequenceReuseDifferentRoots
                }
                return makeAppendReceipt(status: .exactDuplicateAccepted, record: existing, ledgerRoot: head.declaredLedgerRootSHA256)
            }
            guard sequence == head.latestSequence + 1 else {
                throw AnalysisPhysicalEvidenceAnchorLedgerError.sequenceGap
            }
            guard anchorReceipt.anchor.predecessorAnchorReceiptRootSHA256 == head.latestAnchorReceiptRootSHA256 else {
                throw AnalysisPhysicalEvidenceAnchorLedgerError.predecessorReceiptMismatch
            }
        } else {
            guard sequence == 1 else {
                throw AnalysisPhysicalEvidenceAnchorLedgerError.sequenceGap
            }
            guard anchorReceipt.anchor.predecessorAnchorReceiptRootSHA256 == nil else {
                throw AnalysisPhysicalEvidenceAnchorLedgerError.predecessorReceiptMismatch
            }
        }

        try fileManager.createDirectory(at: ledgerURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: ledgerURL.appendingPathComponent("records", isDirectory: true), withIntermediateDirectories: true)

        let record = try makeRecord(
            ledgerID: ledgerID,
            anchorReceipt: anchorReceipt,
            destinationCertificate: destinationCertificate,
            predecessorLedgerRecordRootSHA256: head?.latestRecordRootSHA256
        )
        let relativePath = recordRelativePath(record)
        let pending = AnalysisPhysicalEvidenceAnchorLedgerPendingAppend(
            ledgerID: ledgerID,
            candidateRecord: record,
            candidateRelativePath: relativePath,
            previousLedgerRootSHA256: head?.declaredLedgerRootSHA256,
            previousLatestRecordRootSHA256: head?.latestRecordRootSHA256
        )
        do {
            try AnalysisPhysicalEvidenceAnchorLedgerCodec.encodePending(pending).write(
                to: ledgerURL.appendingPathComponent(pendingFileName), options: .atomic
            )
            try writeRecord(record, relativePath: relativePath, ledgerURL: ledgerURL, fileManager: fileManager)
            let newHead = try makeHead(previous: head, record: record, relativePath: relativePath)
            try AnalysisPhysicalEvidenceAnchorLedgerCodec.encodeHead(newHead).write(
                to: ledgerURL.appendingPathComponent(headFileName), options: .atomic
            )
            try fileManager.removeItem(at: ledgerURL.appendingPathComponent(pendingFileName))
            guard let verified = try loadValidatedHead(ledgerID: ledgerID, rootURL: rootURL, fileManager: fileManager),
                  verified == newHead else {
                throw AnalysisPhysicalEvidenceAnchorLedgerError.readBackFailed
            }
            return makeAppendReceipt(
                status: recovered ? .recoveredInterruptedAppend : .appended,
                record: record,
                ledgerRoot: verified.declaredLedgerRootSHA256
            )
        } catch let error as AnalysisPhysicalEvidenceAnchorLedgerError {
            throw error
        } catch {
            throw AnalysisPhysicalEvidenceAnchorLedgerError.writeFailed
        }
    }

    public static func exportSnapshot(
        ledgerID: String,
        rootURL: URL,
        fileManager: FileManager = .default
    ) throws -> AnalysisPhysicalEvidenceAnchorLedgerSnapshot {
        guard AnalysisPhysicalEvidenceW39BatchLoader.safeComponent(ledgerID) else {
            throw AnalysisPhysicalEvidenceAnchorLedgerError.unsafeLedgerID
        }
        _ = try recoverIfNeeded(ledgerID: ledgerID, rootURL: rootURL, fileManager: fileManager)
        guard let head = try loadValidatedHead(ledgerID: ledgerID, rootURL: rootURL, fileManager: fileManager) else {
            throw AnalysisPhysicalEvidenceAnchorLedgerError.corruptedLedger
        }
        return .init(
            ledgerID: head.ledgerID,
            anchorID: head.anchorID,
            records: head.records,
            declaredLedgerRootSHA256: head.declaredLedgerRootSHA256,
            limitations: limitations
        )
    }

    public static func createInterruptedAppendCheckpoint(
        ledgerID: String,
        anchorReceipt: AnalysisPhysicalEvidenceAnchorReceipt,
        destinationCertificate: AnalysisPhysicalEvidenceDestinationVerificationCertificate,
        checkpoint: AnalysisPhysicalEvidenceAnchorLedgerInterruptedCheckpoint,
        rootURL: URL,
        fileManager: FileManager = .default
    ) throws {
        guard AnalysisPhysicalEvidenceW39BatchLoader.safeComponent(ledgerID),
              AnalysisPhysicalEvidenceAnchorLedgerPairValidator.validate(
                receipt: anchorReceipt,
                certificate: destinationCertificate
              ) else {
            throw AnalysisPhysicalEvidenceAnchorLedgerError.invalidReceiptOrCertificate
        }
        _ = try recoverIfNeeded(ledgerID: ledgerID, rootURL: rootURL, fileManager: fileManager)
        let head = try loadValidatedHead(ledgerID: ledgerID, rootURL: rootURL, fileManager: fileManager)
        let sequence = anchorReceipt.anchor.anchorSequence
        if let head {
            guard head.anchorID == anchorReceipt.anchor.anchorID,
                  sequence == head.latestSequence + 1,
                  anchorReceipt.anchor.predecessorAnchorReceiptRootSHA256 == head.latestAnchorReceiptRootSHA256 else {
                throw AnalysisPhysicalEvidenceAnchorLedgerError.predecessorReceiptMismatch
            }
        } else {
            guard sequence == 1, anchorReceipt.anchor.predecessorAnchorReceiptRootSHA256 == nil else {
                throw AnalysisPhysicalEvidenceAnchorLedgerError.sequenceGap
            }
        }

        let ledgerURL = ledgerDirectoryURL(ledgerID: ledgerID, rootURL: rootURL)
        try fileManager.createDirectory(at: ledgerURL.appendingPathComponent("records", isDirectory: true), withIntermediateDirectories: true)
        let record = try makeRecord(
            ledgerID: ledgerID,
            anchorReceipt: anchorReceipt,
            destinationCertificate: destinationCertificate,
            predecessorLedgerRecordRootSHA256: head?.latestRecordRootSHA256
        )
        let path = recordRelativePath(record)
        let pending = AnalysisPhysicalEvidenceAnchorLedgerPendingAppend(
            ledgerID: ledgerID,
            candidateRecord: record,
            candidateRelativePath: path,
            previousLedgerRootSHA256: head?.declaredLedgerRootSHA256,
            previousLatestRecordRootSHA256: head?.latestRecordRootSHA256
        )
        try AnalysisPhysicalEvidenceAnchorLedgerCodec.encodePending(pending).write(
            to: ledgerURL.appendingPathComponent(pendingFileName), options: .atomic
        )
        if checkpoint == .recordWrittenBeforeHead {
            try writeRecord(record, relativePath: path, ledgerURL: ledgerURL, fileManager: fileManager)
        }
    }

    @discardableResult
    public static func recoverIfNeeded(
        ledgerID: String,
        rootURL: URL,
        fileManager: FileManager = .default
    ) throws -> Bool {
        guard AnalysisPhysicalEvidenceW39BatchLoader.safeComponent(ledgerID) else {
            throw AnalysisPhysicalEvidenceAnchorLedgerError.unsafeLedgerID
        }
        let ledgerURL = ledgerDirectoryURL(ledgerID: ledgerID, rootURL: rootURL)
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: ledgerURL.path, isDirectory: &isDirectory) else { return false }
        guard isDirectory.boolValue else { throw AnalysisPhysicalEvidenceAnchorLedgerError.corruptedLedger }

        let pendingURL = ledgerURL.appendingPathComponent(pendingFileName)
        guard fileManager.fileExists(atPath: pendingURL.path) else {
            _ = try loadValidatedHead(ledgerID: ledgerID, rootURL: rootURL, fileManager: fileManager)
            return false
        }
        let pending: AnalysisPhysicalEvidenceAnchorLedgerPendingAppend
        do {
            pending = try AnalysisPhysicalEvidenceAnchorLedgerCodec.decodePending(
                try readRegularFile(pendingURL, within: ledgerURL)
            )
        } catch {
            throw AnalysisPhysicalEvidenceAnchorLedgerError.ambiguousRecoveryState
        }
        guard pending.schemaVersion == 1,
              pending.ledgerID == ledgerID,
              validateRecord(pending.candidateRecord),
              pending.candidateRelativePath == recordRelativePath(pending.candidateRecord),
              pending.previousLedgerRootSHA256.map(AnalysisPhysicalEvidenceW39BatchLoader.isSHA256) ?? true,
              pending.previousLatestRecordRootSHA256.map(AnalysisPhysicalEvidenceW39BatchLoader.isSHA256) ?? true else {
            throw AnalysisPhysicalEvidenceAnchorLedgerError.ambiguousRecoveryState
        }

        let head = try loadHeadAllowingPendingCandidate(
            ledgerID: ledgerID,
            candidateRelativePath: pending.candidateRelativePath,
            rootURL: rootURL,
            fileManager: fileManager
        )
        let candidate = pending.candidateRecord
        if let head, candidate.sequence == head.latestSequence {
            guard head.latestRecordRootSHA256 == candidate.declaredRecordRootSHA256,
                  head.latestAnchorReceiptRootSHA256 == candidate.anchorReceiptRootSHA256,
                  head.latestCertificateRootSHA256 == candidate.certificateRootSHA256,
                  head.records.last?.relativePath == pending.candidateRelativePath,
                  try readRecord(relativePath: pending.candidateRelativePath, ledgerURL: ledgerURL, fileManager: fileManager) == candidate else {
                throw AnalysisPhysicalEvidenceAnchorLedgerError.ambiguousRecoveryState
            }
            try fileManager.removeItem(at: pendingURL)
            _ = try loadValidatedHead(ledgerID: ledgerID, rootURL: rootURL, fileManager: fileManager)
            return true
        }

        if let head {
            guard head.anchorID == candidate.anchorID,
                  candidate.sequence == head.latestSequence + 1,
                  candidate.anchorReceipt.anchor.predecessorAnchorReceiptRootSHA256 == head.latestAnchorReceiptRootSHA256,
                  candidate.predecessorLedgerRecordRootSHA256 == head.latestRecordRootSHA256,
                  pending.previousLedgerRootSHA256 == head.declaredLedgerRootSHA256,
                  pending.previousLatestRecordRootSHA256 == head.latestRecordRootSHA256 else {
                throw AnalysisPhysicalEvidenceAnchorLedgerError.ambiguousRecoveryState
            }
        } else {
            guard candidate.sequence == 1,
                  candidate.anchorReceipt.anchor.predecessorAnchorReceiptRootSHA256 == nil,
                  candidate.predecessorLedgerRecordRootSHA256 == nil,
                  pending.previousLedgerRootSHA256 == nil,
                  pending.previousLatestRecordRootSHA256 == nil else {
                throw AnalysisPhysicalEvidenceAnchorLedgerError.ambiguousRecoveryState
            }
        }

        let recordURL = ledgerURL.appendingPathComponent(pending.candidateRelativePath)
        if fileManager.fileExists(atPath: recordURL.path) {
            guard try readRecord(relativePath: pending.candidateRelativePath, ledgerURL: ledgerURL, fileManager: fileManager) == candidate else {
                throw AnalysisPhysicalEvidenceAnchorLedgerError.ambiguousRecoveryState
            }
        } else {
            try writeRecord(candidate, relativePath: pending.candidateRelativePath, ledgerURL: ledgerURL, fileManager: fileManager)
        }
        let newHead = try makeHead(previous: head, record: candidate, relativePath: pending.candidateRelativePath)
        try AnalysisPhysicalEvidenceAnchorLedgerCodec.encodeHead(newHead).write(
            to: ledgerURL.appendingPathComponent(headFileName), options: .atomic
        )
        try fileManager.removeItem(at: pendingURL)
        guard let verified = try loadValidatedHead(ledgerID: ledgerID, rootURL: rootURL, fileManager: fileManager),
              verified == newHead else {
            throw AnalysisPhysicalEvidenceAnchorLedgerError.readBackFailed
        }
        return true
    }

    private static func makeRecord(
        ledgerID: String,
        anchorReceipt: AnalysisPhysicalEvidenceAnchorReceipt,
        destinationCertificate: AnalysisPhysicalEvidenceDestinationVerificationCertificate,
        predecessorLedgerRecordRootSHA256: String?
    ) throws -> AnalysisPhysicalEvidenceAnchorLedgerRecord {
        var provisional = AnalysisPhysicalEvidenceAnchorLedgerRecord(
            ledgerID: ledgerID,
            anchorID: anchorReceipt.anchor.anchorID,
            sequence: anchorReceipt.anchor.anchorSequence,
            anchorReceiptRootSHA256: anchorReceipt.declaredAnchorReceiptRootSHA256,
            certificateRootSHA256: destinationCertificate.declaredCertificateRootSHA256,
            predecessorLedgerRecordRootSHA256: predecessorLedgerRecordRootSHA256,
            anchorReceipt: anchorReceipt,
            destinationCertificate: destinationCertificate,
            declaredRecordRootSHA256: String(repeating: "0", count: 64)
        )
        let root = try AnalysisPhysicalEvidenceAnchorLedgerRecordRoot.compute(provisional)
        provisional = .init(
            ledgerID: provisional.ledgerID,
            anchorID: provisional.anchorID,
            sequence: provisional.sequence,
            anchorReceiptRootSHA256: provisional.anchorReceiptRootSHA256,
            certificateRootSHA256: provisional.certificateRootSHA256,
            predecessorLedgerRecordRootSHA256: provisional.predecessorLedgerRecordRootSHA256,
            anchorReceipt: provisional.anchorReceipt,
            destinationCertificate: provisional.destinationCertificate,
            declaredRecordRootSHA256: root
        )
        return provisional
    }

    private static func makeHead(
        previous: AnalysisPhysicalEvidenceAnchorLedgerHead?,
        record: AnalysisPhysicalEvidenceAnchorLedgerRecord,
        relativePath: String
    ) throws -> AnalysisPhysicalEvidenceAnchorLedgerHead {
        var summaries = previous?.records ?? []
        summaries.append(.init(
            sequence: record.sequence,
            relativePath: relativePath,
            anchorReceiptRootSHA256: record.anchorReceiptRootSHA256,
            certificateRootSHA256: record.certificateRootSHA256,
            predecessorLedgerRecordRootSHA256: record.predecessorLedgerRecordRootSHA256,
            recordRootSHA256: record.declaredRecordRootSHA256
        ))
        let root = try AnalysisPhysicalEvidenceAnchorLedgerRoot.compute(
            ledgerID: record.ledgerID,
            anchorID: record.anchorID,
            records: summaries
        )
        return .init(
            ledgerID: record.ledgerID,
            anchorID: record.anchorID,
            records: summaries,
            latestSequence: record.sequence,
            latestAnchorReceiptRootSHA256: record.anchorReceiptRootSHA256,
            latestCertificateRootSHA256: record.certificateRootSHA256,
            latestRecordRootSHA256: record.declaredRecordRootSHA256,
            declaredLedgerRootSHA256: root
        )
    }

    private static func validateRecord(_ record: AnalysisPhysicalEvidenceAnchorLedgerRecord) -> Bool {
        record.schemaVersion == 1
            && AnalysisPhysicalEvidenceW39BatchLoader.safeComponent(record.ledgerID)
            && AnalysisPhysicalEvidenceW39BatchLoader.safeComponent(record.anchorID)
            && record.sequence > 0
            && AnalysisPhysicalEvidenceW39BatchLoader.isSHA256(record.anchorReceiptRootSHA256)
            && AnalysisPhysicalEvidenceW39BatchLoader.isSHA256(record.certificateRootSHA256)
            && (record.predecessorLedgerRecordRootSHA256.map(AnalysisPhysicalEvidenceW39BatchLoader.isSHA256) ?? true)
            && record.anchorReceipt.anchor.anchorID == record.anchorID
            && record.anchorReceipt.anchor.anchorSequence == record.sequence
            && record.anchorReceipt.declaredAnchorReceiptRootSHA256 == record.anchorReceiptRootSHA256
            && record.destinationCertificate.declaredCertificateRootSHA256 == record.certificateRootSHA256
            && AnalysisPhysicalEvidenceAnchorLedgerPairValidator.validate(
                receipt: record.anchorReceipt,
                certificate: record.destinationCertificate
            )
            && (try? AnalysisPhysicalEvidenceAnchorLedgerRecordRoot.compute(record)) == record.declaredRecordRootSHA256
    }

    private static func loadValidatedHead(
        ledgerID: String,
        rootURL: URL,
        fileManager: FileManager
    ) throws -> AnalysisPhysicalEvidenceAnchorLedgerHead? {
        try loadHead(
            ledgerID: ledgerID,
            allowedExtraRelativePaths: [],
            rootURL: rootURL,
            fileManager: fileManager
        )
    }

    private static func loadHeadAllowingPendingCandidate(
        ledgerID: String,
        candidateRelativePath: String,
        rootURL: URL,
        fileManager: FileManager
    ) throws -> AnalysisPhysicalEvidenceAnchorLedgerHead? {
        try loadHead(
            ledgerID: ledgerID,
            allowedExtraRelativePaths: [pendingFileName, candidateRelativePath],
            rootURL: rootURL,
            fileManager: fileManager
        )
    }

    private static func loadHead(
        ledgerID: String,
        allowedExtraRelativePaths: Set<String>,
        rootURL: URL,
        fileManager: FileManager
    ) throws -> AnalysisPhysicalEvidenceAnchorLedgerHead? {
        let ledgerURL = ledgerDirectoryURL(ledgerID: ledgerID, rootURL: rootURL)
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: ledgerURL.path, isDirectory: &isDirectory) else { return nil }
        guard isDirectory.boolValue else { throw AnalysisPhysicalEvidenceAnchorLedgerError.corruptedLedger }

        let headURL = ledgerURL.appendingPathComponent(headFileName)
        guard fileManager.fileExists(atPath: headURL.path) else {
            let observed = try regularFileInventory(ledgerURL: ledgerURL, fileManager: fileManager)
            guard observed.subtracting(allowedExtraRelativePaths).isEmpty else {
                throw AnalysisPhysicalEvidenceAnchorLedgerError.corruptedLedger
            }
            return nil
        }
        let head: AnalysisPhysicalEvidenceAnchorLedgerHead
        do {
            head = try AnalysisPhysicalEvidenceAnchorLedgerCodec.decodeHead(try readRegularFile(headURL, within: ledgerURL))
        } catch {
            throw AnalysisPhysicalEvidenceAnchorLedgerError.corruptedLedger
        }
        guard head.schemaVersion == 1,
              head.ledgerID == ledgerID,
              AnalysisPhysicalEvidenceW39BatchLoader.safeComponent(head.anchorID),
              !head.records.isEmpty,
              head.records.count == Int(head.latestSequence),
              Set(head.records.map(\.sequence)).count == head.records.count,
              Set(head.records.map(\.relativePath)).count == head.records.count,
              AnalysisPhysicalEvidenceW39BatchLoader.isSHA256(head.latestAnchorReceiptRootSHA256),
              AnalysisPhysicalEvidenceW39BatchLoader.isSHA256(head.latestCertificateRootSHA256),
              AnalysisPhysicalEvidenceW39BatchLoader.isSHA256(head.latestRecordRootSHA256),
              AnalysisPhysicalEvidenceW39BatchLoader.isSHA256(head.declaredLedgerRootSHA256) else {
            throw AnalysisPhysicalEvidenceAnchorLedgerError.corruptedLedger
        }

        var previousRecordRoot: String?
        var previousReceiptRoot: String?
        for (index, summary) in head.records.sorted(by: { $0.sequence < $1.sequence }).enumerated() {
            let expectedSequence = UInt64(index + 1)
            guard summary.sequence == expectedSequence,
                  AnalysisPhysicalEvidenceW39BatchLoader.safeRelativePath(summary.relativePath),
                  summary.relativePath.hasPrefix("records/"),
                  AnalysisPhysicalEvidenceW39BatchLoader.isSHA256(summary.anchorReceiptRootSHA256),
                  AnalysisPhysicalEvidenceW39BatchLoader.isSHA256(summary.certificateRootSHA256),
                  AnalysisPhysicalEvidenceW39BatchLoader.isSHA256(summary.recordRootSHA256),
                  summary.predecessorLedgerRecordRootSHA256 == previousRecordRoot else {
                throw AnalysisPhysicalEvidenceAnchorLedgerError.corruptedLedger
            }
            let record = try readRecord(relativePath: summary.relativePath, ledgerURL: ledgerURL, fileManager: fileManager)
            guard validateRecord(record),
                  record.ledgerID == ledgerID,
                  record.anchorID == head.anchorID,
                  record.sequence == summary.sequence,
                  record.anchorReceiptRootSHA256 == summary.anchorReceiptRootSHA256,
                  record.certificateRootSHA256 == summary.certificateRootSHA256,
                  record.predecessorLedgerRecordRootSHA256 == summary.predecessorLedgerRecordRootSHA256,
                  record.declaredRecordRootSHA256 == summary.recordRootSHA256,
                  record.anchorReceipt.anchor.predecessorAnchorReceiptRootSHA256 == previousReceiptRoot else {
                throw AnalysisPhysicalEvidenceAnchorLedgerError.corruptedLedger
            }
            previousRecordRoot = record.declaredRecordRootSHA256
            previousReceiptRoot = record.anchorReceiptRootSHA256
        }
        guard let last = head.records.last,
              head.latestSequence == last.sequence,
              head.latestAnchorReceiptRootSHA256 == last.anchorReceiptRootSHA256,
              head.latestCertificateRootSHA256 == last.certificateRootSHA256,
              head.latestRecordRootSHA256 == last.recordRootSHA256,
              (try? AnalysisPhysicalEvidenceAnchorLedgerRoot.compute(
                ledgerID: ledgerID, anchorID: head.anchorID, records: head.records
              )) == head.declaredLedgerRootSHA256 else {
            throw AnalysisPhysicalEvidenceAnchorLedgerError.corruptedLedger
        }

        var expected = Set(head.records.map(\.relativePath))
        expected.insert(headFileName)
        expected.formUnion(allowedExtraRelativePaths)
        let observed = try regularFileInventory(ledgerURL: ledgerURL, fileManager: fileManager)
        guard observed.subtracting(expected).isEmpty,
              Set(head.records.map(\.relativePath)).union([headFileName]).isSubset(of: observed) else {
            throw AnalysisPhysicalEvidenceAnchorLedgerError.corruptedLedger
        }
        return head
    }

    private static func writeRecord(
        _ record: AnalysisPhysicalEvidenceAnchorLedgerRecord,
        relativePath: String,
        ledgerURL: URL,
        fileManager: FileManager
    ) throws {
        guard AnalysisPhysicalEvidenceW39BatchLoader.safeRelativePath(relativePath),
              relativePath == recordRelativePath(record) else {
            throw AnalysisPhysicalEvidenceAnchorLedgerError.writeFailed
        }
        let url = ledgerURL.appendingPathComponent(relativePath)
        try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if fileManager.fileExists(atPath: url.path) {
            throw AnalysisPhysicalEvidenceAnchorLedgerError.existingRecordCollision
        }
        try AnalysisPhysicalEvidenceAnchorLedgerCodec.encodeRecord(record).write(to: url, options: .atomic)
    }

    private static func readRecord(
        relativePath: String,
        ledgerURL: URL,
        fileManager: FileManager
    ) throws -> AnalysisPhysicalEvidenceAnchorLedgerRecord {
        guard AnalysisPhysicalEvidenceW39BatchLoader.safeRelativePath(relativePath) else {
            throw AnalysisPhysicalEvidenceAnchorLedgerError.corruptedLedger
        }
        do {
            return try AnalysisPhysicalEvidenceAnchorLedgerCodec.decodeRecord(
                try readRegularFile(ledgerURL.appendingPathComponent(relativePath), within: ledgerURL)
            )
        } catch {
            throw AnalysisPhysicalEvidenceAnchorLedgerError.corruptedLedger
        }
    }

    private static func regularFileInventory(
        ledgerURL: URL,
        fileManager: FileManager
    ) throws -> Set<String> {
        guard let enumerator = fileManager.enumerator(
            at: ledgerURL,
            includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey],
            options: [],
            errorHandler: { _, _ in false }
        ) else {
            throw AnalysisPhysicalEvidenceAnchorLedgerError.corruptedLedger
        }
        let rootPath = ledgerURL.standardizedFileURL.path
        var observed = Set<String>()
        for case let url as URL in enumerator {
            let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
            if values.isSymbolicLink == true {
                throw AnalysisPhysicalEvidenceAnchorLedgerError.corruptedLedger
            }
            guard values.isRegularFile == true else { continue }
            let path = relativePath(url, rootPath: rootPath)
            guard AnalysisPhysicalEvidenceW39BatchLoader.safeRelativePath(path) || path == pendingFileName else {
                throw AnalysisPhysicalEvidenceAnchorLedgerError.corruptedLedger
            }
            observed.insert(path)
        }
        return observed
    }

    private static func readRegularFile(_ url: URL, within root: URL) throws -> Data {
        let standardizedRoot = root.standardizedFileURL
        let standardizedURL = url.standardizedFileURL
        let prefix = standardizedRoot.path.hasSuffix("/") ? standardizedRoot.path : standardizedRoot.path + "/"
        guard standardizedURL.path.hasPrefix(prefix) else {
            throw AnalysisPhysicalEvidenceAnchorLedgerError.corruptedLedger
        }
        let values = try standardizedURL.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true else {
            throw AnalysisPhysicalEvidenceAnchorLedgerError.corruptedLedger
        }
        let resolvedRoot = standardizedRoot.resolvingSymlinksInPath().path
        let resolvedURL = standardizedURL.resolvingSymlinksInPath().path
        let resolvedPrefix = resolvedRoot.hasSuffix("/") ? resolvedRoot : resolvedRoot + "/"
        guard resolvedURL.hasPrefix(resolvedPrefix) else {
            throw AnalysisPhysicalEvidenceAnchorLedgerError.corruptedLedger
        }
        return try Data(contentsOf: standardizedURL)
    }

    private static func recordRelativePath(_ record: AnalysisPhysicalEvidenceAnchorLedgerRecord) -> String {
        let digits = String(record.sequence)
        let padded = String(repeating: "0", count: max(0, 20 - digits.count)) + digits
        return "records/\(padded)-\(record.declaredRecordRootSHA256.prefix(16)).json"
    }

    private static func ledgerDirectoryURL(ledgerID: String, rootURL: URL) -> URL {
        rootURL
            .appendingPathComponent("anchor-ledgers", isDirectory: true)
            .appendingPathComponent(ledgerID, isDirectory: true)
    }

    private static func relativePath(_ url: URL, rootPath: String) -> String {
        let path = url.standardizedFileURL.path
        let prefix = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"
        return path.hasPrefix(prefix) ? String(path.dropFirst(prefix.count)) : path
    }

    private static func makeAppendReceipt(
        status: AnalysisPhysicalEvidenceAnchorLedgerAppendStatus,
        record: AnalysisPhysicalEvidenceAnchorLedgerRecord,
        ledgerRoot: String
    ) -> AnalysisPhysicalEvidenceAnchorLedgerAppendReceipt {
        .init(
            status: status,
            ledgerID: record.ledgerID,
            anchorID: record.anchorID,
            sequence: record.sequence,
            anchorReceiptRootSHA256: record.anchorReceiptRootSHA256,
            certificateRootSHA256: record.certificateRootSHA256,
            recordRootSHA256: record.declaredRecordRootSHA256,
            ledgerRootSHA256: ledgerRoot
        )
    }
}

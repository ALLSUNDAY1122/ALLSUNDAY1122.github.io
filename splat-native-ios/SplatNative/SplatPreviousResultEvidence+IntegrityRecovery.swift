import CryptoKit
import Foundation

extension SplatPreviousResultEvidence {
    /// Restores the last independently verified result when the current result passed legacy size
    /// evidence but failed the strong SHA seal. The current evidence must still match the evidence
    /// that failed verification; otherwise a concurrent/newer completion wins and recovery stops.
    @discardableResult
    static func recoverTrustedPreviousAfterIntegrityFailure(
        projectURL: URL,
        evidence: SplatCommitEvidence,
        fileManager: FileManager = .default
    ) throws -> Bool {
        let currentEvidenceURL = projectURL.appendingPathComponent(ScanProjectStore.splatCommitEvidenceFileName)
        guard let currentEvidenceData = boundedRegularFileData(at: currentEvidenceURL, fileManager: fileManager),
              let currentEvidence = try? JSONDecoder().decode(SplatCommitEvidence.self, from: currentEvidenceData),
              currentEvidence == evidence else {
            return false
        }

        let backupEvidenceURL = projectURL.appendingPathComponent(fileName)
        let backupAssetURL = projectURL.appendingPathComponent(assetFileName)
        guard let snapshotData = boundedRegularFileData(at: backupEvidenceURL, fileManager: fileManager),
              let snapshot = try? JSONDecoder().decode(Snapshot.self, from: snapshotData),
              snapshot.schemaVersion == Snapshot.currentSchemaVersion,
              snapshot.originalEvidence.schemaVersion == SplatCommitEvidence.currentSchemaVersion,
              snapshot.originalEvidence.fileName == ScanProjectStore.splatResultFileName,
              snapshot.originalEvidence.byteCount > 0,
              snapshot.originalEvidence.byteCount % 32 == 0,
              isIndependentRegularFileForIntegrityRecovery(backupAssetURL),
              try fileByteCountForIntegrityRecovery(backupAssetURL, fileManager: fileManager) == snapshot.originalEvidence.byteCount,
              try sha256HexForIntegrityRecovery(fileURL: backupAssetURL) == snapshot.sha256 else {
            return false
        }

        let outputURL = projectURL.appendingPathComponent(ScanProjectStore.splatResultFileName)
        let partialURL = projectURL.appendingPathComponent(".result.integrity-recovery.partial")
        try? fileManager.removeItem(at: partialURL)
        defer { try? fileManager.removeItem(at: partialURL) }

        try fileManager.copyItem(at: backupAssetURL, to: partialURL)
        guard isIndependentRegularFileForIntegrityRecovery(partialURL),
              try fileByteCountForIntegrityRecovery(partialURL, fileManager: fileManager) == snapshot.originalEvidence.byteCount,
              try sha256HexForIntegrityRecovery(fileURL: partialURL) == snapshot.sha256 else {
            return false
        }
        try synchronizeForIntegrityRecovery(partialURL)

        if fileManager.fileExists(atPath: outputURL.path) {
            guard isIndependentRegularFileForIntegrityRecovery(outputURL) else { return false }
            _ = try fileManager.replaceItemAt(outputURL, withItemAt: partialURL)
        } else {
            try fileManager.moveItem(at: partialURL, to: outputURL)
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let restoredEvidenceData = try encoder.encode(snapshot.originalEvidence)
        try restoredEvidenceData.write(to: currentEvidenceURL, options: .atomic)
        try synchronizeForIntegrityRecovery(currentEvidenceURL)
        guard boundedRegularFileData(at: currentEvidenceURL, fileManager: fileManager) == restoredEvidenceData else {
            try? fileManager.removeItem(at: currentEvidenceURL)
            return false
        }

        let store = ScanProjectStore(
            rootURL: projectURL.deletingLastPathComponent(),
            fileManager: fileManager
        )
        _ = try store.updateManifest(projectURL: projectURL) { value in
            value.stage = .finished
            value.outputs[ScanRepresentationKind.splat.rawValue] = ScanProjectStore.splatResultFileName
            value.recoveredAfterInterruption = true
            value.lastError = "現在の3Dの整合性確認に失敗したため、直前の完成確認済み3Dを復元しました。"
        }
        return true
    }

    private static func boundedRegularFileData(
        at url: URL,
        fileManager: FileManager
    ) -> Data? {
        let maximumByteCount = 64 * 1024
        guard isIndependentRegularFileForIntegrityRecovery(url),
              let byteCount = try? fileByteCountForIntegrityRecovery(url, fileManager: fileManager),
              byteCount >= 0,
              byteCount <= Int64(maximumByteCount),
              let handle = try? FileHandle(forReadingFrom: url) else {
            return nil
        }
        defer { try? handle.close() }
        guard let data = try? handle.read(upToCount: maximumByteCount + 1),
              data.count <= maximumByteCount else {
            return nil
        }
        return data
    }

    private static func isIndependentRegularFileForIntegrityRecovery(_ url: URL) -> Bool {
        guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey]) else {
            return false
        }
        return values.isRegularFile == true && values.isSymbolicLink != true
    }

    private static func fileByteCountForIntegrityRecovery(
        _ url: URL,
        fileManager: FileManager
    ) throws -> Int64 {
        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        guard let size = attributes[.size] as? NSNumber else { throw CocoaError(.fileReadUnknown) }
        return size.int64Value
    }

    private static func synchronizeForIntegrityRecovery(_ url: URL) throws {
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        try handle.synchronize()
    }

    private static func sha256HexForIntegrityRecovery(fileURL: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: fileURL)
        defer { try? handle.close() }
        var hasher = SHA256()
        while true {
            try Task.checkCancellation()
            guard let chunk = try handle.read(upToCount: 1_024 * 1_024), !chunk.isEmpty else { break }
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}

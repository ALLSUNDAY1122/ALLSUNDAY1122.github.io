import CryptoKit
import Foundation

extension SplatPreviousResultEvidence {
    /// Last-resort recovery for a completed project whose current result still has the expected
    /// byte count but fails the strong SHA-256 completion check. The normal recovery path uses
    /// cheap structural checks so every library open does not hash the same large Splat twice;
    /// this path runs only after the strong verifier has already proved the current bytes untrusted.
    ///
    /// Recovery is allowed only when the protected snapshot belongs to the exact same commit
    /// evidence. A successful newer reconstruction therefore can never be replaced by an older
    /// protected result merely because that backup still exists.
    static func recoverTrustedPreviousAfterIntegrityFailure(
        projectURL: URL,
        evidence: SplatCommitEvidence,
        fileManager: FileManager = .default
    ) throws -> Bool {
        let snapshotURL = projectURL.appendingPathComponent(fileName)
        let backupURL = projectURL.appendingPathComponent(assetFileName)
        guard let snapshotData = try? Data(contentsOf: snapshotURL),
              let snapshot = try? JSONDecoder().decode(Snapshot.self, from: snapshotData),
              snapshot.schemaVersion == Snapshot.currentSchemaVersion,
              snapshot.originalEvidence == evidence,
              snapshot.originalEvidence.byteCount > 0,
              snapshot.originalEvidence.byteCount % 32 == 0,
              fileManager.fileExists(atPath: backupURL.path),
              try fileByteCountForIntegrityRecovery(backupURL, fileManager: fileManager) == evidence.byteCount,
              try sha256ForIntegrityRecovery(backupURL) == snapshot.sha256 else {
            return false
        }

        try Task.checkCancellation()
        let outputURL = projectURL.appendingPathComponent(ScanProjectStore.splatResultFileName)
        let partialURL = projectURL.appendingPathComponent(".result.splat.integrity-recovery.partial")
        try? fileManager.removeItem(at: partialURL)

        do {
            // Materialize and verify the replacement before removing the untrusted current result.
            // This preserves the best available bytes even if storage or I/O fails mid-recovery.
            try fileManager.copyItem(at: backupURL, to: partialURL)
            guard try fileByteCountForIntegrityRecovery(partialURL, fileManager: fileManager) == evidence.byteCount,
                  try sha256ForIntegrityRecovery(partialURL) == snapshot.sha256 else {
                try? fileManager.removeItem(at: partialURL)
                return false
            }
            try Task.checkCancellation()

            if fileManager.fileExists(atPath: outputURL.path) {
                try fileManager.removeItem(at: outputURL)
            }
            try fileManager.moveItem(at: partialURL, to: outputURL)
            return true
        } catch {
            try? fileManager.removeItem(at: partialURL)
            throw error
        }
    }

    private static func fileByteCountForIntegrityRecovery(
        _ url: URL,
        fileManager: FileManager
    ) throws -> Int64 {
        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        guard let size = attributes[.size] as? NSNumber else {
            throw CocoaError(.fileReadUnknown)
        }
        return size.int64Value
    }

    private static func sha256ForIntegrityRecovery(_ url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
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

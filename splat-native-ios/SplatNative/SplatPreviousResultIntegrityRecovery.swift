import CryptoKit
import Darwin
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
        guard isIndependentRegularFileForIntegrityRecovery(snapshotURL),
              let snapshotData = try? Data(contentsOf: snapshotURL),
              let snapshot = try? JSONDecoder().decode(Snapshot.self, from: snapshotData),
              snapshot.schemaVersion == Snapshot.currentSchemaVersion,
              snapshot.originalEvidence == evidence,
              snapshot.originalEvidence.byteCount > 0,
              snapshot.originalEvidence.byteCount % 32 == 0,
              isIndependentRegularFileForIntegrityRecovery(backupURL),
              try fileByteCountForIntegrityRecovery(backupURL, fileManager: fileManager) == evidence.byteCount,
              try sha256ForIntegrityRecovery(backupURL) == snapshot.sha256 else {
            return false
        }

        try Task.checkCancellation()
        let outputURL = projectURL.appendingPathComponent(ScanProjectStore.splatResultFileName)
        let partialURL = projectURL.appendingPathComponent(".result.splat.integrity-recovery.partial")
        try? fileManager.removeItem(at: partialURL)

        do {
            // Materialize and verify the replacement before touching the untrusted current result.
            // Prefer an APFS clone so a scene-sized recovery normally uses copy-on-write storage
            // without aliasing the protected backup. A hard link is deliberately not used here:
            // an in-place mutation of a recovered result must never mutate its recovery source.
            // Fall back to a normal copy when cloning is unavailable.
            try cloneOrCopyForIntegrityRecovery(
                from: backupURL,
                to: partialURL,
                fileManager: fileManager
            )
            guard isIndependentRegularFileForIntegrityRecovery(partialURL),
                  try fileByteCountForIntegrityRecovery(partialURL, fileManager: fileManager) == evidence.byteCount,
                  try sha256ForIntegrityRecovery(partialURL) == snapshot.sha256 else {
                try? fileManager.removeItem(at: partialURL)
                return false
            }
            try Task.checkCancellation()

            if fileManager.fileExists(atPath: outputURL.path) {
                // Replace in one filesystem transaction. The previous remove+move sequence created
                // a data-loss window: if the move failed after removing the corrupt-but-recoverable
                // current result, the project was left with no result at all. The verified partial
                // lives in the same project directory, so replaceItemAt can promote it atomically.
                _ = try fileManager.replaceItemAt(outputURL, withItemAt: partialURL)
            } else {
                try fileManager.moveItem(at: partialURL, to: outputURL)
            }
            return true
        } catch {
            try? fileManager.removeItem(at: partialURL)
            throw error
        }
    }

    private static func isIndependentRegularFileForIntegrityRecovery(_ url: URL) -> Bool {
        guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey]) else {
            return false
        }
        return values.isRegularFile == true && values.isSymbolicLink != true
    }

    private static func cloneOrCopyForIntegrityRecovery(
        from sourceURL: URL,
        to destinationURL: URL,
        fileManager: FileManager
    ) throws {
        let cloned = sourceURL.withUnsafeFileSystemRepresentation { sourcePath in
            destinationURL.withUnsafeFileSystemRepresentation { destinationPath in
                guard let sourcePath, let destinationPath else { return false }
                return clonefile(sourcePath, destinationPath, 0) == 0
            }
        }
        if cloned { return }

        // clonefile can fail on non-APFS/cross-volume destinations. Ensure no destination artifact
        // survives a failed clone before falling back to FileManager's independent copy.
        try? fileManager.removeItem(at: destinationURL)
        try fileManager.copyItem(at: sourceURL, to: destinationURL)
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

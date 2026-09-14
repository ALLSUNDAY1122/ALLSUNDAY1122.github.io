import CryptoKit
import Darwin
import Foundation

extension SplatPreviousResultEvidence {
    private static let maximumIntegritySnapshotByteCount: Int64 = 64 * 1024

    /// Last-resort recovery for a completed project whose current result still has the expected
    /// byte count but fails the strong SHA-256 completion check. The normal recovery path uses
    /// cheap structural checks so every library open does not hash the same large Splat twice;
    /// this path runs only after the strong verifier has already proved the current bytes untrusted.
    ///
    /// A protected previous result may belong to the immediately preceding commit evidence. That is
    /// precisely the useful fallback when a newer, strongly sealed result is later found corrupt.
    /// Recovery therefore validates the backup against the snapshot's original evidence/hash rather
    /// than requiring that older evidence to equal the already-failed current evidence. A snapshot
    /// from the future is rejected so stale/cross-run metadata cannot supersede a newer commit.
    static func recoverTrustedPreviousAfterIntegrityFailure(
        projectURL: URL,
        evidence: SplatCommitEvidence,
        fileManager: FileManager = .default
    ) throws -> Bool {
        let snapshotURL = projectURL.appendingPathComponent(fileName)
        let backupURL = projectURL.appendingPathComponent(assetFileName)
        guard let snapshotData = readIntegritySnapshotDataIfSafe(
                  at: snapshotURL,
                  fileManager: fileManager
              ),
              let snapshot = try? JSONDecoder().decode(Snapshot.self, from: snapshotData),
              snapshot.schemaVersion == Snapshot.currentSchemaVersion,
              snapshot.originalEvidence.schemaVersion == SplatCommitEvidence.currentSchemaVersion,
              snapshot.originalEvidence.fileName == ScanProjectStore.splatResultFileName,
              snapshot.originalEvidence.byteCount > 0,
              snapshot.originalEvidence.byteCount % 32 == 0,
              snapshot.originalEvidence.completedAt <= evidence.completedAt,
              snapshot.preservedAt <= evidence.completedAt,
              isIndependentRegularFileForIntegrityRecovery(backupURL),
              try fileByteCountForIntegrityRecovery(backupURL, fileManager: fileManager) == snapshot.originalEvidence.byteCount,
              try sha256ForIntegrityRecovery(backupURL) == snapshot.sha256 else {
            return false
        }

        try Task.checkCancellation()
        let outputURL = projectURL.appendingPathComponent(ScanProjectStore.splatResultFileName)
        let evidenceURL = projectURL.appendingPathComponent(ScanProjectStore.splatCommitEvidenceFileName)
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
                  try fileByteCountForIntegrityRecovery(partialURL, fileManager: fileManager) == snapshot.originalEvidence.byteCount,
                  try sha256ForIntegrityRecovery(partialURL) == snapshot.sha256 else {
                try? fileManager.removeItem(at: partialURL)
                return false
            }
            try synchronizeIntegrityRecoveryFile(at: partialURL)
            try Task.checkCancellation()

            if fileManager.fileExists(atPath: outputURL.path) {
                // Replace in one filesystem transaction. The verified partial lives in the same
                // project directory, so promotion never creates a remove-then-move data-loss gap.
                _ = try fileManager.replaceItemAt(outputURL, withItemAt: partialURL)
            } else {
                try fileManager.moveItem(at: partialURL, to: outputURL)
            }

            // The bytes now belong to the previous trusted completion, so the commit evidence must
            // move back with them. Leaving the newer evidence in place made the restored asset fail
            // verification immediately after recovery, especially when both results had equal size.
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try writeIntegrityRecoveryMetadata(
                encoder.encode(snapshot.originalEvidence),
                to: evidenceURL
            )

            let store = ScanProjectStore(
                rootURL: projectURL.deletingLastPathComponent(),
                fileManager: fileManager
            )
            _ = try store.updateManifest(projectURL: projectURL) { manifest in
                manifest.stage = .finished
                manifest.outputs[ScanRepresentationKind.splat.rawValue] = ScanProjectStore.splatResultFileName
                manifest.recoveredAfterInterruption = true
                manifest.lastError = "最新の3Dの整合性を確認できなかったため、直前の完成確認済み3Dを復元しました。"
            }
            return true
        } catch {
            try? fileManager.removeItem(at: partialURL)
            throw error
        }
    }

    private static func readIntegritySnapshotDataIfSafe(
        at url: URL,
        fileManager: FileManager
    ) -> Data? {
        guard isIndependentRegularFileForIntegrityRecovery(url),
              let size = try? fileByteCountForIntegrityRecovery(url, fileManager: fileManager),
              size >= 0,
              size <= maximumIntegritySnapshotByteCount,
              let handle = try? FileHandle(forReadingFrom: url) else {
            return nil
        }
        defer { try? handle.close() }

        // Re-check through a bounded read instead of Data(contentsOf:). The metadata file can be
        // replaced or extended after the size stat; reading at most cap + 1 keeps corruption or a
        // concurrent writer from turning that TOCTOU window into an unbounded allocation.
        guard let data = try? handle.read(upToCount: Int(maximumIntegritySnapshotByteCount) + 1),
              data.count <= Int(maximumIntegritySnapshotByteCount) else {
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

    private static func writeIntegrityRecoveryMetadata(_ data: Data, to url: URL) throws {
        try data.write(to: url, options: .atomic)
        try synchronizeIntegrityRecoveryFile(at: url)
    }

    private static func synchronizeIntegrityRecoveryFile(at url: URL) throws {
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        try handle.synchronize()
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
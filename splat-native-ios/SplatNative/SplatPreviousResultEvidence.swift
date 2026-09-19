import CryptoKit
import Darwin
import Foundation

/// Durable protection for the last trusted completed Splat while a new reconstruction is running.
///
/// The legacy Store swap keeps one `result.previous.splat`, but a second retry from `.failed`
/// can delete that file before the old result has been restored. C2 therefore keeps a separate
/// trusted backup. APFS cloning is attempted first so the backup normally costs no immediate
/// duplicate data blocks while remaining logically independent; a verified copy is used when
/// cloning is unavailable. SHA-256 binds the backup to its original completion evidence and
/// prevents same-size partial data from regaining trust.
enum SplatPreviousResultEvidence {
    static let fileName = "result.previous.splat.complete.json"
    static let assetFileName = "result.previous.trusted.splat"
    private static let maximumTrustMetadataByteCount: Int64 = 64 * 1024

    struct Snapshot: Codable, Equatable, Sendable {
        static let currentSchemaVersion = 2

        let schemaVersion: Int
        let originalEvidence: SplatCommitEvidence
        let sha256: String
        let preservedAt: Date

        init(originalEvidence: SplatCommitEvidence, sha256: String, preservedAt: Date = Date()) {
            self.schemaVersion = Self.currentSchemaVersion
            self.originalEvidence = originalEvidence
            self.sha256 = sha256
            self.preservedAt = preservedAt
        }
    }

    enum PreservationError: LocalizedError {
        case currentResultNotTrusted
        case completionEvidenceMissing
        case resultChangedDuringPreservation
        case previousResultBackupFailed

        var errorDescription: String? {
            switch self {
            case .currentResultNotTrusted:
                return "現在の完成3Dを安全に確認できないため、再処理を開始できません。"
            case .completionEvidenceMissing:
                return "現在の3Dの完了記録を退避できないため、再処理を開始できません。"
            case .resultChangedDuringPreservation:
                return "再処理準備中に3Dデータが変化したため、安全のため処理を中止しました。"
            case .previousResultBackupFailed:
                return "以前の完成3Dを保護できないため、再処理を開始できません。iPhoneの空き容量を確認してください。"
            }
        }
    }

    static func preserveBeforeReprocess(
        sourceURL: URL,
        fileManager: FileManager = .default
    ) throws {
        let verification: SplatCompletionVerifier.Verification
        do {
            verification = try SplatCompletionVerifier.verifyWithDigest(
                sourceURL: sourceURL,
                fileManager: fileManager
            )
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw PreservationError.currentResultNotTrusted
        }

        let trustedURL = verification.url
        let projectURL = trustedURL.deletingLastPathComponent()
        let evidenceURL = projectURL.appendingPathComponent(ScanProjectStore.splatCommitEvidenceFileName)
        guard let evidenceData = readTrustMetadataDataIfSafe(at: evidenceURL, fileManager: fileManager),
              let evidence = try? JSONDecoder().decode(SplatCommitEvidence.self, from: evidenceData),
              evidence.schemaVersion == SplatCommitEvidence.currentSchemaVersion,
              evidence.fileName == ScanProjectStore.splatResultFileName else {
            throw PreservationError.completionEvidenceMissing
        }

        let beforeSize = try fileByteCount(trustedURL, fileManager: fileManager)
        let hash = verification.sha256
        let afterSize = try fileByteCount(trustedURL, fileManager: fileManager)
        guard beforeSize == afterSize, afterSize == evidence.byteCount else {
            throw PreservationError.resultChangedDuringPreservation
        }

        discardBackup(projectURL: projectURL, fileManager: fileManager)
        let backupAssetURL = projectURL.appendingPathComponent(assetFileName)
        do {
            try materializeExactFile(
                sourceURL: trustedURL,
                destinationURL: backupAssetURL,
                expectedByteCount: evidence.byteCount,
                expectedSHA256: hash,
                fileManager: fileManager
            )
        } catch is CancellationError {
            discardBackup(projectURL: projectURL, fileManager: fileManager)
            throw CancellationError()
        } catch {
            discardBackup(projectURL: projectURL, fileManager: fileManager)
            throw PreservationError.previousResultBackupFailed
        }

        let snapshot = Snapshot(originalEvidence: evidence, sha256: hash)
        let backupEvidenceURL = projectURL.appendingPathComponent(fileName)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        do {
            try writeDurableMetadata(encoder.encode(snapshot), to: backupEvidenceURL)
        } catch {
            discardBackup(projectURL: projectURL, fileManager: fileManager)
            throw error
        }
    }

    @discardableResult
    static func recoverTrustedPreviousIfNeeded(
        projectURL: URL,
        manifest: ScanProjectManifest,
        fileManager: FileManager = .default
    ) -> ScanProjectManifest {
        let outputURL = projectURL.appendingPathComponent(ScanProjectStore.splatResultFileName)
        let currentEvidenceURL = projectURL.appendingPathComponent(ScanProjectStore.splatCommitEvidenceFileName)

        if currentResultMatchesEvidence(
            outputURL: outputURL,
            evidenceURL: currentEvidenceURL,
            fileManager: fileManager
        ) {
            return manifest
        }

        let backupEvidenceURL = projectURL.appendingPathComponent(fileName)
        let backupAssetURL = projectURL.appendingPathComponent(assetFileName)
        guard let data = readTrustMetadataDataIfSafe(at: backupEvidenceURL, fileManager: fileManager),
              let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data),
              snapshot.schemaVersion == Snapshot.currentSchemaVersion,
              snapshot.originalEvidence.schemaVersion == SplatCommitEvidence.currentSchemaVersion,
              snapshot.originalEvidence.fileName == ScanProjectStore.splatResultFileName,
              snapshot.originalEvidence.byteCount > 0,
              snapshot.originalEvidence.byteCount % 32 == 0,
              isIndependentRegularFile(backupAssetURL),
              (try? fileByteCount(backupAssetURL, fileManager: fileManager)) == snapshot.originalEvidence.byteCount,
              (try? sha256Hex(fileURL: backupAssetURL)) == snapshot.sha256 else {
            return manifest
        }

        do {
            try materializeExactFile(
                sourceURL: backupAssetURL,
                destinationURL: outputURL,
                expectedByteCount: snapshot.originalEvidence.byteCount,
                expectedSHA256: snapshot.sha256,
                fileManager: fileManager
            )

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try writeDurableMetadata(encoder.encode(snapshot.originalEvidence), to: currentEvidenceURL)

            let store = ScanProjectStore(
                rootURL: projectURL.deletingLastPathComponent(),
                fileManager: fileManager
            )
            return try store.updateManifest(projectURL: projectURL) { value in
                value.stage = .finished
                value.outputs[ScanRepresentationKind.splat.rawValue] = ScanProjectStore.splatResultFileName
                value.recoveredAfterInterruption = true
                value.lastError = "再処理が中断したため、直前の完成確認済み3Dを復元しました。"
            }
        } catch {
            try? fileManager.removeItem(at: currentEvidenceURL)
            return manifest
        }
    }

    static func discardBackup(
        projectURL: URL,
        fileManager: FileManager = .default
    ) {
        try? fileManager.removeItem(at: projectURL.appendingPathComponent(fileName))
        try? fileManager.removeItem(at: projectURL.appendingPathComponent(assetFileName))
        try? fileManager.removeItem(at: projectURL.appendingPathComponent(".\(assetFileName).partial"))
    }

    private static func currentResultMatchesEvidence(
        outputURL: URL,
        evidenceURL: URL,
        fileManager: FileManager
    ) -> Bool {
        guard isIndependentRegularFile(outputURL),
              let data = readTrustMetadataDataIfSafe(at: evidenceURL, fileManager: fileManager),
              let evidence = try? JSONDecoder().decode(SplatCommitEvidence.self, from: data),
              evidence.schemaVersion == SplatCommitEvidence.currentSchemaVersion,
              evidence.fileName == ScanProjectStore.splatResultFileName,
              evidence.byteCount > 0,
              evidence.byteCount % 32 == 0,
              let actual = try? fileByteCount(outputURL, fileManager: fileManager),
              actual == evidence.byteCount else {
            return false
        }
        return true
    }

    private static func materializeExactFile(
        sourceURL: URL,
        destinationURL: URL,
        expectedByteCount: Int64,
        expectedSHA256: String,
        fileManager: FileManager
    ) throws {
        guard isIndependentRegularFile(sourceURL) else {
            throw PreservationError.resultChangedDuringPreservation
        }

        let partialURL = destinationURL
            .deletingLastPathComponent()
            .appendingPathComponent(".\(destinationURL.lastPathComponent).partial")
        try? fileManager.removeItem(at: partialURL)

        do {
            let cloned = sourceURL.withUnsafeFileSystemRepresentation { sourcePath in
                partialURL.withUnsafeFileSystemRepresentation { destinationPath in
                    guard let sourcePath, let destinationPath else { return false }
                    return clonefile(sourcePath, destinationPath, 0) == 0
                }
            }
            if !cloned {
                try? fileManager.removeItem(at: partialURL)
                try fileManager.copyItem(at: sourceURL, to: partialURL)
            }

            guard isIndependentRegularFile(partialURL),
                  try fileByteCount(partialURL, fileManager: fileManager) == expectedByteCount,
                  try sha256Hex(fileURL: partialURL) == expectedSHA256 else {
                throw PreservationError.resultChangedDuringPreservation
            }
            try synchronizeFile(at: partialURL)

            if fileManager.fileExists(atPath: destinationURL.path) {
                _ = try fileManager.replaceItemAt(destinationURL, withItemAt: partialURL)
            } else {
                try fileManager.moveItem(at: partialURL, to: destinationURL)
            }
        } catch {
            try? fileManager.removeItem(at: partialURL)
            throw error
        }
    }

    private static func writeDurableMetadata(_ data: Data, to url: URL) throws {
        try data.write(to: url, options: .atomic)
        try synchronizeFile(at: url)
    }

    private static func synchronizeFile(at url: URL) throws {
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        try handle.synchronize()
    }

    private static func readTrustMetadataDataIfSafe(at url: URL, fileManager: FileManager) -> Data? {
        // Trust metadata decides whether a previous completed result may be restored. Keep that
        // decision bound to one regular, single-link descriptor generation instead of preflighting
        // the path and reopening it through FileHandle.
        try? BoundedFileReader.read(url, maximumBytes: Int(maximumTrustMetadataByteCount))
    }

    private static func isIndependentRegularFile(_ url: URL) -> Bool {
        guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey]) else {
            return false
        }
        return values.isRegularFile == true && values.isSymbolicLink != true
    }

    private static func fileByteCount(_ url: URL, fileManager: FileManager) throws -> Int64 {
        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        guard let size = attributes[.size] as? NSNumber else {
            throw PreservationError.resultChangedDuringPreservation
        }
        return size.int64Value
    }

    private static func sha256Hex(fileURL: URL) throws -> String {
        let descriptor = Darwin.open(fileURL.path, O_RDONLY | O_CLOEXEC | O_NOFOLLOW | O_NONBLOCK)
        guard descriptor >= 0 else { throw PreservationError.resultChangedDuringPreservation }
        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        defer { try? handle.close() }
        var opened = stat()
        guard fstat(descriptor, &opened) == 0, (opened.st_mode & S_IFMT) == S_IFREG, opened.st_nlink == 1 else {
            throw PreservationError.resultChangedDuringPreservation
        }
        var hasher = SHA256()
        while true {
            try Task.checkCancellation()
            guard let chunk = try handle.read(upToCount: 1_024 * 1_024), !chunk.isEmpty else { break }
            hasher.update(data: chunk)
        }
        var finalOpened = stat(); var named = stat()
        guard fstat(descriptor, &finalOpened) == 0, lstat(fileURL.path, &named) == 0,
              (named.st_mode & S_IFMT) == S_IFREG, named.st_nlink == 1,
              finalOpened.st_dev == opened.st_dev, finalOpened.st_ino == opened.st_ino,
              finalOpened.st_nlink == opened.st_nlink, finalOpened.st_size == opened.st_size,
              finalOpened.st_mtimespec.tv_sec == opened.st_mtimespec.tv_sec, finalOpened.st_mtimespec.tv_nsec == opened.st_mtimespec.tv_nsec,
              finalOpened.st_ctimespec.tv_sec == opened.st_ctimespec.tv_sec, finalOpened.st_ctimespec.tv_nsec == opened.st_ctimespec.tv_nsec,
              named.st_dev == opened.st_dev, named.st_ino == opened.st_ino, named.st_size == opened.st_size,
              named.st_mtimespec.tv_sec == opened.st_mtimespec.tv_sec, named.st_mtimespec.tv_nsec == opened.st_mtimespec.tv_nsec,
              named.st_ctimespec.tv_sec == opened.st_ctimespec.tv_sec, named.st_ctimespec.tv_nsec == opened.st_ctimespec.tv_nsec else {
            throw PreservationError.resultChangedDuringPreservation
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}

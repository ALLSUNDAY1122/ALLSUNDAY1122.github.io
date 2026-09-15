import CryptoKit
import Foundation

/// Durable protection for the last trusted completed Splat while a new reconstruction is running.
///
/// The legacy Store swap keeps one `result.previous.splat`, but a second retry from `.failed`
/// can delete that file before the old result has been restored. C2 therefore keeps a separate
/// trusted backup. APFS hard-linking is attempted first so the backup normally costs no duplicate
/// data blocks; a verified copy is used only when linking is unavailable. SHA-256 binds the backup
/// to its original completion evidence and prevents same-size partial data from regaining trust.
enum SplatPreviousResultEvidence {
    static let fileName = "result.previous.splat.complete.json"
    static let assetFileName = "result.previous.trusted.splat"

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

    /// Call immediately before a completed result enters `.processing`.
    /// Existing backup is replaced only after the current result has passed the strict verifier.
    static func preserveBeforeReprocess(
        sourceURL: URL,
        fileManager: FileManager = .default
    ) throws {
        let trustedURL: URL
        do {
            trustedURL = try SplatCompletionVerifier.verify(sourceURL: sourceURL, fileManager: fileManager)
        } catch {
            throw PreservationError.currentResultNotTrusted
        }

        let projectURL = trustedURL.deletingLastPathComponent()
        let evidenceURL = projectURL.appendingPathComponent(ScanProjectStore.splatCommitEvidenceFileName)
        guard let evidenceData = try? Data(contentsOf: evidenceURL),
              let evidence = try? JSONDecoder().decode(SplatCommitEvidence.self, from: evidenceData),
              evidence.schemaVersion == SplatCommitEvidence.currentSchemaVersion,
              evidence.fileName == ScanProjectStore.splatResultFileName else {
            throw PreservationError.completionEvidenceMissing
        }

        let beforeSize = try fileByteCount(trustedURL, fileManager: fileManager)
        let hash = try sha256Hex(fileURL: trustedURL)
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
        } catch {
            discardBackup(projectURL: projectURL, fileManager: fileManager)
            throw PreservationError.previousResultBackupFailed
        }

        let snapshot = Snapshot(originalEvidence: evidence, sha256: hash)
        let backupEvidenceURL = projectURL.appendingPathComponent(fileName)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        do {
            try encoder.encode(snapshot).write(to: backupEvidenceURL, options: .atomic)
        } catch {
            discardBackup(projectURL: projectURL, fileManager: fileManager)
            throw error
        }
    }

    /// Restores the separately protected previous result after Store recovery has exhausted its
    /// legacy swap files. This is intentionally callable for `.failed`/`.captured` repaired state:
    /// the exact SHA-256-bound backup is stronger evidence than structural 32-byte alignment.
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
        guard let data = try? Data(contentsOf: backupEvidenceURL),
              let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data),
              snapshot.schemaVersion == Snapshot.currentSchemaVersion,
              snapshot.originalEvidence.schemaVersion == SplatCommitEvidence.currentSchemaVersion,
              snapshot.originalEvidence.fileName == ScanProjectStore.splatResultFileName,
              snapshot.originalEvidence.byteCount > 0,
              snapshot.originalEvidence.byteCount % 32 == 0,
              fileManager.fileExists(atPath: backupAssetURL.path),
              (try? fileByteCount(backupAssetURL, fileManager: fileManager)) == snapshot.originalEvidence.byteCount,
              (try? sha256Hex(fileURL: backupAssetURL)) == snapshot.sha256 else {
            return manifest
        }

        do {
            if fileManager.fileExists(atPath: outputURL.path) {
                try fileManager.removeItem(at: outputURL)
            }
            if fileManager.fileExists(atPath: currentEvidenceURL.path) {
                try fileManager.removeItem(at: currentEvidenceURL)
            }

            try materializeExactFile(
                sourceURL: backupAssetURL,
                destinationURL: outputURL,
                expectedByteCount: snapshot.originalEvidence.byteCount,
                expectedSHA256: snapshot.sha256,
                fileManager: fileManager
            )

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(snapshot.originalEvidence).write(to: currentEvidenceURL, options: .atomic)

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
        guard let data = try? Data(contentsOf: evidenceURL),
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
        let partialURL = destinationURL
            .deletingLastPathComponent()
            .appendingPathComponent(".\(destinationURL.lastPathComponent).partial")
        try? fileManager.removeItem(at: partialURL)
        try? fileManager.removeItem(at: destinationURL)

        do {
            do {
                try fileManager.linkItem(at: sourceURL, to: partialURL)
            } catch {
                try fileManager.copyItem(at: sourceURL, to: partialURL)
            }

            guard try fileByteCount(partialURL, fileManager: fileManager) == expectedByteCount,
                  try sha256Hex(fileURL: partialURL) == expectedSHA256 else {
                throw PreservationError.resultChangedDuringPreservation
            }
            try fileManager.moveItem(at: partialURL, to: destinationURL)
        } catch {
            try? fileManager.removeItem(at: partialURL)
            try? fileManager.removeItem(at: destinationURL)
            throw error
        }
    }

    private static func fileByteCount(_ url: URL, fileManager: FileManager) throws -> Int64 {
        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        guard let size = attributes[.size] as? NSNumber else {
            throw PreservationError.resultChangedDuringPreservation
        }
        return size.int64Value
    }

    private static func sha256Hex(fileURL: URL) throws -> String {
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

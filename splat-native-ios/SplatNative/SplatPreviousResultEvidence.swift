import CryptoKit
import Foundation

/// Durable sidecar used only while a trusted completed Splat is being reprocessed.
///
/// `ScanProjectStore` already preserves the previous `result.splat` bytes, but its legacy swap
/// path removes the current completion evidence before moving those bytes to `result.previous.splat`.
/// This sidecar binds the old completion evidence to the exact old bytes with SHA-256 so a crash
/// can restore trust only for that exact previous result, never for a same-size partial write.
enum SplatPreviousResultEvidence {
    static let fileName = "result.previous.splat.complete.json"

    struct Snapshot: Codable, Equatable, Sendable {
        static let currentSchemaVersion = 1

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

        var errorDescription: String? {
            switch self {
            case .currentResultNotTrusted:
                return "現在の完成3Dを安全に確認できないため、再処理を開始できません。"
            case .completionEvidenceMissing:
                return "現在の3Dの完了記録を退避できないため、再処理を開始できません。"
            case .resultChangedDuringPreservation:
                return "再処理準備中に3Dデータが変化したため、安全のため処理を中止しました。"
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

        let snapshot = Snapshot(originalEvidence: evidence, sha256: hash)
        let backupURL = projectURL.appendingPathComponent(fileName)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(snapshot).write(to: backupURL, options: .atomic)
    }

    /// If Store recovery has restored the exact old bytes but the legacy evidence was lost,
    /// recreate the current evidence atomically. A SHA-256 mismatch always fails closed.
    static func restoreCurrentEvidenceIfExactPreviousResult(
        projectURL: URL,
        outputURL: URL,
        fileManager: FileManager = .default
    ) {
        let currentEvidenceURL = projectURL.appendingPathComponent(ScanProjectStore.splatCommitEvidenceFileName)
        let backupURL = projectURL.appendingPathComponent(fileName)

        // A new successful reconstruction already has its own completion evidence. The old
        // preservation sidecar is no longer needed and must not survive into a later lifecycle.
        if fileManager.fileExists(atPath: currentEvidenceURL.path) {
            try? fileManager.removeItem(at: backupURL)
            return
        }

        guard let data = try? Data(contentsOf: backupURL),
              let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data),
              snapshot.schemaVersion == Snapshot.currentSchemaVersion,
              snapshot.originalEvidence.schemaVersion == SplatCommitEvidence.currentSchemaVersion,
              snapshot.originalEvidence.fileName == ScanProjectStore.splatResultFileName,
              snapshot.originalEvidence.byteCount > 0,
              snapshot.originalEvidence.byteCount % 32 == 0,
              fileManager.fileExists(atPath: outputURL.path),
              (try? fileByteCount(outputURL, fileManager: fileManager)) == snapshot.originalEvidence.byteCount,
              (try? sha256Hex(fileURL: outputURL)) == snapshot.sha256 else {
            return
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let evidenceData = try? encoder.encode(snapshot.originalEvidence) {
            do {
                try evidenceData.write(to: currentEvidenceURL, options: .atomic)
                try? fileManager.removeItem(at: backupURL)
            } catch {
                try? fileManager.removeItem(at: currentEvidenceURL)
            }
        }
    }

    static func discardBackup(
        projectURL: URL,
        fileManager: FileManager = .default
    ) {
        try? fileManager.removeItem(at: projectURL.appendingPathComponent(fileName))
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

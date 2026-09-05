import CryptoKit
import Foundation

/// Strengthens the legacy byte-count completion evidence without changing its on-disk schema.
///
/// The first verification is allowed to seal only when the completed Splat has not been modified
/// after the commit evidence timestamp. Once sealed, every verification recomputes SHA-256 so a
/// same-size replacement cannot be accepted as the previously completed asset.
enum SplatStrongCompletionEvidence {
    static let fileName = "result.splat.sha256.json"

    struct Seal: Codable, Equatable, Sendable {
        static let currentSchemaVersion = 1

        let schemaVersion: Int
        let byteCount: Int64
        let completedAt: Date
        let sha256: String
        let sealedAt: Date

        init(evidence: SplatCommitEvidence, sha256: String, sealedAt: Date = Date()) {
            self.schemaVersion = Self.currentSchemaVersion
            self.byteCount = evidence.byteCount
            self.completedAt = evidence.completedAt
            self.sha256 = sha256
            self.sealedAt = sealedAt
        }

        func matches(_ evidence: SplatCommitEvidence) -> Bool {
            schemaVersion == Self.currentSchemaVersion &&
                byteCount == evidence.byteCount &&
                completedAt == evidence.completedAt &&
                !sha256.isEmpty
        }
    }

    enum IntegrityError: LocalizedError {
        case sourceMissing
        case sourceChangedAfterCommit
        case sourceChangedDuringVerification
        case hashMismatch

        var errorDescription: String? {
            switch self {
            case .sourceMissing:
                return "完成3Dデータを読み込めません。"
            case .sourceChangedAfterCommit:
                return "完成記録の後に3Dデータが変更されています。再生成してください。"
            case .sourceChangedDuringVerification:
                return "3Dデータの確認中に内容が変化しました。再試行してください。"
            case .hashMismatch:
                return "3Dデータの内容が完成時の記録と一致しません。再生成してください。"
            }
        }
    }

    static func verifyOrSeal(
        sourceURL: URL,
        evidence: SplatCommitEvidence,
        fileManager: FileManager = .default
    ) throws {
        let projectURL = sourceURL.deletingLastPathComponent()
        let sealURL = projectURL.appendingPathComponent(fileName)
        let before = try snapshot(sourceURL, fileManager: fileManager)
        guard before.byteCount == evidence.byteCount else { throw IntegrityError.hashMismatch }

        if let data = try? Data(contentsOf: sealURL),
           let seal = try? JSONDecoder().decode(Seal.self, from: data),
           seal.matches(evidence) {
            let hash = try sha256Hex(fileURL: sourceURL)
            let after = try snapshot(sourceURL, fileManager: fileManager)
            guard after == before else { throw IntegrityError.sourceChangedDuringVerification }
            guard hash == seal.sha256 else { throw IntegrityError.hashMismatch }
            return
        }

        // A stale seal is expected after a newly committed reconstruction. It may be replaced only
        // when the new result still carries the modification timestamp from before its commit record.
        // A same-size overwrite after completion changes mtime and therefore fails closed here.
        guard before.modificationDate <= evidence.completedAt else {
            throw IntegrityError.sourceChangedAfterCommit
        }

        let hash = try sha256Hex(fileURL: sourceURL)
        let after = try snapshot(sourceURL, fileManager: fileManager)
        guard after == before else { throw IntegrityError.sourceChangedDuringVerification }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(Seal(evidence: evidence, sha256: hash)).write(to: sealURL, options: .atomic)
    }

    private struct FileSnapshot: Equatable {
        let byteCount: Int64
        let modificationDate: Date
    }

    private static func snapshot(_ url: URL, fileManager: FileManager) throws -> FileSnapshot {
        guard fileManager.fileExists(atPath: url.path) else { throw IntegrityError.sourceMissing }
        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        guard let size = attributes[.size] as? NSNumber,
              let modificationDate = attributes[.modificationDate] as? Date else {
            throw IntegrityError.sourceMissing
        }
        return FileSnapshot(byteCount: size.int64Value, modificationDate: modificationDate)
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

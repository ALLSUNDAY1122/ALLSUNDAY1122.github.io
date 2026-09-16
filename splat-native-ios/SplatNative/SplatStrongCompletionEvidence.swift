import CryptoKit
import Foundation

/// Strengthens the legacy byte-count completion evidence without changing its on-disk schema.
enum SplatStrongCompletionEvidence {
    static let fileName = "result.splat.sha256.json"
    private static let maximumSealByteCount: Int64 = 64 * 1024

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
        case evidencePersistenceFailed

        var errorDescription: String? {
            switch self {
            case .sourceMissing:
                return "完成3Dデータを読み込めません。"
            case .sourceChangedAfterCommit:
                return "完成記録の後に3Dデータが変更されています。再生成してください。"
            case .sourceChangedDuringVerification:
                return "3Dデータの確認中に内容が変化しました。もう一度開いてください。"
            case .hashMismatch:
                return "3Dデータの内容が完成時の記録と一致しません。再生成してください。"
            case .evidencePersistenceFailed:
                return "完成3Dデータの整合性記録を安全に確定できませんでした。もう一度開いてください。"
            }
        }
    }

    @discardableResult
    static func verifyOrSeal(
        sourceURL: URL,
        evidence: SplatCommitEvidence,
        fileManager: FileManager = .default
    ) throws -> String {
        let projectURL = sourceURL.deletingLastPathComponent()
        let sealURL = projectURL.appendingPathComponent(fileName)
        let before = try snapshot(sourceURL, fileManager: fileManager)
        guard before.byteCount == evidence.byteCount else { throw IntegrityError.hashMismatch }

        if let data = try readExistingSealIfSafe(sealURL, fileManager: fileManager),
           let seal = try? JSONDecoder().decode(Seal.self, from: data),
           seal.matches(evidence) {
            let hash = try sha256Hex(fileURL: sourceURL)
            let after = try snapshot(sourceURL, fileManager: fileManager)
            guard after == before else { throw IntegrityError.sourceChangedDuringVerification }
            guard hash == seal.sha256 else { throw IntegrityError.hashMismatch }
            return hash
        }

        guard before.modificationDate <= evidence.completedAt else {
            throw IntegrityError.sourceChangedAfterCommit
        }

        let hash = try sha256Hex(fileURL: sourceURL)
        let after = try snapshot(sourceURL, fileManager: fileManager)
        guard after == before else { throw IntegrityError.sourceChangedDuringVerification }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let encoded = try encoder.encode(Seal(evidence: evidence, sha256: hash))
        do {
            try writeSealAtomicallyAndSynchronize(encoded, to: sealURL, fileManager: fileManager)
        } catch {
            throw IntegrityError.evidencePersistenceFailed
        }

        guard let persisted = try readExistingSealIfSafe(sealURL, fileManager: fileManager),
              persisted == encoded,
              let decoded = try? JSONDecoder().decode(Seal.self, from: persisted),
              decoded.matches(evidence), decoded.sha256 == hash else {
            throw IntegrityError.evidencePersistenceFailed
        }
        return hash
    }

    private struct FileSnapshot: Equatable {
        let byteCount: Int64
        let modificationDate: Date
    }

    private static func snapshot(_ url: URL, fileManager: FileManager) throws -> FileSnapshot {
        guard fileManager.fileExists(atPath: url.path) else { throw IntegrityError.sourceMissing }
        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        guard (attributes[.type] as? FileAttributeType) == .typeRegular,
              let size = attributes[.size] as? NSNumber,
              size.int64Value > 0,
              let modificationDate = attributes[.modificationDate] as? Date else {
            throw IntegrityError.sourceMissing
        }
        return FileSnapshot(byteCount: size.int64Value, modificationDate: modificationDate)
    }

    private static func readExistingSealIfSafe(_ url: URL, fileManager: FileManager) throws -> Data? {
        guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey]),
              values.isRegularFile == true,
              values.isSymbolicLink != true,
              let attributes = try? fileManager.attributesOfItem(atPath: url.path),
              let size = attributes[.size] as? NSNumber,
              size.int64Value >= 0,
              size.int64Value <= maximumSealByteCount else {
            if fileManager.fileExists(atPath: url.path) ||
                (try? fileManager.destinationOfSymbolicLink(atPath: url.path)) != nil {
                throw IntegrityError.hashMismatch
            }
            return nil
        }

        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        guard let data = try handle.read(upToCount: Int(maximumSealByteCount) + 1),
              data.count <= Int(maximumSealByteCount) else {
            throw IntegrityError.hashMismatch
        }
        return data
    }

    private static func writeSealAtomicallyAndSynchronize(
        _ data: Data,
        to sealURL: URL,
        fileManager: FileManager
    ) throws {
        if (try? fileManager.destinationOfSymbolicLink(atPath: sealURL.path)) != nil {
            throw IntegrityError.evidencePersistenceFailed
        }
        if fileManager.fileExists(atPath: sealURL.path) {
            guard let values = try? sealURL.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey]),
                  values.isRegularFile == true,
                  values.isSymbolicLink != true else {
                throw IntegrityError.evidencePersistenceFailed
            }
        }

        let candidate = sealURL.deletingLastPathComponent()
            .appendingPathComponent(".\(sealURL.lastPathComponent).candidate-\(UUID().uuidString)")
        var committed = false
        defer { if !committed { try? fileManager.removeItem(at: candidate) } }
        try data.write(to: candidate, options: .atomic)
        let handle = try FileHandle(forWritingTo: candidate)
        defer { try? handle.close() }
        try handle.synchronize()

        if fileManager.fileExists(atPath: sealURL.path) {
            _ = try fileManager.replaceItemAt(sealURL, withItemAt: candidate)
        } else {
            try fileManager.moveItem(at: candidate, to: sealURL)
        }
        committed = true
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

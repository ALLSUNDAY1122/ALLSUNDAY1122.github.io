import CryptoKit
import Darwin
import Foundation

/// Strengthens the legacy byte-count completion evidence without changing its on-disk schema.
enum SplatStrongCompletionEvidence {
    static let fileName = "result.splat.sha256.json"
    private static let maximumSealByteCount: Int64 = 64 * 1024

    struct Seal: Codable, Equatable, Sendable {
        static let currentSchemaVersion = 1
        let schemaVersion: Int64
        let byteCount: Int64
        let completedAt: Date
        let sha256: String
        let sealedAt: Date

        init(evidence: SplatCommitEvidence, sha256: String, sealedAt: Date = Date()) {
            self.schemaVersion = Int64(Self.currentSchemaVersion)
            self.byteCount = evidence.byteCount
            self.completedAt = evidence.completedAt
            self.sha256 = sha256
            self.sealedAt = sealedAt
        }

        func matches(_ evidence: SplatCommitEvidence) -> Bool {
            schemaVersion == Int64(Self.currentSchemaVersion) && byteCount == evidence.byteCount && completedAt == evidence.completedAt && !sha256.isEmpty
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
            case .sourceMissing: return "完成3Dデータを読み込めません。"
            case .sourceChangedAfterCommit: return "完成記録の後に3Dデータが変更されています。再生成してください。"
            case .sourceChangedDuringVerification: return "3Dデータの確認中に内容が変化しました。もう一度開いてください。"
            case .hashMismatch: return "3Dデータの内容が完成時の記録と一致しません。再生成してください。"
            case .evidencePersistenceFailed: return "完成3Dデータの整合性記録を安全に確定できませんでした。もう一度開いてください。"
            }
        }
    }

    @discardableResult
    static func verifyOrSeal(sourceURL: URL, evidence: SplatCommitEvidence, fileManager: FileManager = .default) throws -> String {
        let projectURL = sourceURL.deletingLastPathComponent()
        let sealURL = projectURL.appendingPathComponent(fileName)
        let before = try snapshot(sourceURL)
        guard before.byteCount == evidence.byteCount else { throw IntegrityError.hashMismatch }

        if let data = try readExistingSealIfSafe(sealURL, fileManager: fileManager),
           let seal = try? JSONDecoder().decode(Seal.self, from: data), seal.matches(evidence) {
            let hash = try sha256Hex(fileURL: sourceURL, expected: before)
            let after = try snapshot(sourceURL)
            guard after == before else { throw IntegrityError.sourceChangedDuringVerification }
            guard hash == seal.sha256 else { throw IntegrityError.hashMismatch }
            return hash
        }

        guard before.modificationDate <= evidence.completedAt else { throw IntegrityError.sourceChangedAfterCommit }
        let hash = try sha256Hex(fileURL: sourceURL, expected: before)
        let after = try snapshot(sourceURL)
        guard after == before else { throw IntegrityError.sourceChangedDuringVerification }

        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let encoded = try encoder.encode(Seal(evidence: evidence, sha256: hash))
        do { try writeSealAtomicallyAndSynchronize(encoded, to: sealURL, fileManager: fileManager) }
        catch { throw IntegrityError.evidencePersistenceFailed }

        guard let persisted = try readExistingSealIfSafe(sealURL, fileManager: fileManager), persisted == encoded,
              let decoded = try? JSONDecoder().decode(Seal.self, from: persisted), decoded.matches(evidence), decoded.sha256 == hash else {
            throw IntegrityError.evidencePersistenceFailed
        }
        return hash
    }

    private struct FileSnapshot: Equatable {
        let device: UInt64
        let inode: UInt64
        let linkCount: UInt64
        let byteCount: Int64
        let modificationSeconds: Int64
        let modificationNanoseconds: Int64
        let changeSeconds: Int64
        let changeNanoseconds: Int64
        let modificationDate: Date
    }

    private static func snapshot(_ url: URL) throws -> FileSnapshot {
        guard url.isFileURL, url.baseURL == nil, !url.path.isEmpty, url.path.hasPrefix("/"), !url.path.contains("\0"),
              url.host == nil, url.user == nil, url.password == nil, url.port == nil, url.query == nil, url.fragment == nil,
              url.standardizedFileURL.path == url.path else { throw IntegrityError.sourceMissing }
        var info = stat()
        guard lstat(url.path, &info) == 0, (info.st_mode & S_IFMT) == S_IFREG, info.st_nlink == 1, info.st_size > 0 else {
            throw IntegrityError.sourceMissing
        }
        return snapshot(from: info)
    }

    private static func snapshot(from info: stat) -> FileSnapshot {
        let seconds = Int64(info.st_mtimespec.tv_sec)
        let nanos = Int64(info.st_mtimespec.tv_nsec)
        return FileSnapshot(
            device: UInt64(info.st_dev), inode: UInt64(info.st_ino), linkCount: UInt64(info.st_nlink), byteCount: Int64(info.st_size),
            modificationSeconds: seconds, modificationNanoseconds: nanos,
            changeSeconds: Int64(info.st_ctimespec.tv_sec), changeNanoseconds: Int64(info.st_ctimespec.tv_nsec),
            modificationDate: Date(timeIntervalSince1970: TimeInterval(seconds) + TimeInterval(nanos) / 1_000_000_000)
        )
    }

    private static func readExistingSealIfSafe(_ url: URL, fileManager: FileManager) throws -> Data? {
        let exists = fileManager.fileExists(atPath: url.path)
        let isSymlink = (try? fileManager.destinationOfSymbolicLink(atPath: url.path)) != nil
        guard exists || isSymlink else { return nil }
        do { return try BoundedFileReader.read(url, maximumBytes: Int(maximumSealByteCount)) }
        catch is CancellationError { throw CancellationError() }
        catch { throw IntegrityError.hashMismatch }
    }

    private static func writeSealAtomicallyAndSynchronize(_ data: Data, to sealURL: URL, fileManager: FileManager) throws {
        if (try? fileManager.destinationOfSymbolicLink(atPath: sealURL.path)) != nil { throw IntegrityError.evidencePersistenceFailed }
        if fileManager.fileExists(atPath: sealURL.path) {
            guard let values = try? sealURL.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey]), values.isRegularFile == true, values.isSymbolicLink != true else {
                throw IntegrityError.evidencePersistenceFailed
            }
        }
        let candidate = sealURL.deletingLastPathComponent().appendingPathComponent(".\(sealURL.lastPathComponent).candidate-\(UUID().uuidString)")
        var committed = false
        defer { if !committed { try? fileManager.removeItem(at: candidate) } }
        try data.write(to: candidate, options: .atomic)
        let handle = try FileHandle(forWritingTo: candidate); defer { try? handle.close() }; try handle.synchronize()
        if fileManager.fileExists(atPath: sealURL.path) { _ = try fileManager.replaceItemAt(sealURL, withItemAt: candidate) }
        else { try fileManager.moveItem(at: candidate, to: sealURL) }
        committed = true
    }

    private static func sha256Hex(fileURL: URL, expected: FileSnapshot) throws -> String {
        let descriptor = Darwin.open(fileURL.path, O_RDONLY | O_CLOEXEC | O_NOFOLLOW | O_NONBLOCK)
        guard descriptor >= 0 else { throw IntegrityError.sourceMissing }
        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        defer { try? handle.close() }
        var openedInfo = stat()
        guard fstat(descriptor, &openedInfo) == 0, (openedInfo.st_mode & S_IFMT) == S_IFREG,
              snapshot(from: openedInfo) == expected else { throw IntegrityError.sourceChangedDuringVerification }

        var hasher = SHA256()
        while true {
            try Task.checkCancellation()
            guard let chunk = try handle.read(upToCount: 1_024 * 1_024), !chunk.isEmpty else { break }
            hasher.update(data: chunk)
        }
        var finalInfo = stat(); var namedInfo = stat()
        guard fstat(descriptor, &finalInfo) == 0, lstat(fileURL.path, &namedInfo) == 0,
              snapshot(from: finalInfo) == expected, snapshot(from: namedInfo) == expected else {
            throw IntegrityError.sourceChangedDuringVerification
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}

import Foundation

public enum RecoveryCheckpointStoreError: Error { case invalidBookID }

public struct RecoveryCheckpointStore: Sendable {
    public init() {}

    public func encode(_ checkpoint: RecoveryCheckpoint) throws -> Data {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(checkpoint)
    }

    public func decode(_ data: Data) throws -> RecoveryCheckpoint {
        try JSONDecoder().decode(RecoveryCheckpoint.self, from: data)
    }

    public func write(_ checkpoint: RecoveryCheckpoint, to url: URL) throws {
        guard !checkpoint.bookID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw RecoveryCheckpointStoreError.invalidBookID }
        let data = try encode(checkpoint)
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let temp = directory.appendingPathComponent(url.lastPathComponent + ".tmp")
        try data.write(to: temp, options: .atomic)
        _ = try? FileManager.default.removeItem(at: url)
        try FileManager.default.moveItem(at: temp, to: url)
    }

    public func read(from url: URL) throws -> RecoveryCheckpoint {
        try decode(Data(contentsOf: url))
    }
}

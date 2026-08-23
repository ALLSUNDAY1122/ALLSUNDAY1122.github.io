import Foundation

public protocol ProductCheckpointPersisting: Sendable {
    func load() async throws -> ProductPipelineCheckpoint?
    func save(_ checkpoint: ProductPipelineCheckpoint) async throws
    func clear() async throws
}

public actor FileProductCheckpointStore: ProductCheckpointPersisting {
    private let fileURL: URL
    private let fileManager: FileManager

    public init(fileURL: URL, fileManager: FileManager = .default) {
        self.fileURL = fileURL
        self.fileManager = fileManager
    }

    public func load() async throws -> ProductPipelineCheckpoint? {
        guard fileManager.fileExists(atPath: fileURL.path) else { return nil }
        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(ProductPipelineCheckpoint.self, from: data)
    }

    public func save(_ checkpoint: ProductPipelineCheckpoint) async throws {
        try fileManager.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(checkpoint).write(to: fileURL, options: .atomic)
    }

    public func clear() async throws {
        guard fileManager.fileExists(atPath: fileURL.path) else { return }
        try fileManager.removeItem(at: fileURL)
    }
}

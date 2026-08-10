import Foundation

public enum LearningStateStoreError: Error {
    case invalidContentVersion(expected: String, actual: String)
    case invalidTarget(Int)
}

public struct LearningBackupEnvelope: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let exportedAt: Date
    public let qualificationBundleID: String
    public let state: LearningState

    public init(
        schemaVersion: Int = 1,
        exportedAt: Date = Date(),
        qualificationBundleID: String,
        state: LearningState
    ) {
        self.schemaVersion = schemaVersion
        self.exportedAt = exportedAt
        self.qualificationBundleID = qualificationBundleID
        self.state = state
    }
}

public final class LearningStateStore: @unchecked Sendable {
    public let bundleID: String
    public let contentVersion: String
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(
        bundleID: String,
        contentVersion: String,
        directoryURL: URL? = nil
    ) {
        self.bundleID = bundleID
        self.contentVersion = contentVersion
        let root = directoryURL ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.fileURL = root
            .appendingPathComponent("LearningSprint", isDirectory: true)
            .appendingPathComponent(bundleID, isDirectory: true)
            .appendingPathComponent("learning-state.json", isDirectory: false)
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder.dateEncodingStrategy = .iso8601
        self.decoder.dateDecodingStrategy = .iso8601
    }

    public func load() throws -> LearningState {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return LearningState(contentVersion: contentVersion)
        }
        let data = try Data(contentsOf: fileURL)
        var state = try decoder.decode(LearningState.self, from: data)
        if !LearningState.validTarget(state.dailyTarget) {
            state.dailyTarget = 8
        }
        state.textSizeStep = min(2, max(0, state.textSizeStep))
        return state
    }

    public func save(_ state: LearningState) throws {
        var safeState = state
        if !LearningState.validTarget(safeState.dailyTarget) {
            safeState.dailyTarget = 8
        }
        safeState.textSizeStep = min(2, max(0, safeState.textSizeStep))
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try encoder.encode(safeState)
        try data.write(to: fileURL, options: [.atomic])
    }

    public func exportBackup(_ state: LearningState) throws -> Data {
        let envelope = LearningBackupEnvelope(
            qualificationBundleID: bundleID,
            state: state
        )
        return try encoder.encode(envelope)
    }

    public func importBackup(_ data: Data, allowContentVersionMigration: Bool = false) throws -> LearningState {
        let envelope = try decoder.decode(LearningBackupEnvelope.self, from: data)
        guard envelope.qualificationBundleID == bundleID else {
            throw CocoaError(.fileReadCorruptFile, userInfo: [
                NSLocalizedDescriptionKey: "別の資格アプリのバックアップです。"
            ])
        }
        guard LearningState.validTarget(envelope.state.dailyTarget) else {
            throw LearningStateStoreError.invalidTarget(envelope.state.dailyTarget)
        }
        if !allowContentVersionMigration && envelope.state.contentVersion != contentVersion {
            throw LearningStateStoreError.invalidContentVersion(
                expected: contentVersion,
                actual: envelope.state.contentVersion
            )
        }
        var imported = envelope.state
        if allowContentVersionMigration {
            imported.contentVersion = contentVersion
            imported.resumeSession = nil
        }
        try save(imported)
        return imported
    }

    public func reset() throws {
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }
    }
}

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

    public init(schemaVersion: Int = 1, exportedAt: Date = Date(), qualificationBundleID: String, state: LearningState) {
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

    public init(bundleID: String, contentVersion: String, directoryURL: URL? = nil) {
        self.bundleID = bundleID
        self.contentVersion = contentVersion
        let root = directoryURL ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.fileURL = root.appendingPathComponent("LearningSprint", isDirectory: true).appendingPathComponent(bundleID, isDirectory: true).appendingPathComponent("learning-state.json", isDirectory: false)
        self.encoder = JSONEncoder(); self.decoder = JSONDecoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        Self.configureDates(encoder: self.encoder, decoder: self.decoder)
    }

    public func load() throws -> LearningState {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return LearningState(contentVersion: contentVersion) }
        var state = try decoder.decode(LearningState.self, from: Data(contentsOf: fileURL))
        normalize(&state)
        return state
    }

    public func save(_ state: LearningState) throws {
        var safeState = state; normalize(&safeState)
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try encoder.encode(safeState).write(to: fileURL, options: [.atomic])
    }

    public func exportBackup(_ state: LearningState) throws -> Data {
        var safeState = state; normalize(&safeState)
        return try encoder.encode(LearningBackupEnvelope(qualificationBundleID: bundleID, state: safeState))
    }

    public func importBackup(_ data: Data, allowContentVersionMigration: Bool = false) throws -> LearningState {
        let envelope = try decoder.decode(LearningBackupEnvelope.self, from: data)
        guard envelope.qualificationBundleID == bundleID else {
            throw CocoaError(.fileReadCorruptFile, userInfo: [NSLocalizedDescriptionKey: "別の資格アプリのバックアップです。"])
        }
        guard LearningState.validTarget(envelope.state.dailyTarget) else { throw LearningStateStoreError.invalidTarget(envelope.state.dailyTarget) }
        if !allowContentVersionMigration && envelope.state.contentVersion != contentVersion {
            throw LearningStateStoreError.invalidContentVersion(expected: contentVersion, actual: envelope.state.contentVersion)
        }
        var imported = envelope.state
        if allowContentVersionMigration { imported.contentVersion = contentVersion; imported.resumeSession = nil }
        normalize(&imported); try save(imported); return imported
    }

    public func reset() throws {
        if FileManager.default.fileExists(atPath: fileURL.path) { try FileManager.default.removeItem(at: fileURL) }
    }

    private func normalize(_ state: inout LearningState) {
        if !LearningState.validTarget(state.dailyTarget) { state.dailyTarget = 8 }
        state.textSizeStep = min(2, max(0, state.textSizeStep))
        if state.shuffleQuestions == nil { state.shuffleQuestions = true }
        if state.shuffleChoices == nil { state.shuffleChoices = false }
    }

    private static func configureDates(encoder: JSONEncoder, decoder: JSONDecoder) {
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer(); try container.encode(date.timeIntervalSinceReferenceDate)
        }
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            if let value = try? container.decode(Double.self) { return Date(timeIntervalSinceReferenceDate: value) }
            let value = try container.decode(String.self)
            if let date = fractionalISO8601.date(from: value) ?? plainISO8601.date(from: value) { return date }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date value: \(value)")
        }
    }

    private static let fractionalISO8601: ISO8601DateFormatter = { let f=ISO8601DateFormatter(); f.formatOptions=[.withInternetDateTime,.withFractionalSeconds]; return f }()
    private static let plainISO8601: ISO8601DateFormatter = { let f=ISO8601DateFormatter(); f.formatOptions=[.withInternetDateTime]; return f }()
}

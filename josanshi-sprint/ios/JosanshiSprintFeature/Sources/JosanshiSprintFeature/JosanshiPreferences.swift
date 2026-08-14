import Foundation
import LearningSprintCore

public struct JosanshiPreferences: Codable, Equatable, Sendable {
    public var shuffleQuestions: Bool
    public var shuffleChoices: Bool
    /// Optional so preferences written before the v2.1 text-size control still decode safely.
    public var textSizeStep: Int?

    public init(
        shuffleQuestions: Bool = true,
        shuffleChoices: Bool = true,
        textSizeStep: Int? = 0
    ) {
        self.shuffleQuestions = shuffleQuestions
        self.shuffleChoices = shuffleChoices
        self.textSizeStep = textSizeStep
    }

    public var resolvedTextSizeStep: Int {
        min(2, max(0, textSizeStep ?? 0))
    }
}

public final class JosanshiPreferencesStore: @unchecked Sendable {
    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(directoryURL: URL? = nil) {
        let root = directoryURL ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.fileURL = root
            .appendingPathComponent("LearningSprint", isDirectory: true)
            .appendingPathComponent(JosanshiLocalPersistenceConfiguration.storageNamespace, isDirectory: true)
            .appendingPathComponent("preferences.json", isDirectory: false)
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    public func load() throws -> JosanshiPreferences {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return JosanshiPreferences() }
        return try decoder.decode(JosanshiPreferences.self, from: Data(contentsOf: fileURL))
    }

    public func save(_ preferences: JosanshiPreferences) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try encoder.encode(preferences).write(to: fileURL, options: [.atomic])
    }
}

public struct JosanshiBackupEnvelope: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let namespace: String
    public let exportedAt: Date
    public let state: LearningState
    public let preferences: JosanshiPreferences

    public init(
        schemaVersion: Int = 2,
        namespace: String = JosanshiLocalPersistenceConfiguration.storageNamespace,
        exportedAt: Date = Date(),
        state: LearningState,
        preferences: JosanshiPreferences
    ) {
        self.schemaVersion = schemaVersion
        self.namespace = namespace
        self.exportedAt = exportedAt
        self.state = state
        self.preferences = preferences
    }
}

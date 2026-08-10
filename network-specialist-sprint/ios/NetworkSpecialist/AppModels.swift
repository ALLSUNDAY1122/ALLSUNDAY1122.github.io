import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct QuestionPayload: Codable {
    let schemaVersion: Int
    let contentVersion: String
    let lawBaselineDate: String?
    let sourceCheckedAt: String
    let sourceURLs: [String: String]
    let answerURLs: [String: String]
    let uniqueIDs: [String]
    let questions: [Question]
}

struct Question: Codable, Identifiable, Hashable {
    let id: String
    let examYear: Int
    let questionNo: Int
    let domain: String
    let topic: String
    let question: String
    let choices: [String]
    let answerIndex: Int
    let memoryLine: String
    let shortExplanation: String
    let detailExplanation: String
    let canonicalConceptId: String
    let isHistoricalRepeatOrVariant: Bool
    let uiDomain: String
    let sourceAttribution: String?

    var canonicalID: String {
        canonicalConceptId.isEmpty ? id : canonicalConceptId
    }
}

enum MainTab: String, CaseIterable, Identifiable {
    case home
    case mock
    case history
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: return "ホーム"
        case .mock: return "模試"
        case .history: return "記録"
        case .settings: return "設定"
        }
    }

    var systemImage: String {
        switch self {
        case .home: return "house"
        case .mock: return "doc.text"
        case .history: return "chart.bar"
        case .settings: return "gearshape"
        }
    }
}

enum SessionMode: String, Codable {
    case practice
    case mock
}

enum FontSizePreference: String, Codable, CaseIterable, Identifiable {
    case normal
    case large
    case xlarge

    var id: String { rawValue }

    var title: String {
        switch self {
        case .normal: return "標準"
        case .large: return "大"
        case .xlarge: return "特大"
        }
    }

    var scale: CGFloat {
        switch self {
        case .normal: return 1.0
        case .large: return 1.13
        case .xlarge: return 1.27
        }
    }
}

struct UserSettings: Codable, Equatable {
    var dailyGoal: Int = 8
    var fontSize: FontSizePreference = .normal
    var examDate: Date? = nil
}

struct WeakProgress: Codable, Equatable {
    var streak: Int
    var lastUpdatedAt: Date
}

struct AnswerLogEntry: Codable, Identifiable, Equatable {
    let id: UUID
    let questionID: String
    let canonicalQuestionID: String
    let answeredAt: Date
    let responseIndex: Int?
    let isUnknown: Bool
    let correct: Bool
    let uiDomain: String
    let sessionKey: String
    let examYear: Int
}

struct SessionResponse: Codable, Equatable {
    let selectedIndex: Int?
    let isUnknown: Bool
    let correct: Bool
}

struct SessionState: Codable, Equatable {
    let key: String
    let title: String
    let mode: SessionMode
    let questionIDs: [String]
    var index: Int
    var responses: [String: SessionResponse]
    let startedAt: Date

    var total: Int { questionIDs.count }
}

struct CompletionRecord: Codable, Identifiable, Equatable {
    let id: UUID
    let key: String
    let title: String
    let mode: SessionMode
    let completedAt: Date
    let total: Int
    let correct: Int
}

struct PersistedLearningState: Codable, Equatable {
    var schemaVersion: Int = 2
    var contentVersion: String
    var weak: [String: WeakProgress] = [:]
    var seenIDs: Set<String> = []
    var sessionCompletions: [String: Int] = [:]
    var answerLog: [AnswerLogEntry] = []
    var completionHistory: [CompletionRecord] = []
    var settings: UserSettings = .init()
    var inProgress: SessionState? = nil

    static func fresh(contentVersion: String) -> PersistedLearningState {
        PersistedLearningState(contentVersion: contentVersion)
    }
}

struct SessionResult: Identifiable, Equatable {
    let id = UUID()
    let key: String
    let title: String
    let mode: SessionMode
    let questionIDs: [String]
    let responses: [String: SessionResponse]
    let completedAt: Date

    var total: Int { questionIDs.count }
    var correct: Int { responses.values.filter(\.correct).count }
    var accuracy: Int { total == 0 ? 0 : Int((Double(correct) / Double(total) * 100).rounded()) }
}

struct BackupEnvelope: Codable {
    let exportedAt: Date
    let app: String
    let bundleID: String
    let contentVersion: String
    let state: PersistedLearningState
}

struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        self.data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

private struct AppFontScaleKey: EnvironmentKey {
    static let defaultValue: CGFloat = 1.0
}

extension EnvironmentValues {
    var appFontScale: CGFloat {
        get { self[AppFontScaleKey.self] }
        set { self[AppFontScaleKey.self] = newValue }
    }
}

private struct SerifFontModifier: ViewModifier {
    @Environment(\.appFontScale) private var scale
    let size: CGFloat
    let weight: Font.Weight

    func body(content: Content) -> some View {
        content
            .font(.custom("Hiragino Mincho ProN", size: size * scale))
            .fontWeight(weight)
    }
}

private struct SansFontModifier: ViewModifier {
    @Environment(\.appFontScale) private var scale
    let size: CGFloat
    let weight: Font.Weight

    func body(content: Content) -> some View {
        content.font(.system(size: size * scale, weight: weight, design: .default))
    }
}

extension View {
    func appSerif(_ size: CGFloat, weight: Font.Weight = .regular) -> some View {
        modifier(SerifFontModifier(size: size, weight: weight))
    }

    func appSans(_ size: CGFloat, weight: Font.Weight = .regular) -> some View {
        modifier(SansFontModifier(size: size, weight: weight))
    }
}

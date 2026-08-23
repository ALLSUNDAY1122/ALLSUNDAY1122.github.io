import Foundation
import SwiftUI
import UniformTypeIdentifiers

final class AppBundleToken: NSObject {}

enum QuestionContentUse: String, Codable, CaseIterable {
    case practice
    case officialMock = "official_mock"
}

enum QuestionDifficulty: String, Codable, CaseIterable {
    case foundation
    case standard
    case applied
}

struct StudyQuestion: Codable, Identifiable, Equatable {
    let id: String
    let examYear: Int?
    let subject: String
    let topic: String
    let stem: String
    let choices: [String]
    let correctIndices: [Int]
    let explanation: String
    let memory: String
    let sourceTitle: String
    let sourceURL: String
    let evidenceCheckedDate: String
    let lawBasisDate: String?
    let originType: String
    let releaseEligible: Bool
    let contentUse: QuestionContentUse?
    let difficulty: QuestionDifficulty?

    init(
        id: String,
        examYear: Int?,
        subject: String,
        topic: String,
        stem: String,
        choices: [String],
        correctIndices: [Int],
        explanation: String,
        memory: String,
        sourceTitle: String,
        sourceURL: String,
        evidenceCheckedDate: String,
        lawBasisDate: String?,
        originType: String,
        releaseEligible: Bool,
        contentUse: QuestionContentUse? = nil,
        difficulty: QuestionDifficulty? = nil
    ) {
        self.id = id
        self.examYear = examYear
        self.subject = subject
        self.topic = topic
        self.stem = stem
        self.choices = choices
        self.correctIndices = correctIndices
        self.explanation = explanation
        self.memory = memory
        self.sourceTitle = sourceTitle
        self.sourceURL = sourceURL
        self.evidenceCheckedDate = evidenceCheckedDate
        self.lawBasisDate = lawBasisDate
        self.originType = originType
        self.releaseEligible = releaseEligible
        self.contentUse = contentUse
        self.difficulty = difficulty
    }

    var isPracticeQuestion: Bool {
        originType == "original_preview" || contentUse == .practice
    }

    var isOfficialMockQuestion: Bool {
        contentUse == .officialMock
    }
}

struct AttemptState: Codable, Equatable {
    var answered = 0
    var correct = 0
    var consecutiveCorrect = 0
    var weak = false
    var unknown = false
}

struct DayStat: Codable, Equatable {
    var answered = 0
    var correct = 0
}

struct ResumeState: Codable, Equatable {
    let questionIDs: [String]
    var index: Int
    var correct: Int
    let title: String
    let consumesFreeSprint: Bool
    let requiresPremium: Bool?

    var resolvedRequiresPremium: Bool {
        if let requiresPremium { return requiresPremium }
        return title != "今日のスプリント" && title != "開発プレビュー"
    }
}

struct PersistentState: Codable, Equatable {
    var attempts: [String: AttemptState] = [:]
    var dailyStats: [String: DayStat] = [:]
    var totalAnswered = 0
    var totalCorrect = 0
    var dailyGoal = 8
    var selectedTextSize = "medium"
    var examDate: Date?
    var resume: ResumeState?
    var freeSprintConsumed = false
}

enum SessionDescriptor: Equatable {
    case daily
    case weak
    case subject(String)
    case mock(Int)
}

struct SessionResult: Equatable {
    let title: String
    let answered: Int
    let correct: Int
}

struct BackupPayload: Codable {
    let schemaVersion: Int
    let exportedAt: Date
    let state: PersistentState
}

struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data

    init(data: Data = Data()) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

extension DateFormatter {
    static let sprintDayKey: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

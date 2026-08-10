import Foundation

struct QuestionBundle: Codable {
    let schemaVersion: Int
    let contentVersion: String
    let questions: [Question]
}

struct Question: Codable, Identifiable, Hashable {
    let id: String
    let exam: Int
    let questionNo: Int
    let section: String
    let field: String
    let question: String
    let choices: [String]
    let answer: [Int]
    let acceptedAnswers: [[Int]]
    let scoringStatus: String
    let memoryPoint: String
    let explanation: String
    let sharedStem: String
    let displayMode: String
    let mediaAssets: [String]
    let numberedChoiceCount: Int
    let attribution: String
    let modificationDisclosure: String
    let canonicalId: String

    var isScored: Bool { scoringStatus != "excluded" }
    var isMediaQuestion: Bool { displayMode == "officialQuestionImage" }
    var selectionCount: Int {
        if let first = acceptedAnswers.first, !first.isEmpty { return first.count }
        return max(1, answer.count)
    }
    var availableChoices: [String] {
        if !choices.isEmpty { return choices }
        let count = max(numberedChoiceCount, (answer.max() ?? 0) + 1, 5)
        return (1...count).map { "選択肢 \($0)" }
    }
    var isFree: Bool { exam == 111 && section == "必須" }

    func accepts(_ indexes: [Int]) -> Bool {
        let normalized = indexes.sorted()
        if acceptedAnswers.contains(where: { $0.sorted() == normalized }) { return true }
        return answer.sorted() == normalized
    }
}

struct DailyRecord: Codable, Hashable {
    var answered = 0
    var correct = 0
}

struct FieldRecord: Codable, Hashable {
    var answered = 0
    var correct = 0
}

struct WeakRecord: Codable, Hashable {
    var streak = 0
    var lastAnsweredAt = Date()
}

struct SessionAnswer: Codable, Hashable {
    let questionID: String
    let correct: Bool
    let unknown: Bool
}

struct ActiveSession: Codable, Hashable {
    var title: String
    var field: String
    var ids: [String]
    var index: Int
    var answers: [SessionAnswer]
    var choiceOrders: [String: [Int]]
    var mockKey: String?

    var completed: Bool { index >= ids.count }
}

struct SessionHistory: Codable, Identifiable, Hashable {
    let id: UUID
    let completedAt: Date
    let title: String
    let score: Int
    let total: Int
}

struct MockResult: Codable, Hashable {
    let score: Int
    let total: Int
    let completedAt: Date
}

struct LearningState: Codable, Hashable {
    var totalAnswered = 0
    var totalCorrect = 0
    var weak: [String: WeakRecord] = [:]
    var history: [SessionHistory] = []
    var inProgress: ActiveSession?
    var fontSize = 16
    var goal = 8
    var shuffleQuestions = true
    var shuffleChoices = false
    var daily: [String: DailyRecord] = [:]
    var mock: [String: MockResult] = [:]
    var fields: [String: FieldRecord] = [:]
    var examDate: Date?
    var seen: Set<String> = []
}

struct AnswerFeedback: Hashable {
    let question: Question
    let selected: [Int]
    let correct: Bool
    let unknown: Bool
    let weakMessage: String
}

enum AppRoute: Equatable {
    case tabs
    case quiz
    case result
}

enum MainTab: String, CaseIterable, Identifiable {
    case home = "ホーム"
    case mock = "模試"
    case history = "記録"
    case settings = "設定"
    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .home: return "house"
        case .mock: return "rectangle.grid.2x2"
        case .history: return "chart.bar.xaxis"
        case .settings: return "gearshape"
        }
    }
}

import Foundation

struct NativeContentBundle: Decodable {
    let schemaVersion: Int
    let qualification: String
    let contentVersion: String
    let totalQuestions: Int
    let exams: [Int]
    let freeSampleQuestionIds: [String]
    let questions: [NativeQuestion]
}

struct NativeQuestion: Decodable, Identifiable {
    let id: String
    let sourceExam: Int
    let session: String
    let questionNo: Int
    let category: String
    let majorSubject: String
    let subject: String
    let answerType: String
    let selectCount: Int?
    let question: String
    let choices: [String]
    let acceptedChoiceSets: [[Int]]
    let numericAnswer: Double?
    let tolerance: Double
    let unit: String
    let point: String
    let detail: String
    let scenario: String
    let scenarioId: String
    let scenarioIndex: Int
    let scenarioTotal: Int
    let scoringMode: String
    let mediaAssets: [String]
    let mediaAttribution: String

    var isNumeric: Bool { answerType == "numeric" }
    var isMultiChoice: Bool { answerType == "multiChoice" }
    var requiredSelectionCount: Int { selectCount ?? acceptedChoiceSets.first?.count ?? 1 }
}

struct WeakProgress: Codable {
    var streak: Int = 0
    var misses: Int = 0
}

struct HistoryEntry: Codable, Identifiable {
    var id = UUID()
    let date: Date
    let title: String
    let correct: Int
    let scoredTotal: Int
    let attempted: Int
    let sourceExam: Int?
    let category: String?

    var rate: Int { scoredTotal > 0 ? Int((Double(correct) / Double(scoredTotal) * 100).rounded()) : 0 }
}

struct PersistedLearningState: Codable {
    var totalAnswers = 0
    var totalCorrect = 0
    var seen: Set<String> = []
    var weak: [String: WeakProgress] = [:]
    var history: [HistoryEntry] = []
    var goal = 8
    var fontScale = "normal"
    var examDate: Date?
    var dailyAnswers: [String: Int] = [:]
    var dailyCorrect: [String: Int] = [:]
}

struct AnswerResult: Codable {
    let questionId: String
    let correct: Bool
    let scored: Bool
    let unknown: Bool
    let responseChoices: [Int]
    let numericResponse: Double?
}

struct StudySession: Identifiable {
    let id = UUID()
    let questionIds: [String]
    let title: String
    let sourceExam: Int?
    let category: String?
    let isMock: Bool
    var index = 0
    var results: [AnswerResult] = []
    var answered = false

    var attempted: Int { results.count }
    var correct: Int { results.filter { $0.correct && $0.scored }.count }
    var scoredTotal: Int { results.filter(\.scored).count }
}

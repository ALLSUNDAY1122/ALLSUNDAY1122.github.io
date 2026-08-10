import Foundation

struct Question: Codable, Identifiable, Hashable {
    let id: String
    let round: Int
    let sourceYear: Int
    let session: String
    let sourceQuestionNo: Int
    let subject: String
    let topic: String
    let question: String
    let choices: [String]
    let officialAnswerNo: Int?
    let scoringStatus: String
    let shortExplanation: String
    let memoryLine: String
    let primaryBasis: String
    let basisURL: String
    let lawBaseline: String
    let currentLawStatus: String

    enum CodingKeys: String, CodingKey {
        case id, round, session, subject, topic, question, choices
        case sourceYear = "source_year"
        case sourceQuestionNo = "source_question_no"
        case officialAnswerNo = "official_answer_no"
        case scoringStatus = "scoring_status"
        case shortExplanation = "short_explanation"
        case memoryLine = "memory_line"
        case primaryBasis = "primary_basis"
        case basisURL = "basis_url"
        case lawBaseline = "law_baseline"
        case currentLawStatus = "current_law_status"
    }

    var isAllCorrect: Bool { scoringStatus == "all_correct" }
    var yearLabel: String { "令和\(sourceYear - 2018)年度" }
    var sessionLabel: String { session == "AM" ? "午前" : "午後" }
}

struct AttemptStat: Codable, Hashable {
    var answered = 0
    var correct = 0
    var correctStreak = 0
    var isWeak = false

    var accuracy: Double {
        guard answered > 0 else { return 0 }
        return Double(correct) / Double(answered)
    }
}

struct DayStat: Codable, Hashable {
    var answered = 0
    var correct = 0
}

struct SessionDescriptor: Codable, Hashable {
    enum Kind: String, Codable { case daily, weak, subject, mock }
    var kind: Kind
    var year: Int?
    var session: String?
    var subject: String?

    static let daily = SessionDescriptor(kind: .daily)
    static let weak = SessionDescriptor(kind: .weak)
    static func subject(year: Int, subject: String) -> Self { .init(kind: .subject, year: year, subject: subject) }
    static func mock(year: Int, session: String) -> Self { .init(kind: .mock, year: year, session: session) }

    init(kind: Kind, year: Int? = nil, session: String? = nil, subject: String? = nil) {
        self.kind = kind
        self.year = year
        self.session = session
        self.subject = subject
    }

    var completionKey: String {
        switch kind {
        case .daily: return "daily"
        case .weak: return "weak"
        case .subject: return "subject-\(year ?? 0)-\(subject ?? "")"
        case .mock: return "mock-\(year ?? 0)-\(session ?? "")"
        }
    }
}

struct SessionSnapshot: Codable, Hashable {
    var descriptor: SessionDescriptor
    var questionIDs: [String]
    var index: Int
    var correctCount: Int
    var answeredChoice: Int?
    var answeredCorrect: Bool?

    var isFinished: Bool { index >= questionIDs.count }
}

struct LearningState: Codable, Hashable {
    static let currentVersion = 2
    var version = currentVersion
    var dailyGoal = 8
    var textSize = "medium"
    var examDate: Date?
    var attempts: [String: AttemptStat] = [:]
    var days: [String: DayStat] = [:]
    var completionCounts: [String: Int] = [:]
    var resume: SessionSnapshot?

    var totalAnswered: Int { attempts.values.reduce(0) { $0 + $1.answered } }
    var totalCorrect: Int { attempts.values.reduce(0) { $0 + $1.correct } }
    var overallAccuracy: Double {
        guard totalAnswered > 0 else { return 0 }
        return Double(totalCorrect) / Double(totalAnswered)
    }
    var weakIDs: Set<String> { Set(attempts.compactMap { $0.value.isWeak ? $0.key : nil }) }
}

struct SessionResult: Identifiable, Hashable {
    let id = UUID()
    let descriptor: SessionDescriptor
    let correct: Int
    let total: Int
}

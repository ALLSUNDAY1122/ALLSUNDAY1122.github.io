import Foundation

struct QuestionRepository {
    let payload: QuestionPayload
    private let byID: [String: Question]
    private let uniqueIDSet: Set<String>

    init(payload: QuestionPayload) {
        self.payload = payload
        self.byID = Dictionary(uniqueKeysWithValues: payload.questions.map { ($0.id, $0) })
        self.uniqueIDSet = Set(payload.uniqueIDs)
    }

    static func load(bundle: Bundle = .main) throws -> QuestionRepository {
        let bundledURL = bundle.url(forResource: "questions.native", withExtension: "json")
            ?? bundle.url(forResource: "questions.native", withExtension: "json", subdirectory: "Resources")

        let data: Data
        if let bundledURL {
            data = try Data(contentsOf: bundledURL)
        } else {
            // The same audited payload is generated into Swift before XcodeGen runs.
            // This keeps offline startup and unit tests independent of Bundle resource layout.
            data = GeneratedQuestionPayload.data
        }

        let decoder = JSONDecoder()
        let payload = try decoder.decode(QuestionPayload.self, from: data)
        try validate(payload)
        return QuestionRepository(payload: payload)
    }

    static var empty: QuestionRepository {
        QuestionRepository(payload: QuestionPayload(
            schemaVersion: 1,
            contentVersion: "missing",
            lawBaselineDate: nil,
            sourceCheckedAt: "",
            sourceURLs: [:],
            answerURLs: [:],
            uniqueIDs: [],
            questions: []
        ))
    }

    var occurrences: [Question] { payload.questions }

    var uniqueQuestions: [Question] {
        payload.questions.filter { uniqueIDSet.contains($0.id) }
    }

    var years: [Int] {
        Array(Set(payload.questions.map(\.examYear))).sorted(by: >)
    }

    var domains: [String] {
        Array(Set(uniqueQuestions.map(\.uiDomain))).sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    func question(id: String) -> Question? {
        byID[id]
    }

    func canonicalQuestion(for question: Question) -> Question {
        byID[question.canonicalID] ?? question
    }

    func questions(forYear year: Int) -> [Question] {
        payload.questions.filter { $0.examYear == year }.sorted { $0.questionNo < $1.questionNo }
    }

    func uniqueQuestions(domain: String) -> [Question] {
        uniqueQuestions.filter { $0.uiDomain == domain }
    }

    func sourceURL(for question: Question) -> URL? {
        URL(string: payload.sourceURLs[String(question.examYear)] ?? "")
    }

    func answerURL(for question: Question) -> URL? {
        URL(string: payload.answerURLs[String(question.examYear)] ?? "")
    }

    private static func validate(_ payload: QuestionPayload) throws {
        guard payload.questions.count == 75 else {
            throw RepositoryError.invalidQuestionCount(payload.questions.count)
        }
        guard payload.uniqueIDs.count == 68, Set(payload.uniqueIDs).count == 68 else {
            throw RepositoryError.invalidUniqueCount(payload.uniqueIDs.count)
        }
        let ids = Set(payload.questions.map(\.id))
        guard ids.count == payload.questions.count else {
            throw RepositoryError.duplicateIDs
        }
        for id in payload.uniqueIDs where !ids.contains(id) {
            throw RepositoryError.missingUniqueQuestion(id)
        }
        for year in [2025, 2024, 2023] {
            let count = payload.questions.filter { $0.examYear == year }.count
            guard count == 25 else {
                throw RepositoryError.invalidYearCount(year: year, count: count)
            }
        }
        for question in payload.questions {
            guard question.choices.count == 4 else {
                throw RepositoryError.invalidChoiceCount(question.id)
            }
            guard question.choices.indices.contains(question.answerIndex) else {
                throw RepositoryError.invalidAnswerIndex(question.id)
            }
            guard !question.question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !question.memoryLine.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !question.detailExplanation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw RepositoryError.missingRequiredText(question.id)
            }
        }
    }

    enum RepositoryError: LocalizedError {
        case invalidQuestionCount(Int)
        case invalidUniqueCount(Int)
        case duplicateIDs
        case missingUniqueQuestion(String)
        case invalidYearCount(year: Int, count: Int)
        case invalidChoiceCount(String)
        case invalidAnswerIndex(String)
        case missingRequiredText(String)

        var errorDescription: String? {
            switch self {
            case .invalidQuestionCount(let count):
                return "出題枠が \(count) 問です。正本は75問です。"
            case .invalidUniqueCount(let count):
                return "通常学習ユニーク問題が \(count) 問です。正本は68問です。"
            case .duplicateIDs:
                return "問題IDが重複しています。"
            case .missingUniqueQuestion(let id):
                return "ユニーク問題ID \(id) が出題枠に存在しません。"
            case .invalidYearCount(let year, let count):
                return "\(year)年度が \(count) 問です。正本は25問です。"
            case .invalidChoiceCount(let id):
                return "\(id) の選択肢数が4ではありません。"
            case .invalidAnswerIndex(let id):
                return "\(id) の正答indexが不正です。"
            case .missingRequiredText(let id):
                return "\(id) の問題・要点・解説に欠損があります。"
            }
        }
    }
}

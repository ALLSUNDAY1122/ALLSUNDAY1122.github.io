import Foundation

struct Otsu4QuestionBank: Decodable {
    let contentVersion: String
    let lawBaselineDate: String
    let questions: [Otsu4Question]
}

struct Otsu4Question: Identifiable, Decodable, Hashable {
    let id: String
    let subject: String
    let topic: String
    let question: String
    let choices: [String]
    let answer: Int
    let point: String
    let detail: String
    let tags: [String]
    let sourceTitle: String
    let sourceURL: String
    let sourceCheckedAt: String
    let legalEffectiveDate: String?
    let contentVersion: String
    let difficulty: Int
    let premium: Bool
}

enum Otsu4ContentError: Error {
    case resourceMissing
    case invalidCounts
    case invalidQuestion(String)
}

struct Otsu4ContentStore {
    static let freeQuestionCount = 72

    let bank: Otsu4QuestionBank

    init(bundle: Bundle = .main) throws {
        guard let url = bundle.url(forResource: "questions.generated", withExtension: "json") else {
            throw Otsu4ContentError.resourceMissing
        }
        let data = try Data(contentsOf: url)
        let decoded = try JSONDecoder().decode(Otsu4QuestionBank.self, from: data)
        try Self.validate(decoded)
        bank = decoded
    }

    var allQuestions: [Otsu4Question] {
        bank.questions
    }

    var freeQuestions: [Otsu4Question] {
        Array(bank.questions.prefix(Self.freeQuestionCount))
    }

    func availableQuestions(isPremium: Bool) -> [Otsu4Question] {
        isPremium ? allQuestions : freeQuestions
    }

    func questions(subject: String, isPremium: Bool) -> [Otsu4Question] {
        availableQuestions(isPremium: isPremium).filter { $0.subject == subject }
    }

    func questions(withTag tag: String, isPremium: Bool) -> [Otsu4Question] {
        availableQuestions(isPremium: isPremium).filter { $0.tags.contains(tag) }
    }

    func mockExamQuestions() -> [Otsu4Question]? {
        let law = bank.questions.filter { $0.subject == "法令" }.prefix(15)
        let physics = bank.questions.filter { $0.subject == "物理・化学" }.prefix(10)
        let properties = bank.questions.filter { $0.subject == "性質・消火" }.prefix(10)
        guard law.count == 15, physics.count == 10, properties.count == 10 else { return nil }
        return Array(law + physics + properties)
    }

    private static func validate(_ bank: Otsu4QuestionBank) throws {
        guard bank.questions.count == 360 else { throw Otsu4ContentError.invalidCounts }
        let counts = Dictionary(grouping: bank.questions, by: \ .subject).mapValues(\.count)
        guard counts["法令"] == 144,
              counts["物理・化学"] == 96,
              counts["性質・消火"] == 120 else {
            throw Otsu4ContentError.invalidCounts
        }

        var ids = Set<String>()
        for q in bank.questions {
            guard ids.insert(q.id).inserted else { throw Otsu4ContentError.invalidQuestion(q.id) }
            guard q.choices.count == 5,
                  Set(q.choices).count == 5,
                  (0..<5).contains(q.answer),
                  !q.point.isEmpty,
                  !q.detail.isEmpty,
                  !q.sourceTitle.isEmpty,
                  !q.sourceURL.isEmpty else {
                throw Otsu4ContentError.invalidQuestion(q.id)
            }
        }
    }
}

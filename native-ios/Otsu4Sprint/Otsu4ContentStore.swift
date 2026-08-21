import Foundation

struct Otsu4QuestionBank: Decodable {
    let contentVersion: String
    let lawAuditDate: String
    let currentEffectiveDates: [String: String]
    let questions: [Otsu4Question]
}

struct Otsu4SourceRef: Decodable, Hashable {
    let title: String
    let url: String
    let locator: String
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
    let sourceLocator: String
    let sourceRefs: [Otsu4SourceRef]
    let learningObjective: String
    let conceptKey: String
}

enum Otsu4ContentError: Error {
    case resourceMissing
    case invalidCounts
    case invalidVersion
    case invalidQuestion(String)
}

struct Otsu4ContentStore {
    static let expectedContentVersion = "otsu4-2026-08-product-v2"
    static let freeQuestionCount = 72
    static let freeSubjectCounts = ["法令": 29, "物理・化学": 19, "性質・消火": 24]
    static let supportedSprintGoals = [4, 8, 16]
    static let mockSetCount = 3

    let bank: Otsu4QuestionBank

    init(bundle: Bundle = .main) throws {
        guard let url = bundle.url(forResource: "questions.generated", withExtension: "json") else {
            throw Otsu4ContentError.resourceMissing
        }
        try self.init(url: url)
    }

    init(url: URL) throws {
        try self.init(data: Data(contentsOf: url))
    }

    init(data: Data) throws {
        let decoded = try JSONDecoder().decode(Otsu4QuestionBank.self, from: data)
        try Self.validate(decoded)
        bank = decoded
    }

    var allQuestions: [Otsu4Question] { bank.questions }

    var freeQuestions: [Otsu4Question] {
        let law = bank.questions.filter { $0.subject == "法令" }.prefix(Self.freeSubjectCounts["法令"] ?? 0)
        let physics = bank.questions.filter { $0.subject == "物理・化学" }.prefix(Self.freeSubjectCounts["物理・化学"] ?? 0)
        let properties = bank.questions.filter { $0.subject == "性質・消火" }.prefix(Self.freeSubjectCounts["性質・消火"] ?? 0)
        return Array(law) + Array(physics) + Array(properties)
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

    func sprint(goal: Int = 8, isPremium: Bool) -> [Otsu4Question] {
        let normalizedGoal = Self.supportedSprintGoals.contains(goal) ? goal : 8
        let allocation = Self.sprintAllocation(for: normalizedGoal)
        let pool = availableQuestions(isPremium: isPremium)
        let law = pool.filter { $0.subject == "法令" }.shuffled().prefix(allocation.law)
        let physics = pool.filter { $0.subject == "物理・化学" }.shuffled().prefix(allocation.physics)
        let properties = pool.filter { $0.subject == "性質・消火" }.shuffled().prefix(allocation.properties)
        return (Array(law) + Array(physics) + Array(properties)).shuffled()
    }

    func mockExamQuestions(set: Int) -> [Otsu4Question]? {
        guard (1...Self.mockSetCount).contains(set) else { return nil }
        let lawPool = bank.questions.filter { $0.subject == "法令" }
        let physicsPool = bank.questions.filter { $0.subject == "物理・化学" }
        let propertiesPool = bank.questions.filter { $0.subject == "性質・消火" }

        guard let law = Self.balancedMockSlice(lawPool, set: set, count: 15, hardCount: 5, salt: "law"),
              let physics = Self.balancedMockSlice(physicsPool, set: set, count: 10, hardCount: 3, salt: "physics"),
              let properties = Self.balancedMockSlice(propertiesPool, set: set, count: 10, hardCount: 3, salt: "properties") else {
            return nil
        }
        return law + physics + properties
    }

    static func mockSetsAreDisjoint(in store: Otsu4ContentStore) -> Bool {
        let sets = (1...mockSetCount).compactMap { store.mockExamQuestions(set: $0) }
        guard sets.count == mockSetCount else { return false }
        let ids = sets.flatMap { $0.map(\.id) }
        return ids.count == Set(ids).count
    }

    private static func balancedMockSlice(
        _ pool: [Otsu4Question],
        set: Int,
        count: Int,
        hardCount: Int,
        salt: String
    ) -> [Otsu4Question]? {
        let normalCount = count - hardCount
        let hard = pool
            .filter { $0.difficulty >= 3 }
            .sorted { stableRank($0.id, salt: salt + "-hard") < stableRank($1.id, salt: salt + "-hard") }
        let normal = pool
            .filter { $0.difficulty < 3 }
            .sorted { stableRank($0.id, salt: salt + "-normal") < stableRank($1.id, salt: salt + "-normal") }

        let hardStart = (set - 1) * hardCount
        let normalStart = (set - 1) * normalCount
        guard hard.count >= hardStart + hardCount,
              normal.count >= normalStart + normalCount else { return nil }

        let selected = Array(hard[hardStart..<(hardStart + hardCount)])
            + Array(normal[normalStart..<(normalStart + normalCount)])
        return selected.sorted {
            stableRank($0.id, salt: salt + "-set-\(set)") < stableRank($1.id, salt: salt + "-set-\(set)")
        }
    }

    private static func stableRank(_ text: String, salt: String) -> UInt64 {
        var hash: UInt64 = 1_469_598_103_934_665_603
        for byte in (salt + "|" + text).utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return hash
    }

    private static func sprintAllocation(for goal: Int) -> (law: Int, physics: Int, properties: Int) {
        switch goal {
        case 4: return (2, 1, 1)
        case 16: return (7, 4, 5)
        default: return (3, 2, 3)
        }
    }

    private static func validate(_ bank: Otsu4QuestionBank) throws {
        guard bank.contentVersion == expectedContentVersion else { throw Otsu4ContentError.invalidVersion }
        guard bank.questions.count == 360 else { throw Otsu4ContentError.invalidCounts }
        let counts = Dictionary(grouping: bank.questions, by: \.subject).mapValues(\.count)
        guard counts["法令"] == 144,
              counts["物理・化学"] == 96,
              counts["性質・消火"] == 120 else {
            throw Otsu4ContentError.invalidCounts
        }

        var ids = Set<String>()
        for q in bank.questions {
            guard ids.insert(q.id).inserted else { throw Otsu4ContentError.invalidQuestion(q.id) }
            guard q.contentVersion == expectedContentVersion,
                  q.choices.count == 5,
                  Set(q.choices).count == 5,
                  (0..<5).contains(q.answer),
                  (2...3).contains(q.difficulty),
                  !q.question.isEmpty,
                  !q.point.isEmpty,
                  !q.detail.isEmpty,
                  !q.learningObjective.isEmpty,
                  !q.sourceTitle.isEmpty,
                  !q.sourceURL.isEmpty,
                  !q.sourceLocator.isEmpty,
                  !q.sourceRefs.isEmpty else {
                throw Otsu4ContentError.invalidQuestion(q.id)
            }
        }
    }
}

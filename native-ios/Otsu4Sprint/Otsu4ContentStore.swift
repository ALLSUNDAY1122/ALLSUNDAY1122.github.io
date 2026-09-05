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
    static let mockSetCount = 6

    let bank: Otsu4QuestionBank

    init(bundle: Bundle = .main) throws {
        guard let url = bundle.url(forResource: "questions.generated", withExtension: "json") else {
            throw Otsu4ContentError.resourceMissing
        }
        try self.init(url: url)
    }

    init(url: URL) throws { try self.init(data: Data(contentsOf: url)) }

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

    func availableQuestions(isPremium: Bool) -> [Otsu4Question] { isPremium ? allQuestions : freeQuestions }
    func questions(subject: String, isPremium: Bool) -> [Otsu4Question] { availableQuestions(isPremium: isPremium).filter { $0.subject == subject } }
    func questions(withTag tag: String, isPremium: Bool) -> [Otsu4Question] { availableQuestions(isPremium: isPremium).filter { $0.tags.contains(tag) } }

    func sprint(goal: Int = 8, isPremium: Bool) -> [Otsu4Question] {
        let normalizedGoal = Self.supportedSprintGoals.contains(goal) ? goal : 8
        let allocation = Self.sprintAllocation(for: normalizedGoal)
        let pool = availableQuestions(isPremium: isPremium)
        let law = pool.filter { $0.subject == "法令" }.shuffled().prefix(allocation.law)
        let physics = pool.filter { $0.subject == "物理・化学" }.shuffled().prefix(allocation.physics)
        let properties = pool.filter { $0.subject == "性質・消火" }.shuffled().prefix(allocation.properties)
        return (Array(law) + Array(physics) + Array(properties)).shuffled()
    }

    func practiceRoundQuestions(set: Int, isPremium: Bool) -> [Otsu4Question]? {
        guard (1...Self.mockSetCount).contains(set) else { return nil }
        if isPremium { return mockExamQuestions(set: set) }
        guard set == 1 else { return nil }
        let lawPool = freeQuestions.filter { $0.subject == "法令" }
        let physicsPool = freeQuestions.filter { $0.subject == "物理・化学" }
        let propertiesPool = freeQuestions.filter { $0.subject == "性質・消火" }
        let law = Array(Self.ordered(lawPool, salt: "practice-free-law").prefix(15))
        let physics = Array(Self.ordered(physicsPool, salt: "practice-free-physics").prefix(10))
        let properties = Array(Self.ordered(propertiesPool, salt: "practice-free-properties").prefix(10))
        guard law.count == 15, physics.count == 10, properties.count == 10 else { return nil }
        return Self.ordered(law + physics + properties, salt: "practice-free-round-1")
    }

    func mockExamQuestions(set: Int) -> [Otsu4Question]? {
        guard (1...Self.mockSetCount).contains(set) else { return nil }
        let lawPool = bank.questions.filter { $0.subject == "法令" }
        let physicsPool = bank.questions.filter { $0.subject == "物理・化学" }
        let propertiesPool = bank.questions.filter { $0.subject == "性質・消火" }
        guard let law = Self.lawMockSlice(lawPool, set: set),
              let physics = Self.physicsMockSlice(physicsPool, set: set),
              let properties = Self.propertiesMockSlice(propertiesPool, set: set) else { return nil }
        return law + physics + properties
    }

    static func mockSetsAreDisjoint(in store: Otsu4ContentStore) -> Bool {
        let sets = (1...mockSetCount).compactMap { store.mockExamQuestions(set: $0) }
        guard sets.count == mockSetCount else { return false }
        let ids = sets.flatMap { $0.map(\.id) }
        return ids.count == Set(ids).count
    }

    private static func lawMockSlice(_ pool: [Otsu4Question], set: Int) -> [Otsu4Question]? {
        let hard = pool.filter { $0.difficulty >= 3 }
        let knowledge = pool.filter { $0.difficulty < 3 && $0.topic.contains("指定数量") }
        let rule = pool.filter { $0.difficulty < 3 && !$0.topic.contains("指定数量") }
        guard let hardPart = take(hard, set: set, count: 5, salt: "law-hard"),
              let knowledgePart = take(knowledge, set: set, count: 2, salt: "law-knowledge"),
              let rulePart = take(rule, set: set, count: 8, salt: "law-rule") else { return nil }
        return ordered(hardPart + knowledgePart + rulePart, salt: "law-set-\(set)")
    }

    private static func physicsMockSlice(_ pool: [Otsu4Question], set: Int) -> [Otsu4Question]? {
        let mechanismTopics: Set<String> = ["冷却消火", "窒息消火", "除去消火", "抑制消火", "泡消火", "二酸化炭素消火", "粉末消火", "静電気", "接地"]
        let hard = pool.filter { $0.difficulty >= 3 }
        let mechanism = pool.filter { $0.difficulty < 3 && mechanismTopics.contains($0.topic) }
        let concept = pool.filter { $0.difficulty < 3 && !mechanismTopics.contains($0.topic) }
        guard let hardPart = take(hard, set: set, count: 3, salt: "physics-hard"),
              let conceptPart = take(concept, set: set, count: 5, salt: "physics-concept"),
              let mechanismPart = take(mechanism, set: set, count: 2, salt: "physics-mechanism") else { return nil }
        return ordered(hardPart + conceptPart + mechanismPart, salt: "physics-set-\(set)")
    }

    private static func propertiesMockSlice(_ pool: [Otsu4Question], set: Int) -> [Otsu4Question]? {
        let hardClassification = pool.filter { $0.difficulty >= 3 && $0.topic == "石油類区分" }
        let hardApplication = pool.filter { $0.difficulty >= 3 && ($0.topic == "指定数量応用" || $0.topic == "比較応用") }
        let normalClassification = pool.filter { $0.difficulty < 3 && $0.topic == "品名分類" }
        let normalResponse = pool.filter { $0.difficulty < 3 && $0.topic != "品名分類" }
        guard let hardClassificationPart = take(hardClassification, set: set, count: 1, salt: "properties-hard-classification"),
              let hardApplicationPart = take(hardApplication, set: set, count: 2, salt: "properties-hard-application"),
              let normalClassificationPart = take(normalClassification, set: set, count: 2, salt: "properties-normal-classification"),
              let normalResponsePart = take(normalResponse, set: set, count: 5, salt: "properties-response") else { return nil }
        return ordered(hardClassificationPart + hardApplicationPart + normalClassificationPart + normalResponsePart, salt: "properties-set-\(set)")
    }

    private static func take(_ pool: [Otsu4Question], set: Int, count: Int, salt: String) -> [Otsu4Question]? {
        let sorted = ordered(pool, salt: salt)
        let start = (set - 1) * count
        guard sorted.count >= start + count else { return nil }
        return Array(sorted[start..<(start + count)])
    }
    private static func ordered(_ pool: [Otsu4Question], salt: String) -> [Otsu4Question] { pool.sorted { stableRank($0.id, salt: salt) < stableRank($1.id, salt: salt) } }
    private static func stableRank(_ text: String, salt: String) -> UInt64 {
        var hash: UInt64 = 1_469_598_103_934_665_603
        for byte in (salt + "|" + text).utf8 { hash ^= UInt64(byte); hash &*= 1_099_511_628_211 }
        return hash
    }
    private static func sprintAllocation(for goal: Int) -> (law: Int, physics: Int, properties: Int) {
        switch goal { case 4: return (2, 1, 1); case 16: return (7, 4, 5); default: return (3, 2, 3) }
    }

    private static func validate(_ bank: Otsu4QuestionBank) throws {
        guard bank.contentVersion == expectedContentVersion else { throw Otsu4ContentError.invalidVersion }
        guard bank.questions.count == 720 else { throw Otsu4ContentError.invalidCounts }
        let counts = Dictionary(grouping: bank.questions, by: \.subject).mapValues(\.count)
        guard counts["法令"] == 288, counts["物理・化学"] == 192, counts["性質・消火"] == 240 else { throw Otsu4ContentError.invalidCounts }
        var ids = Set<String>()
        for q in bank.questions {
            guard ids.insert(q.id).inserted else { throw Otsu4ContentError.invalidQuestion(q.id) }
            guard q.contentVersion == expectedContentVersion,
                  q.choices.count == 5, Set(q.choices).count == 5, (0..<5).contains(q.answer), (2...3).contains(q.difficulty),
                  !q.question.isEmpty, !q.point.isEmpty, !q.detail.isEmpty, !q.learningObjective.isEmpty,
                  !q.sourceTitle.isEmpty, !q.sourceURL.isEmpty, !q.sourceLocator.isEmpty, !q.sourceRefs.isEmpty else {
                throw Otsu4ContentError.invalidQuestion(q.id)
            }
        }
    }
}

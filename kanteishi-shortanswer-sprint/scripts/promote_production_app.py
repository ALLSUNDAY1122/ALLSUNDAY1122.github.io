#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
IOS = ROOT / "ios"
APP = IOS / "KanteishiShortAnswer"


def replace_exact(path: Path, old: str, new: str) -> None:
    text = path.read_text(encoding="utf-8")
    if old not in text:
        if new in text:
            print(f"already promoted: {path}")
            return
        raise SystemExit(f"expected source block not found: {path}\n--- expected ---\n{old[:500]}")
    path.write_text(text.replace(old, new), encoding="utf-8")
    print(f"updated: {path}")


app_core = APP / "AppCore.swift"
replace_exact(
    app_core,
    '''    static func load(bundle: Bundle = .main) throws -> QuestionRepository {
        guard let url = bundle.url(forResource: "questions.prototype", withExtension: "json")
                ?? bundle.url(forResource: "questions.prototype", withExtension: "json", subdirectory: "Resources") else {
            throw RepositoryError.missingResource
        }
        let payload = try JSONDecoder().decode(QuestionPayload.self, from: Data(contentsOf: url))
        try validate(payload)
        return QuestionRepository(payload: payload)
    }
''',
    '''    static func load(bundle: Bundle = .main) throws -> QuestionRepository {
        let productionURL = bundle.url(forResource: "questions.production", withExtension: "json")
            ?? bundle.url(forResource: "questions.production", withExtension: "json", subdirectory: "Resources")
        let prototypeURL = bundle.url(forResource: "questions.prototype", withExtension: "json")
            ?? bundle.url(forResource: "questions.prototype", withExtension: "json", subdirectory: "Resources")
        guard let url = productionURL ?? prototypeURL else {
            throw RepositoryError.missingResource
        }
        let payload = try JSONDecoder().decode(QuestionPayload.self, from: Data(contentsOf: url))
        try validate(payload)
        return QuestionRepository(payload: payload)
    }
''',
)

replace_exact(
    app_core,
    '''    private static func validate(_ payload: QuestionPayload) throws {
        guard payload.productionTargetCount == 240 else { throw RepositoryError.invalidProductionTarget }
        guard payload.questions.count == 12 else { throw RepositoryError.invalidPrototypeCount(payload.questions.count) }
        guard Set(payload.questions.map(\\.id)).count == payload.questions.count else { throw RepositoryError.duplicateIDs }
        for round in 1...3 {
            for subject in ["不動産に関する行政法規", "不動産の鑑定評価に関する理論"] {
                let count = payload.questions.filter { $0.round == round && $0.subject == subject }.count
                guard count == 2 else { throw RepositoryError.invalidRoundSubject(round, subject, count) }
            }
        }
        for question in payload.questions {
            guard question.choices.count == 4,
                  question.choices.indices.contains(question.correctIndex),
                  !question.question.isEmpty,
                  !question.memoryLine.isEmpty,
                  !question.detailExplanation.isEmpty,
                  URL(string: question.sourceURL) != nil,
                  !question.referenceDate.isEmpty,
                  !question.rightsBasis.isEmpty else {
                throw RepositoryError.invalidQuestion(question.id)
            }
        }
    }

    enum RepositoryError: LocalizedError {
        case missingResource
        case invalidProductionTarget
        case invalidPrototypeCount(Int)
        case duplicateIDs
        case invalidRoundSubject(Int, String, Int)
        case invalidQuestion(String)

        var errorDescription: String? {
            switch self {
            case .missingResource: return "試作問題データを読み込めません。"
            case .invalidProductionTarget: return "製品版問題枠は240問でなければなりません。"
            case .invalidPrototypeCount(let count): return "試作データが\\(count)問です。正本は12問です。"
            case .duplicateIDs: return "問題IDが重複しています。"
            case .invalidRoundSubject(let round, let subject, let count): return "R\\(round)・\\(subject)が\\(count)問です。試作正本は2問です。"
            case .invalidQuestion(let id): return "\\(id)の必須データが不正です。"
            }
        }
    }
''',
    '''    private static func validate(_ payload: QuestionPayload) throws {
        guard payload.productionTargetCount == 240 else { throw RepositoryError.invalidProductionTarget }
        let isProduction = payload.contentVersion.hasPrefix("official-240-")
        let expectedTotal = isProduction ? 240 : 12
        let expectedPerSubjectRound = isProduction ? 40 : 2
        let expectedChoiceCount = isProduction ? 5 : 4
        guard payload.questions.count == expectedTotal else {
            throw RepositoryError.invalidQuestionCount(expected: expectedTotal, actual: payload.questions.count)
        }
        guard Set(payload.questions.map(\\.id)).count == payload.questions.count else { throw RepositoryError.duplicateIDs }
        guard Set(payload.questions.map(\\.edition)) == Set([2026, 2025, 2024]) else {
            throw RepositoryError.invalidEditions
        }
        for round in 1...3 {
            for subject in ["不動産に関する行政法規", "不動産の鑑定評価に関する理論"] {
                let count = payload.questions.filter { $0.round == round && $0.subject == subject }.count
                guard count == expectedPerSubjectRound else {
                    throw RepositoryError.invalidRoundSubject(round, subject, expected: expectedPerSubjectRound, actual: count)
                }
            }
        }
        for question in payload.questions {
            guard question.choices.count == expectedChoiceCount,
                  question.choices.indices.contains(question.correctIndex),
                  !question.question.isEmpty,
                  !question.memoryLine.isEmpty,
                  !question.shortExplanation.isEmpty,
                  !question.detailExplanation.isEmpty,
                  URL(string: question.sourceURL) != nil,
                  !question.referenceDate.isEmpty,
                  !question.originType.isEmpty,
                  !question.rightsBasis.isEmpty else {
                throw RepositoryError.invalidQuestion(question.id)
            }
        }
    }

    enum RepositoryError: LocalizedError {
        case missingResource
        case invalidProductionTarget
        case invalidQuestionCount(expected: Int, actual: Int)
        case duplicateIDs
        case invalidEditions
        case invalidRoundSubject(Int, String, expected: Int, actual: Int)
        case invalidQuestion(String)

        var errorDescription: String? {
            switch self {
            case .missingResource: return "問題データを読み込めません。"
            case .invalidProductionTarget: return "製品版問題枠は240問でなければなりません。"
            case .invalidQuestionCount(let expected, let actual): return "問題数が\\(actual)問です。期待値は\\(expected)問です。"
            case .duplicateIDs: return "問題IDが重複しています。"
            case .invalidEditions: return "収録年度は令和8・7・6年の3年度でなければなりません。"
            case .invalidRoundSubject(let round, let subject, let expected, let actual):
                return "R\\(round)・\\(subject)が\\(actual)問です。期待値は\\(expected)問です。"
            case .invalidQuestion(let id): return "\\(id)の必須データが不正です。"
            }
        }
    }
''',
)

replace_exact(
    app_core,
    '            title: "令和\\(edition - 2018)年 試作模試",',
    '            title: "令和\\(edition - 2018)年 模擬試験",',
)

content = APP / "ContentView.swift"
replacements = {
    'Text("正解 \\(store.todayCorrect)問・試作データ \\(store.repository.questions.count)問")':
        'Text("正解 \\(store.todayCorrect)問・公式過去問 \\(store.repository.questions.count)問")',
    'Text("試作 \\(store.repository.questions(domain: domain).count)問")':
        'Text("\\(store.repository.questions(domain: domain).count)問")',
    'PageHeader(title: "模擬試験", subtitle: "製品版は各年度80問。現在は操作確認用に各4問です。")':
        'PageHeader(title: "模擬試験", subtitle: "令和8・7・6年の公式80問を年度別に再現します。")',
    'Text("行政法規40問＋鑑定理論40問×3年度＝240問を製品版固定枠としています。試作データを水増しして240問とは扱いません。")':
        'Text("各年度は行政法規40問＋鑑定理論40問＝80問。3年度合計240問を収録しています。")',
    'Text("試作4問／製品80問")':
        'Text("公式80問")',
    'Text("令和\\(edition - 2018)年を試す")':
        'Text("令和\\(edition - 2018)年を解く")',
}
for old, new in replacements.items():
    replace_exact(content, old, new)

tests = IOS / "KanteishiShortAnswerTests" / "KanteishiShortAnswerTests.swift"
replace_exact(
    tests,
    '''    func testPrototypePayloadAndProductionContract() throws {
        let repository = try QuestionRepository.load()
        XCTAssertEqual(repository.questions.count, 12)
        XCTAssertEqual(repository.payload.productionTargetCount, 240)
        XCTAssertEqual(repository.editions, [2026, 2025, 2024])
        XCTAssertEqual(repository.questions(edition: 2026).count, 4)
        XCTAssertEqual(repository.questions(edition: 2025).count, 4)
        XCTAssertEqual(repository.questions(edition: 2024).count, 4)
    }
''',
    '''    func testProductionPayloadContract() throws {
        let repository = try QuestionRepository.load()
        XCTAssertEqual(repository.questions.count, 240)
        XCTAssertEqual(repository.payload.productionTargetCount, 240)
        XCTAssertTrue(repository.payload.contentVersion.hasPrefix("official-240-"))
        XCTAssertEqual(repository.editions, [2026, 2025, 2024])
        XCTAssertEqual(repository.questions(edition: 2026).count, 80)
        XCTAssertEqual(repository.questions(edition: 2025).count, 80)
        XCTAssertEqual(repository.questions(edition: 2024).count, 80)
        XCTAssertEqual(Set(repository.questions.map(\\.id)).count, 240)
        XCTAssertTrue(repository.questions.allSatisfy { $0.choices.count == 5 })
        for round in 1...3 {
            XCTAssertEqual(repository.questions.filter { $0.round == round && $0.subject == "不動産に関する行政法規" }.count, 40)
            XCTAssertEqual(repository.questions.filter { $0.round == round && $0.subject == "不動産の鑑定評価に関する理論" }.count, 40)
        }
    }
''',
)
replace_exact(tests, '            XCTFail("No prototype question")', '            XCTFail("No production question")')
replace_exact(
    tests,
    '''    @MainActor
    func testPrototypeMockUsesFourQuestionsPerEdition() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
        let store = LearningStore(persistenceURL: url)
        store.startMock(edition: 2026)
        XCTAssertEqual(store.session?.total, 4)
        XCTAssertEqual(store.session?.mode, .mock)
    }
''',
    '''    @MainActor
    func testProductionMockUsesEightyQuestionsPerEdition() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
        let store = LearningStore(persistenceURL: url)
        store.startMock(edition: 2026)
        XCTAssertEqual(store.session?.total, 80)
        XCTAssertEqual(store.session?.mode, .mock)
    }
''',
)

print("production app promotion patch complete")

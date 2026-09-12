import XCTest
@testable import Otsu4Sprint

@MainActor
final class Otsu4LearningStoreTests: XCTestCase {
    func testUnknownRegistersWeakAndThreeCorrectAnswersRemoveIt() throws {
        let (store, defaults, suite) = makeLearningStore()
        defer { defaults.removePersistentDomain(forName: suite) }
        let question = makeQuestion(id: "weak-1")

        completeOneQuestion(question, choice: nil, store: store)
        XCTAssertEqual(store.weakCount, 1, "わからないは苦手登録される")

        completeOneQuestion(question, choice: 0, store: store)
        XCTAssertEqual(store.weakCount, 1)
        completeOneQuestion(question, choice: 0, store: store)
        XCTAssertEqual(store.weakCount, 1)
        completeOneQuestion(question, choice: 0, store: store)
        XCTAssertEqual(store.weakCount, 0, "苦手は3連続正解で解除される")
    }

    func testWrongAnswerResetsWeakCorrectStreak() throws {
        let (store, defaults, suite) = makeLearningStore()
        defer { defaults.removePersistentDomain(forName: suite) }
        let question = makeQuestion(id: "weak-reset")

        completeOneQuestion(question, choice: 1, store: store)
        completeOneQuestion(question, choice: 0, store: store)
        completeOneQuestion(question, choice: 0, store: store)
        XCTAssertEqual(store.weakCount, 1)

        completeOneQuestion(question, choice: 2, store: store)
        completeOneQuestion(question, choice: 0, store: store)
        XCTAssertEqual(store.weakCount, 1, "誤答後は連続正解数を0から数え直す")
        completeOneQuestion(question, choice: 0, store: store)
        XCTAssertEqual(store.weakCount, 1)
        completeOneQuestion(question, choice: 0, store: store)
        XCTAssertEqual(store.weakCount, 0)
    }

    func testBackupRoundTripPreservesSettingsAndLearningState() throws {
        let (source, sourceDefaults, sourceSuite) = makeLearningStore()
        defer { sourceDefaults.removePersistentDomain(forName: sourceSuite) }
        source.setGoal(16)
        let examDate = Date(timeIntervalSince1970: 1_800_000_000)
        source.setExamDate(examDate)
        source.setFontScale(2)
        completeOneQuestion(makeQuestion(id: "backup-weak"), choice: nil, store: source)

        let data = try source.exportData()

        let (restored, restoredDefaults, restoredSuite) = makeLearningStore()
        defer { restoredDefaults.removePersistentDomain(forName: restoredSuite) }
        try restored.importData(data)

        XCTAssertEqual(restored.goal, 16)
        XCTAssertEqual(restored.fontScale, 2)
        XCTAssertNotNil(restored.examDate)
        XCTAssertEqual(restored.examDate!.timeIntervalSince1970, examDate.timeIntervalSince1970, accuracy: 0.001)
        XCTAssertEqual(restored.weakCount, 1)
        XCTAssertEqual(restored.history.count, 1)
        XCTAssertEqual(restored.seenCount, 1)
    }

    func testMockTimerUsesOriginalStartedAtAfterRestore() {
        let question = makeQuestion(id: "timer")
        let startedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let snapshot = Otsu4SessionSnapshot(
            kindCode: "mock",
            subject: nil,
            mockSet: 1,
            goal: nil,
            questionIDs: [question.id],
            index: 0,
            answers: [:],
            startedAt: startedAt
        )
        let restored = Otsu4StudySession(kind: .mock(1), questions: [question], snapshot: snapshot)

        XCTAssertEqual(restored.remainingSeconds(at: startedAt.addingTimeInterval(90)), 7_110)
        XCTAssertEqual(restored.timerText(at: startedAt.addingTimeInterval(90)), "118:30")
    }

    func testMockPassRequiresSixtyPercentInEverySubject() {
        let questions = makeMockQuestions()
        let session = Otsu4StudySession(kind: .mock(1), questions: questions)
        var correctUsed = ["法令": 0, "物理・化学": 0, "性質・消火": 0]
        let required = ["法令": 9, "物理・化学": 6, "性質・消火": 6]

        while !session.isFinished {
            let subject = session.currentQuestion.subject
            let shouldBeCorrect = correctUsed[subject, default: 0] < required[subject, default: 0]
            session.choose(shouldBeCorrect ? 0 : 1)
            if shouldBeCorrect { correctUsed[subject, default: 0] += 1 }
            session.next()
        }

        XCTAssertEqual(session.subjectResults["法令"]?.rate, 60)
        XCTAssertEqual(session.subjectResults["物理・化学"]?.rate, 60)
        XCTAssertEqual(session.subjectResults["性質・消火"]?.rate, 60)
        XCTAssertTrue(session.mockPassEstimate)
    }

    func testMockFailsWhenOneSubjectIsBelowSixtyPercent() {
        let questions = makeMockQuestions()
        let session = Otsu4StudySession(kind: .mock(1), questions: questions)
        var correctUsed = ["法令": 0, "物理・化学": 0, "性質・消火": 0]
        let required = ["法令": 9, "物理・化学": 5, "性質・消火": 6]

        while !session.isFinished {
            let subject = session.currentQuestion.subject
            let shouldBeCorrect = correctUsed[subject, default: 0] < required[subject, default: 0]
            session.choose(shouldBeCorrect ? 0 : 1)
            if shouldBeCorrect { correctUsed[subject, default: 0] += 1 }
            session.next()
        }

        XCTAssertEqual(session.subjectResults["物理・化学"]?.rate, 50)
        XCTAssertFalse(session.mockPassEstimate)
    }

    private func makeLearningStore() -> (Otsu4LearningStore, UserDefaults, String) {
        let suite = "Otsu4LearningStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return (Otsu4LearningStore(defaults: defaults), defaults, suite)
    }

    private func completeOneQuestion(_ question: Otsu4Question, choice: Int?, store: Otsu4LearningStore) {
        let session = Otsu4StudySession(kind: .sprint(4), questions: [question])
        session.choose(choice)
        session.next()
        XCTAssertTrue(session.isFinished)
        store.complete(session: session)
    }

    private func makeMockQuestions() -> [Otsu4Question] {
        let law = (0..<15).map { makeQuestion(id: "law-\($0)", subject: "法令") }
        let physics = (0..<10).map { makeQuestion(id: "physics-\($0)", subject: "物理・化学") }
        let properties = (0..<10).map { makeQuestion(id: "properties-\($0)", subject: "性質・消火") }
        return law + physics + properties
    }

    private func makeQuestion(id: String, subject: String = "法令") -> Otsu4Question {
        let source = Otsu4SourceRef(title: "test source", url: "https://example.invalid/source", locator: "test")
        return Otsu4Question(
            id: id,
            subject: subject,
            topic: "test topic",
            question: "test question \(id)",
            choices: ["A", "B", "C", "D", "E"],
            answer: 0,
            point: "test point",
            detail: "test detail",
            tags: ["test"],
            sourceTitle: source.title,
            sourceURL: source.url,
            sourceCheckedAt: "2026-08-09",
            legalEffectiveDate: nil,
            contentVersion: Otsu4ContentStore.expectedContentVersion,
            difficulty: 1,
            premium: false,
            sourceLocator: source.locator,
            sourceRefs: [source],
            learningObjective: "objective-\(id)",
            conceptKey: "concept-\(id)"
        )
    }
}

import XCTest
@testable import PharmacistSprint

final class QuestionModelTests: XCTestCase {
    private func question(
        id: String = "P111-001",
        exam: Int = 111,
        section: String = "必須",
        answer: [Int] = [1],
        accepted: [[Int]] = []
    ) -> Question {
        Question(
            id: id,
            exam: exam,
            questionNo: 1,
            section: section,
            field: "物理・化学・生物",
            question: "テスト問題",
            choices: ["A", "B", "C", "D", "E"],
            answer: answer,
            acceptedAnswers: accepted,
            scoringStatus: accepted.isEmpty ? "normal" : "multiple_accepted",
            memoryPoint: "要点",
            explanation: "解説",
            sharedStem: "",
            displayMode: "textChoices",
            mediaAssets: [],
            numberedChoiceCount: 0,
            attribution: "出典",
            modificationDisclosure: "加工して作成",
            canonicalId: id
        )
    }

    func testSingleChoiceScoring() {
        let q = question(answer: [1])
        XCTAssertTrue(q.accepts([1]))
        XCTAssertFalse(q.accepts([0]))
        XCTAssertEqual(q.selectionCount, 1)
    }

    func testMultipleAcceptedPairScoring() {
        let q = question(answer: [0, 1], accepted: [[0, 1], [0, 2], [1, 2]])
        XCTAssertTrue(q.accepts([2, 0]))
        XCTAssertTrue(q.accepts([1, 2]))
        XCTAssertFalse(q.accepts([3, 4]))
        XCTAssertEqual(q.selectionCount, 2)
    }

    func testLearningStateJSONRoundTripPreservesDailyAndWeakData() throws {
        var state = LearningState()
        state.totalAnswered = 8
        state.totalCorrect = 0
        state.daily["2026-08-10"] = DailyRecord(answered: 8, correct: 0)
        state.weak["P111-001"] = WeakRecord(streak: 0, lastAnsweredAt: Date(timeIntervalSince1970: 1_700_000_000))
        state.goal = 8
        state.seen.insert("P111-001")

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let restored = try decoder.decode(LearningState.self, from: encoder.encode(state))

        XCTAssertEqual(restored.totalAnswered, 8)
        XCTAssertEqual(restored.totalCorrect, 0)
        XCTAssertEqual(restored.daily["2026-08-10"]?.answered, 8)
        XCTAssertEqual(restored.daily["2026-08-10"]?.correct, 0)
        XCTAssertEqual(restored.weak["P111-001"]?.streak, 0)
        XCTAssertTrue(restored.seen.contains("P111-001"))
    }

    @MainActor
    func testNoIAPReleaseHasAllScoredQuestionsAvailable() {
        let store = LearningStore()
        XCTAssertEqual(store.questions.count, 1035)
        XCTAssertEqual(store.activeQuestions.count, 1031)

        let allSectionQuestions = [111, 110, 109].flatMap { exam in
            ["必須", "理論", "実践"].flatMap { section in
                store.sectionQuestions(exam: exam, section: section, premium: true)
            }
        }
        XCTAssertEqual(allSectionQuestions.count, 1031)
        XCTAssertEqual(Set(allSectionQuestions.map(\.id)).count, 1031)
    }

    @MainActor
    func testDailySprintMatchesOfficialSectionRatio() {
        let store = LearningStore()
        XCTAssertEqual(store.questions.count, 1035)
        XCTAssertEqual(store.activeQuestions.count, 1031)
        store.updateShuffleQuestions(false)

        let cases: [(goal: Int, mandatory: Int, theory: Int, practical: Int)] = [
            (4, 1, 1, 2),
            (8, 2, 2, 4),
            (16, 4, 5, 7),
        ]
        for expected in cases {
            store.resetLearningData()
            store.updateShuffleQuestions(false)
            store.updateGoal(expected.goal)
            store.startDaily(premium: true)
            guard let ids = store.activeSession?.ids else {
                XCTFail("総合スプリントを開始できない")
                return
            }
            let sections = ids.compactMap { store.questionMap[$0]?.section }
            XCTAssertEqual(sections.filter { $0 == "必須" }.count, expected.mandatory)
            XCTAssertEqual(sections.filter { $0 == "理論" }.count, expected.theory)
            XCTAssertEqual(sections.filter { $0 == "実践" }.count, expected.practical)
            XCTAssertEqual(sections.count, expected.goal)
        }
        store.resetLearningData()
    }

    @MainActor
    func testFieldStudyUsesApproximatelyTwentyQuestionBatchesInsteadOfDailyGoal() {
        let store = LearningStore()
        store.resetLearningData()
        store.updateShuffleQuestions(false)
        store.updateGoal(8)

        let field = "実務"
        let all = store.fieldQuestions(field, premium: true)
        let batches = store.fieldQuestionBatches(field, premium: true)
        XCTAssertFalse(batches.isEmpty)
        XCTAssertEqual(batches.flatMap(\.questions).count, all.count)
        XCTAssertEqual(Set(batches.flatMap(\.questions).map(\.id)), Set(all.map(\.id)))
        XCTAssertTrue(batches.allSatisfy { $0.count >= 18 && $0.count <= 20 })

        store.startFieldBatch(field, batchIndex: 0, premium: true)
        XCTAssertEqual(store.activeSession?.ids.count, batches[0].count)
        XCTAssertNotEqual(store.activeSession?.ids.count, store.state.goal, "分野別は今日の8問設定で切らない")
        XCTAssertEqual(store.activeSession?.field, field)
        store.resetLearningData()
    }

    @MainActor
    func testWrongOrUnknownAnswerStillAdvancesDailyHeatmapAndAchievement() {
        let store = LearningStore()
        XCTAssertEqual(store.questions.count, 1035)
        XCTAssertEqual(store.activeQuestions.count, 1031)
        store.resetLearningData()
        store.updateGoal(8)
        store.updateShuffleQuestions(false)

        let before = store.learningProgress
        store.startDaily(premium: true)
        XCTAssertNotNil(store.currentQuestion)
        store.revealUnknown()

        XCTAssertEqual(store.state.totalAnswered, 1)
        XCTAssertEqual(store.state.totalCorrect, 0)
        XCTAssertEqual(store.todayRecord.answered, 1, "不正解でも5週間ヒートマップ用の日別回答数を増やす")
        XCTAssertEqual(store.todayRecord.correct, 0)
        XCTAssertGreaterThan(store.learningProgress, before, "達成度は正答率ではなくユニーク着手率なので0%のままにしない")
        XCTAssertEqual(store.weakCount, 1)
        store.resetLearningData()
    }
}
